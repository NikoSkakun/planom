import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/calendar/event_controller.dart';
import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/event.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late EventController controller;

  setUp(() async {
    db = freshDb();
    controller = EventController(db);
    await controller.load();
  });

  test('addEvent then eventById / events getter', () async {
    final e = Event(title: 'Standup', date: DateTime(2026, 5, 31));
    await controller.addEvent(e);

    expect(controller.events.length, 1);
    expect(controller.eventById(e.id)?.title, 'Standup');
    expect(controller.eventById('nope'), isNull);
  });

  test('addEvent persists across reload', () async {
    final e = Event(
      title: 'Persisted',
      date: DateTime(2026, 5, 31),
      doTime: 600,
      duration: 30,
    );
    await controller.addEvent(e);

    final fresh = EventController(db);
    await fresh.load();
    expect(fresh.events.length, 1);
    final stored = fresh.eventById(e.id)!;
    expect(stored.title, 'Persisted');
    expect(stored.doTime, 600);
    expect(stored.duration, 30);
  });

  test('updateEvent mutates the stored record', () async {
    final e = Event(title: 'Old', date: DateTime(2026, 5, 31));
    await controller.addEvent(e);
    await controller.updateEvent(e.copyWith(title: 'New'));
    expect(controller.eventById(e.id)?.title, 'New');
  });

  test('eventsForDate filters by exact y/m/d', () async {
    final a = Event(title: 'On 31st', date: DateTime(2026, 5, 31));
    final b = Event(title: 'On 1st', date: DateTime(2026, 6, 1));
    await controller.addEvent(a);
    await controller.addEvent(b);

    final may31 = controller.eventsForDate(DateTime(2026, 5, 31));
    expect(may31.map((e) => e.title), ['On 31st']);

    final jun1 = controller.eventsForDate(DateTime(2026, 6, 1));
    expect(jun1.map((e) => e.title), ['On 1st']);

    expect(controller.eventsForDate(DateTime(2026, 7, 7)), isEmpty);
  });

  test('eventsForDate ignores the time component of the query date', () async {
    final e = Event(title: 'AllDay', date: DateTime(2026, 5, 31));
    await controller.addEvent(e);
    final hits = controller.eventsForDate(DateTime(2026, 5, 31, 14, 30));
    expect(hits.map((x) => x.title), ['AllDay']);
  });

  test('deleteEvent hard-deletes from controller and DB', () async {
    final e = Event(title: 'Gone', date: DateTime(2026, 5, 31));
    await controller.addEvent(e);
    await controller.deleteEvent(e.id);

    expect(controller.events, isEmpty);
    expect(controller.eventById(e.id), isNull);

    // Hard delete: not present in DB at all.
    final inDb = await db.getEvents();
    expect(inDb.where((x) => x.id == e.id), isEmpty);

    final fresh = EventController(db);
    await fresh.load();
    expect(fresh.events, isEmpty);
  });
}
