import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/routine.dart';
import 'package:planom/src/models/routine_entry.dart';
import 'package:planom/src/routines/routine_controller.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late RoutineController controller;

  setUp(() async {
    db = freshDb();
    controller = RoutineController(db);
    await controller.load();
  });

  Routine achieveAll(String name) =>
      Routine(name: name, goalType: 'achieve_all');

  group('CRUD', () {
    test('addRoutine then routines getter', () async {
      await controller.addRoutine(achieveAll('Water'));
      expect(controller.routines.length, 1);
      expect(controller.routines.single.name, 'Water');
    });

    test('updateRoutine mutates record', () async {
      final r = achieveAll('Water');
      await controller.addRoutine(r);
      await controller.updateRoutine(r.copyWith(name: 'Hydrate'));
      expect(controller.routines.single.name, 'Hydrate');
    });

    test('deleteRoutine also removes its entries', () async {
      final r = achieveAll('Pushups');
      await controller.addRoutine(r);
      await controller.recordProgress(r); // creates today's entry
      expect((await db.getRoutineEntries()).length, 1);

      await controller.deleteRoutine(r.id);
      expect(controller.routines, isEmpty);
      expect(await db.getRoutineEntries(), isEmpty);

      final fresh = RoutineController(db);
      await fresh.load();
      expect(fresh.routines, isEmpty);
    });
  });

  group('routinesForDate scheduling', () {
    test('a daily routine shows on its creation day and every later day',
        () async {
      final created = DateTime(2026, 5, 20, 9, 30);
      final r = Routine(
          name: 'Daily', goalType: 'achieve_all', creationDate: created);
      await controller.addRoutine(r);

      // Creation day and a later day: shown.
      expect(controller.routinesForDate(DateTime(2026, 5, 20)).map((x) => x.id),
          contains(r.id));
      expect(controller.routinesForDate(DateTime(2026, 6, 1)).map((x) => x.id),
          contains(r.id));
      // Before it existed: hidden (history stays accurate).
      expect(controller.routinesForDate(DateTime(2026, 5, 19)).map((x) => x.id),
          isNot(contains(r.id)));
    });

    test('specific_days routine only shows on its selected weekdays', () async {
      // 2026-06-01 is a Monday (weekday index 0); 2026-06-02 is a Tuesday (1).
      final monday = DateTime(2026, 6, 1);
      final tuesday = DateTime(2026, 6, 2);
      expect(monday.weekday, DateTime.monday);

      final r = Routine(
        name: 'Gym',
        goalType: 'achieve_all',
        frequencyType: 'specific_days',
        weekdays: const [0, 2, 4], // Mon, Wed, Fri
        creationDate: DateTime(2026, 1, 1),
      );
      await controller.addRoutine(r);

      expect(controller.routinesForDate(monday).map((x) => x.id),
          contains(r.id));
      expect(controller.routinesForDate(tuesday).map((x) => x.id),
          isNot(contains(r.id)));
    });

    test('specific_days schedule survives a reload', () async {
      final r = Routine(
        name: 'Gym',
        goalType: 'achieve_all',
        frequencyType: 'specific_days',
        weekdays: const [5, 6], // Sat, Sun
        creationDate: DateTime(2026, 1, 1),
      );
      await controller.addRoutine(r);

      final fresh = RoutineController(db);
      await fresh.load();
      final reloaded = fresh.routines.firstWhere((x) => x.id == r.id);
      expect(reloaded.frequencyType, 'specific_days');
      expect(reloaded.weekdays, const [5, 6]);
    });
  });

  group('recordProgress: achieve_all', () {
    test('first call completes, second call toggles back off', () async {
      final r = achieveAll('Meditate');
      await controller.addRoutine(r);

      await controller.recordProgress(r);
      expect(controller.entryForToday(r.id)?.amount, 1);
      expect(controller.isTodayCompleted(r), isTrue);

      await controller.recordProgress(r);
      expect(controller.entryForToday(r.id)?.amount, 0);
      expect(controller.isTodayCompleted(r), isFalse);
    });
  });

  group('recordProgress: certain_amount', () {
    test('each call adds recordAmount; wraps to 0 once the goal is reached',
        () async {
      final r = Routine(
        name: 'Drink',
        goalType: 'certain_amount',
        goalAmount: 8,
        recordAmount: 2,
        goalUnit: 'cup',
      );
      await controller.addRoutine(r);

      await controller.recordProgress(r);
      expect(controller.todayProgress(r.id), 2);
      expect(controller.isTodayCompleted(r), isFalse);

      await controller.recordProgress(r);
      await controller.recordProgress(r);
      await controller.recordProgress(r);
      expect(controller.todayProgress(r.id), 8);
      expect(controller.isTodayCompleted(r), isTrue);

      // Tapping again wraps back to 0 so the day can be un-completed.
      await controller.recordProgress(r);
      expect(controller.todayProgress(r.id), 0);
      expect(controller.isTodayCompleted(r), isFalse);
    });
  });

  group('per-day history', () {
    test('progress on different days is tracked independently', () async {
      final r = achieveAll('Streak');
      await controller.addRoutine(r);

      final yesterday = today().subtract(const Duration(days: 1));

      // Complete yesterday only.
      await controller.recordProgress(r, yesterday);
      expect(controller.isCompletedOnDate(r, yesterday), isTrue);
      // Today is a fresh, separate item — not completed.
      expect(controller.isTodayCompleted(r), isFalse);
      expect(controller.progressForDate(r.id, yesterday), 1);
      expect(controller.progressForDate(r.id, today()), 0);
    });

    test('editing a past day persists across reload', () async {
      final r = achieveAll('History');
      await controller.addRoutine(r);
      final twoDaysAgo = today().subtract(const Duration(days: 2));
      await controller.recordProgress(r, twoDaysAgo);

      final fresh = RoutineController(db);
      await fresh.load();
      final reloaded = fresh.routines.firstWhere((x) => x.id == r.id);
      expect(fresh.isCompletedOnDate(reloaded, twoDaysAgo), isTrue);
      expect(fresh.isTodayCompleted(reloaded), isFalse);
    });

    test('amounts written for a day are reflected in queries', () async {
      final r = Routine(
          name: 'Manual', goalType: 'certain_amount', goalAmount: 3);
      await controller.addRoutine(r);
      final day = today().subtract(const Duration(days: 3));
      await db.insertRoutineEntry(
          RoutineEntry(routineId: r.id, date: day, amount: 3));

      final fresh = RoutineController(db);
      await fresh.load();
      final reloaded = fresh.routines.firstWhere((x) => x.id == r.id);
      expect(fresh.progressForDate(r.id, day), 3);
      expect(fresh.isCompletedOnDate(reloaded, day), isTrue);
    });
  });
}
