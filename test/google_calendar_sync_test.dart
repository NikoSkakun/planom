import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/integrations/google/google_account.dart';
import 'package:planom/src/integrations/google/google_auth_service.dart';
import 'package:planom/src/integrations/google/google_calendar_api.dart';
import 'package:planom/src/integrations/google/google_calendar_cache.dart';
import 'package:planom/src/integrations/google/google_calendar_controller.dart';
import 'package:planom/src/integrations/google/remote_event.dart';

/// Auth stub: no real flutter_appauth / secure storage. The controller only
/// calls authorize / cacheAccessToken / storeRefreshToken / forget on it; the
/// API stub handles everything else.
class _FakeAuth extends GoogleAuthService {
  @override
  Future<GoogleAuthResult?> authorize(List<String> scopes) async =>
      GoogleAuthResult(accessToken: 'access', refreshToken: 'refresh');
  @override
  void cacheAccessToken(String accountId, String token, DateTime? expiry) {}
  @override
  Future<void> storeRefreshToken(String accountId, String? token) async {}
  @override
  Future<void> forget(String accountId) async {}
}

/// Scriptable Calendar API. A full fetch (no token) returns the registered
/// events; an incremental fetch (with token) returns queued deltas / deletes.
class _FakeApi extends GoogleCalendarApi {
  _FakeApi() : super(_FakeAuth());

  /// The email the next addAccount() should resolve to.
  String? nextPrimaryEmail;

  /// When true, [listCalendars] throws — simulating a transient token / network
  /// failure so we can assert cached calendars survive.
  bool failListCalendars = false;

  final Map<String, List<GoogleCalendarMeta>> _cals = {};
  final Map<String, List<RemoteEvent>> _fullEvents = {}; // calKey -> events
  final Map<String, List<RemoteEvent>> _pendingDeltas = {};
  final Map<String, Set<String>> _pendingDeletes = {};
  int _tok = 0;

  void register(
    String email, {
    required List<GoogleCalendarMeta> calendars,
    Map<String, List<RemoteEvent>> events = const {},
  }) {
    _cals[email] = calendars;
    events.forEach((calId, evs) {
      _fullEvents[calendarKey(email, calId)] = evs;
    });
  }

  void queueDelete(String calKey, String eventId) =>
      (_pendingDeletes[calKey] ??= {}).add(eventId);

  @override
  Future<String?> primaryCalendarId(GoogleAccount account) async =>
      nextPrimaryEmail;

  @override
  Future<List<GoogleCalendarMeta>> listCalendars(GoogleAccount account) async {
    if (failListCalendars) throw Exception('listCalendars failed');
    final base = _cals[account.id] ?? const <GoogleCalendarMeta>[];
    // Stamp the account's read-only mode, mirroring the real API.
    return base
        .map((c) => GoogleCalendarMeta(
              accountId: account.id,
              id: c.id,
              summary: c.summary,
              color: c.color,
              accessRole: c.accessRole,
              primary: c.primary,
              accountReadOnly: account.readOnly,
            ))
        .toList();
  }

  @override
  Future<CalendarListResult> listEvents({
    required GoogleAccount account,
    required GoogleCalendarMeta calendar,
    DateTime? timeMin,
    DateTime? timeMax,
    String? syncToken,
  }) async {
    final key = calendar.key;
    if (syncToken == null) {
      return CalendarListResult(
        events: List.of(_fullEvents[key] ?? const []),
        nextSyncToken: 'tok${_tok++}',
        tokenInvalid: false,
      );
    }
    return CalendarListResult(
      events: List.of(_pendingDeltas.remove(key) ?? const []),
      nextSyncToken: 'tok${_tok++}',
      tokenInvalid: false,
      deletedEventIds: _pendingDeletes.remove(key) ?? const {},
    );
  }

  @override
  Future<RemoteEvent?> insertEvent({
    required GoogleAccount account,
    required GoogleCalendarMeta calendar,
    required RemoteEventDraft draft,
  }) async =>
      RemoteEvent(
        googleEventId: 'created${_tok++}',
        accountId: account.id,
        calendarId: calendar.id,
        calendarName: calendar.summary,
        calendarColor: calendar.color,
        title: draft.title,
        date: draft.date,
      );
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

