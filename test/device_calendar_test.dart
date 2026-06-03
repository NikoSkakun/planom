import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/integrations/apple/device_calendar_cache.dart';
import 'package:planom/src/integrations/apple/device_calendar_controller.dart';
import 'package:planom/src/integrations/apple/device_event.dart';
import 'package:planom/src/integrations/apple/eventkit_service.dart';

/// In-memory fake EventKit bridge. Reports itself as supported so the platform
/// channel is never touched, and lets tests script calendars + events.
class _FakeEventKit extends EventKitService {
  _FakeEventKit();

  @override
  bool get isSupported => true;

  EventKitAuthStatus status = EventKitAuthStatus.notDetermined;
  bool grantOnRequest = true;

  final List<DeviceCalendarMeta> calendars = [];
  final List<DeviceEvent> events = [];
  int _seq = 0;

  @override
  Future<EventKitAuthStatus> authorizationStatus() async => status;

  @override
  Future<bool> requestAccess() async {
    if (grantOnRequest) status = EventKitAuthStatus.fullAccess;
    return grantOnRequest;
  }

  @override
  Future<List<DeviceCalendarMeta>> listCalendars() async =>
      List.of(calendars);

  @override
  Future<List<DeviceEvent>> fetchEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async =>
      events
          .where((e) =>
              calendarIds.contains(e.calendarId) &&
              !e.date.isBefore(DateTime(start.year, start.month, start.day)) &&
              !e.date.isAfter(end))
          .toList();

  @override
  Future<DeviceEvent?> createEvent(
    DeviceEventDraft draft, {
    required String calendarId,
  }) async {
    final cal = calendars.firstWhere((c) => c.id == calendarId);
    final e = DeviceEvent(
      eventId: 'created${_seq++}',
      calendarId: calendarId,
      calendarName: cal.title,
      calendarColor: cal.color,
      title: draft.title,
      note: draft.note,
      date: draft.date,
      doTime: draft.doTime,
      duration: draft.duration,
    );
    events.add(e);
    return e;
  }

  @override
  Future<DeviceEvent?> updateEvent(DeviceEvent event) async {
    final i = events.indexWhere((e) => e.eventId == event.eventId);
    if (i >= 0) events[i] = event;
    return event;
  }

  @override
  Future<bool> deleteEvent(DeviceEvent event) async {
    events.removeWhere((e) => e.eventId == event.eventId);
    return true;
  }
}

class _FakeCache extends DeviceCalendarCache {
  List<DeviceEvent> events = [];
  List<DeviceCalendarMeta> cals = [];
  @override
  Future<List<DeviceEvent>> read() async => List.of(events);
  @override
  Future<void> write(List<DeviceEvent> e) async => events = List.of(e);
  @override
  Future<List<DeviceCalendarMeta>> readCalendars() async => List.of(cals);
  @override
  Future<void> writeCalendars(List<DeviceCalendarMeta> c) async =>
      cals = List.of(c);
  @override
  Future<void> clear() async {
    events = [];
    cals = [];
  }

