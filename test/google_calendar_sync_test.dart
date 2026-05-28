import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/integrations/google/google_auth_service.dart';
import 'package:planom/src/integrations/google/google_calendar_api.dart';
import 'package:planom/src/integrations/google/google_calendar_cache.dart';
import 'package:planom/src/integrations/google/google_calendar_controller.dart';
import 'package:planom/src/integrations/google/remote_event.dart';

/// A signed-in auth stub. Never touches the real google_sign_in plugin.
class _FakeAuth extends GoogleAuthService {
  bool signedIn = true;

  @override
  bool get isSignedIn => signedIn;
  @override
  String? get email => signedIn ? 'tester@example.com' : null;
  @override
  Future<bool> trySilentSignIn() async => signedIn;
  @override
  Future<bool> signIn() async {
    signedIn = true;
    return true;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }

  @override
  Future<http.Client?> authClient() async => null;
}

/// Scriptable Calendar API stub. A full fetch (no sync token) returns
/// [fullEvents]; an incremental fetch (with token) returns the queued deltas /
/// deletes for that calendar, mimicking Google's real behavior.
class _FakeApi extends GoogleCalendarApi {
  _FakeApi() : super(_FakeAuth());

  List<GoogleCalendarMeta> calendars = const [];
  Map<String, List<RemoteEvent>> fullEvents = {};
  final Map<String, List<RemoteEvent>> _pendingDeltas = {};
  final Map<String, Set<String>> _pendingDeletes = {};
  int _tok = 0;

  void queueDelete(String calId, String eventId) =>
      (_pendingDeletes[calId] ??= {}).add(eventId);

  @override
  Future<List<GoogleCalendarMeta>> listCalendars() async => calendars;

  @override
  Future<CalendarListResult> listEvents({
    required GoogleCalendarMeta calendar,
    DateTime? timeMin,
    DateTime? timeMax,
    String? syncToken,
  }) async {
    if (syncToken == null) {
      // Full fetch: authoritative snapshot for the window.
      return CalendarListResult(
        events: List.of(fullEvents[calendar.id] ?? const []),
        nextSyncToken: 'tok${_tok++}',
        tokenInvalid: false,
      );
    }
    // Incremental: only deltas + deletion tombstones since the last token.
    final deltas = _pendingDeltas.remove(calendar.id) ?? const [];
    final deletes = _pendingDeletes.remove(calendar.id) ?? const <String>{};
    return CalendarListResult(
      events: List.of(deltas),
      nextSyncToken: 'tok${_tok++}',
      tokenInvalid: false,
      deletedEventIds: deletes,
    );
  }
}

class _FakeCache extends GoogleCalendarCache {
  List<RemoteEvent> stored = [];
  @override
  Future<List<RemoteEvent>> read() async => List.of(stored);
  @override
  Future<void> write(List<RemoteEvent> events) async => stored = List.of(events);
  @override
  Future<void> clear() async => stored = [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  GoogleCalendarMeta cal(String id, {bool primary = false}) => GoogleCalendarMeta(
        id: id,
        summary: id,
        color: 0xFF112233,
        accessRole: 'owner',
        primary: primary,
      );

  RemoteEvent ev(String id, String calId) => RemoteEvent(
        googleEventId: id,
        calendarId: calId,
        calendarName: calId,
        calendarColor: 0xFF112233,
        title: id,
        date: DateTime.now(),
      );

  late DatabaseService db;
  late _FakeAuth auth;
  late _FakeApi api;
  late _FakeCache cache;
  late GoogleCalendarController controller;

  setUp(() async {
    db = DatabaseService(
      dbName: 'test_gcal_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    auth = _FakeAuth();
    api = _FakeApi()
      ..calendars = [cal('A', primary: true), cal('B')]
      ..fullEvents = {
        'A': [ev('a1', 'A'), ev('a2', 'A')],
        'B': [ev('b1', 'B'), ev('b2', 'B')],
      };
    cache = _FakeCache();
    controller = GoogleCalendarController(
      db: db,
      auth: auth,
      cache: cache,
      api: api,
    );
  });

  tearDown(() async {
    await db.resetUserData();
  });

  // Drains the fire-and-forget refresh()es kicked off inside connect() /
  // setSelectedCalendars().
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  Set<String> idsFor(String calId) => controller.events
      .where((e) => e.calendarId == calId)
      .map((e) => e.googleEventId)
      .toSet();

  test('connect loads every event from every calendar', () async {
    await controller.connect();
    await settle();

    expect(idsFor('A'), {'a1', 'a2'});
    expect(idsFor('B'), {'b1', 'b2'});
  });

  test('re-enabling a calendar restores all its events, not just deltas',
      () async {
    await controller.connect();
    await settle();
    expect(idsFor('B'), {'b1', 'b2'});

    // Disable calendar B.
    await controller.setSelectedCalendars({'A'});
    await settle();
    expect(idsFor('B'), isEmpty);

    // Re-enable B. The stale sync token must have been cleared so this does a
    // full fetch — otherwise an incremental sync would return no deltas and B
    // would stay empty (the reported bug).
    await controller.setSelectedCalendars({'A', 'B'});
    await settle();
    expect(idsFor('B'), {'b1', 'b2'});
  });

  test('reconnecting after disconnect restores all events', () async {
    await controller.connect();
    await settle();
    expect(idsFor('A'), {'a1', 'a2'});

    await controller.disconnect();
    expect(controller.events, isEmpty);

    await controller.connect();
    await settle();
    expect(idsFor('A'), {'a1', 'a2'});
    expect(idsFor('B'), {'b1', 'b2'});
  });

  test('incremental sync evicts events deleted on Google', () async {
    await controller.connect();
    await settle();
    expect(idsFor('B'), {'b1', 'b2'});

    // Next incremental refresh reports b1 as cancelled (deleted elsewhere).
    api.queueDelete('B', 'b1');
    await controller.refresh();

    expect(idsFor('B'), {'b2'});
  });
}