  GoogleCalendarMeta cal(
    String email,
    String id, {
    bool primary = false,
    String role = 'owner',
  }) =>
      GoogleCalendarMeta(
        accountId: email,
        id: id,
        summary: id,
        color: 0xFF112233,
        accessRole: role,
        primary: primary,
      );

  RemoteEvent ev(String email, String calId, String id) => RemoteEvent(
        googleEventId: id,
        accountId: email,
        calendarId: calId,
        calendarName: calId,
        calendarColor: 0xFF112233,
        title: id,
        date: DateTime.now(),
      );

  late DatabaseService db;
  late _FakeApi api;
  late GoogleCalendarController controller;

  setUp(() async {
    db = DatabaseService(
        dbName: 'test_gcal_${DateTime.now().microsecondsSinceEpoch}.db');
    api = _FakeApi();
    controller = GoogleCalendarController(
      db: db,
      auth: _FakeAuth(),
      cache: _FakeCache(),
      api: api,
    );
  });

  tearDown(() async => db.resetUserData());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  Set<String> eventIds() =>
      controller.events.map((e) => e.googleEventId).toSet();

  Future<void> addAccount(String email,
      {bool readOnly = false, required _FakeApi api}) async {
    api.nextPrimaryEmail = email;
    await controller.addAccount(readOnly: readOnly);
  }

  test('adding an account loads events from all its calendars', () async {
    api.register('a@x.com', calendars: [
      cal('a@x.com', 'work', primary: true),
      cal('a@x.com', 'home'),
    ], events: {
      'work': [ev('a@x.com', 'work', 'w1')],
      'home': [ev('a@x.com', 'home', 'h1')],
    });

    await addAccount('a@x.com', api: api);
    await settle();

    expect(eventIds(), {'w1', 'h1'});
    expect(controller.accountCount, 1);
  });

  test('re-enabling a calendar restores all its events, not just deltas',
      () async {
    api.register('a@x.com', calendars: [
      cal('a@x.com', 'work', primary: true),
      cal('a@x.com', 'home'),
    ], events: {
      'work': [ev('a@x.com', 'work', 'w1')],
      'home': [ev('a@x.com', 'home', 'h1')],
    });
    await addAccount('a@x.com', api: api);
    await settle();
    expect(eventIds(), {'w1', 'h1'});

    final home =
        controller.calendarsForAccount('a@x.com').firstWhere((c) => c.id == 'home');

    await controller.setCalendarSelected(home, false);
    await settle();
    expect(eventIds(), {'w1'});

    // Re-enable: the cleared sync token must force a full fetch.
    await controller.setCalendarSelected(home, true);
    await settle();
    expect(eventIds(), {'w1', 'h1'});
  });

  test('removing then re-adding an account restores its events', () async {
    api.register('a@x.com',
        calendars: [cal('a@x.com', 'work', primary: true)],
        events: {
          'work': [ev('a@x.com', 'work', 'w1')]
        });
    await addAccount('a@x.com', api: api);
    await settle();
    expect(eventIds(), {'w1'});

    await controller.removeAccount(controller.accounts.first);
    expect(controller.events, isEmpty);
    expect(controller.accountCount, 0);

    await addAccount('a@x.com', api: api);
    await settle();
    expect(eventIds(), {'w1'});
  });

  test('incremental sync evicts events deleted on Google', () async {
    api.register('a@x.com',
        calendars: [cal('a@x.com', 'work', primary: true)],
        events: {
          'work': [ev('a@x.com', 'work', 'w1'), ev('a@x.com', 'work', 'w2')]
        });
    await addAccount('a@x.com', api: api);
    await settle();
    expect(eventIds(), {'w1', 'w2'});

    api.queueDelete(calendarKey('a@x.com', 'work'), 'w1');
    await controller.refresh();

    expect(eventIds(), {'w2'});
  });

  test('multiple accounts aggregate their events', () async {
    api.register('a@x.com',
        calendars: [cal('a@x.com', 'cal', primary: true)],
        events: {
          'cal': [ev('a@x.com', 'cal', 'a1')]
        });
    api.register('b@y.com',
        calendars: [cal('b@y.com', 'cal', primary: true)],
        events: {
          'cal': [ev('b@y.com', 'cal', 'b1')]
        });

    await addAccount('a@x.com', api: api);
    await settle();
    await addAccount('b@y.com', api: api);
    await settle();

    expect(controller.accountCount, 2);
    expect(eventIds(), {'a1', 'b1'});
  });