  @override
  Future<void> clearCalendars() async => cals = [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DeviceEvent mapping', () {
    test('fromChannel parses a timed event', () {
      final start = DateTime(2026, 6, 3, 9, 30);
      final end = start.add(const Duration(minutes: 45));
      final e = DeviceEvent.fromChannel({
        'id': 'e1',
        'calendarId': 'work',
        'calendarName': 'Work',
        'colorArgb': 0xFF112233,
        'title': 'Standup',
        'notes': 'daily',
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
        'isAllDay': false,
        'isReadOnly': false,
        'hasRecurrence': true,
      })!;
      expect(e.date, DateTime(2026, 6, 3));
      expect(e.doTime, 9 * 60 + 30);
      expect(e.duration, 45);
      expect(e.isRecurring, true);
      expect(e.title, 'Standup');
    });

    test('fromChannel parses an all-day event (no doTime)', () {
      final start = DateTime(2026, 6, 3);
      final e = DeviceEvent.fromChannel({
        'id': 'e2',
        'calendarId': 'home',
        'startMs': start.millisecondsSinceEpoch,
        'isAllDay': true,
      })!;
      expect(e.doTime, isNull);
      expect(e.date, DateTime(2026, 6, 3));
      expect(e.title, '(No title)');
    });

    test('toJson / fromJson round-trips', () {
      final e = DeviceEvent(
        eventId: 'x',
        calendarId: 'c',
        calendarName: 'C',
        calendarColor: 0xFFAABBCC,
        title: 'T',
        note: 'N',
        date: DateTime(2026, 1, 2),
        doTime: 600,
        duration: 30,
        isReadOnly: true,
      );
      final back = DeviceEvent.fromJson(e.toJson());
      expect(back.eventId, 'x');
      expect(back.doTime, 600);
      expect(back.duration, 30);
      expect(back.isReadOnly, true);
      expect(back.note, 'N');
    });
  });

  group('DeviceCalendarController', () {
    late DatabaseService db;
    late _FakeEventKit service;
    late DeviceCalendarController controller;

    DeviceCalendarMeta cal(String id, {bool writable = true}) =>
        DeviceCalendarMeta(
          id: id,
          title: id,
          color: 0xFF112233,
          allowsModify: writable,
        );

    DeviceEvent ev(String id, String calId, DateTime date) => DeviceEvent(
          eventId: id,
          calendarId: calId,
          calendarName: calId,
          calendarColor: 0xFF112233,
          title: id,
          date: date,
        );

    setUp(() async {
      db = DatabaseService(
          dbName: 'test_ekcal_${DateTime.now().microsecondsSinceEpoch}.db');
      service = _FakeEventKit();
      controller = DeviceCalendarController(
        db: db,
        service: service,
        cache: _FakeCache(),
      );
    });

    tearDown(() async => db.resetUserData());

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    test('connect requests access, loads + selects calendars, fetches events',
        () async {
      final today = DateTime.now();
      service.calendars.addAll([cal('work'), cal('home')]);
      service.events.addAll([
        ev('w1', 'work', today),
        ev('h1', 'home', today),
      ]);

      final ok = await controller.connect();
      await settle();

      expect(ok, true);
      expect(controller.isAuthorized, true);
      expect(controller.availableCalendars.length, 2);
      expect(controller.eventsForDate(today).map((e) => e.eventId).toSet(),
          {'w1', 'h1'});
    });

    test('deselecting a calendar drops its events from the view', () async {
      final today = DateTime.now();
      service.calendars.addAll([cal('work'), cal('home')]);
      service.events
          .addAll([ev('w1', 'work', today), ev('h1', 'home', today)]);
      await controller.connect();
      await settle();

      final home = controller.availableCalendars.firstWhere((c) => c.id == 'home');
      await controller.setCalendarSelected(home, false);
      await settle();

      expect(controller.eventsForDate(today).map((e) => e.eventId).toSet(),
          {'w1'});
    });

    test('createEvent adds to the in-memory stream', () async {
      final today = DateTime.now();
      service.calendars.add(cal('work'));
      await controller.connect();
      await settle();

      final created = await controller.createEvent(
        DeviceEventDraft(title: 'New', date: today, doTime: 540, duration: 60),
        calendarId: 'work',
      );
      expect(created, isNotNull);
      expect(controller.eventsForDate(today).any((e) => e.title == 'New'), true);
    });

    test('createEvent on a read-only calendar is rejected', () async {
      service.calendars.add(cal('holidays', writable: false));
      await controller.connect();
      await settle();

      final created = await controller.createEvent(
        DeviceEventDraft(title: 'X', date: DateTime.now()),
        calendarId: 'holidays',
      );
      expect(created, isNull);
    });

    test('deleteEvent removes it from the stream', () async {
      final today = DateTime.now();
      service.calendars.add(cal('work'));
      service.events.add(ev('w1', 'work', today));
      await controller.connect();
      await settle();
      expect(controller.eventsForDate(today).length, 1);

      final e = controller.events.firstWhere((e) => e.eventId == 'w1');
      final ok = await controller.deleteEvent(e);
      expect(ok, true);
      expect(controller.eventsForDate(today), isEmpty);
    });

    test('not authorized yields no events', () async {
      service.status = EventKitAuthStatus.notDetermined;
      service.grantOnRequest = false;
      final ok = await controller.connect();
      expect(ok, false);
      expect(controller.isAuthorized, false);
      expect(controller.eventsForDate(DateTime.now()), isEmpty);
    });

    test('reminders are stored, read back and cleared', () async {
      final today = DateTime.now();
      service.calendars.add(cal('work'));
      service.events.add(ev('w1', 'work', today));
      await controller.connect();
      await settle();
      final e = controller.events.firstWhere((e) => e.eventId == 'w1');

      expect(controller.remindersForEvent(e), isEmpty);
      await controller.setEventReminders(e, [-10, -60]);
      expect(controller.remindersForEvent(e), [-10, -60]);
      await controller.setEventReminders(e, []);
      expect(controller.remindersForEvent(e), isEmpty);
    });

    test('isReservedKey matches the ekcal_ prefix', () {
      expect(DeviceCalendarController.isReservedKey('ekcal_selected'), true);
      expect(DeviceCalendarController.isReservedKey('gcal_selected'), false);
      expect(DeviceCalendarController.isReservedKey('accent_color'), false);
    });
  });
}