  test(
      'an account added while its calendar list comes back empty still '
      'auto-selects its calendars on the next successful refresh',
      () async {
    api.register('a@x.com',
        calendars: [cal('a@x.com', 'cal', primary: true)],
        events: {
          'cal': [ev('a@x.com', 'cal', 'a1')]
        });

    // First account in normally.
    await addAccount('a@x.com', api: api);
    await settle();

    // Second account: register it but have listCalendars return [] during
    // addAccount (simulating a transient API hiccup right after consent).
    api.register('b@y.com',
        calendars: [cal('b@y.com', 'cal', primary: true)],
        events: {
          'cal': [ev('b@y.com', 'cal', 'b1')]
        });
    final realCalendars = List<GoogleCalendarMeta>.of(api._cals['b@y.com']!);
    api._cals['b@y.com'] = const [];
    await addAccount('b@y.com', api: api);
    await settle();

    // listCalendars now succeeds; a fresh refresh should populate b@y.com's
    // calendars AND select them so they appear in writableSelectedCalendars
    // (which the event-creation picker reads).
    api._cals['b@y.com'] = realCalendars;
    await controller.refresh();
    await settle();

    expect(controller.accountCount, 2);
    expect(controller.calendarsForAccount('b@y.com').map((c) => c.id).toList(),
        ['cal']);
    expect(
        controller.writableSelectedCalendars
            .map((c) => '${c.accountId}/${c.id}')
            .toSet(),
        {'a@x.com/cal', 'b@y.com/cal'});
  });

  test('read-only account calendars are not writable and reject creates',
      () async {
    api.register('r@x.com',
        calendars: [cal('r@x.com', 'cal', primary: true)]);
    await addAccount('r@x.com', readOnly: true, api: api);
    await settle();

    final cals = controller.calendarsForAccount('r@x.com');
    expect(cals.isNotEmpty, true);
    expect(cals.every((c) => !c.canWrite), true);

    final created = await controller.createEvent(
      RemoteEventDraft(title: 'x', date: DateTime.now()),
      accountId: 'r@x.com',
      calendarId: 'cal',
    );
    expect(created, isNull);
  });

  test('a failed calendar fetch keeps previously-known calendars', () async {
    api.register('a@x.com',
        calendars: [cal('a@x.com', 'work', primary: true)],
        events: {
          'work': [ev('a@x.com', 'work', 'w1')]
        });
    await addAccount('a@x.com', api: api);
    await settle();
    expect(controller.calendarsForAccount('a@x.com').map((c) => c.id).toList(),
        ['work']);

    // A subsequent refresh whose calendar fetch fails must not blank the
    // account out to "No calendars found".
    api.failListCalendars = true;
    await controller.refresh();
    await settle();
    expect(controller.calendarsForAccount('a@x.com').map((c) => c.id).toList(),
        ['work']);
    // The calendar also stays available to the event-creation picker.
    expect(
        controller.writableSelectedCalendars.map((c) => c.id).toList(), ['work']);
  });

  test('event reminders are stored, read back and cleared', () async {
    api.register('a@x.com',
        calendars: [cal('a@x.com', 'work', primary: true)],
        events: {
          'work': [ev('a@x.com', 'work', 'w1')]
        });
    await addAccount('a@x.com', api: api);
    await settle();
    final event = controller.events.firstWhere((e) => e.googleEventId == 'w1');
    expect(controller.remindersForEvent(event), isEmpty);

    await controller.setEventReminders(event, [-10, -60]);
    expect(controller.remindersForEvent(event), [-10, -60]);

    await controller.setEventReminders(event, []);
    expect(controller.remindersForEvent(event), isEmpty);
  });

  test('removing an account clears its event reminders', () async {
    api.register('a@x.com',
        calendars: [cal('a@x.com', 'work', primary: true)],
        events: {
          'work': [ev('a@x.com', 'work', 'w1')]
        });
    await addAccount('a@x.com', api: api);
    await settle();
    final event = controller.events.firstWhere((e) => e.googleEventId == 'w1');
    await controller.setEventReminders(event, [-15]);
    expect(controller.remindersForEvent(event), [-15]);

    await controller.removeAccount(controller.accounts.first);
    await addAccount('a@x.com', api: api);
    await settle();
    final again = controller.events.firstWhere((e) => e.googleEventId == 'w1');
    expect(controller.remindersForEvent(again), isEmpty);
  });
}
