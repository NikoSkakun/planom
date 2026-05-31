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

  // 0=Mon … 6=Sun (matches Routine.weekdays indexing).
  final int todayIdx = DateTime.now().weekday - 1;
  final int otherIdx = (todayIdx + 1) % 7;

  setUp(() async {
    db = freshDb();
    controller = RoutineController(db);
    await controller.load();
  });

  group('CRUD', () {
    test('addRoutine then routines getter', () async {
      final r = Routine(
        name: 'Water',
        goalType: 'achieve_all',
        frequencyType: 'daily',
        autoReset: 'everyday',
      );
      await controller.addRoutine(r);
      expect(controller.routines.length, 1);
      expect(controller.routines.single.name, 'Water');
    });

    test('updateRoutine mutates record', () async {
      final r = Routine(
        name: 'Water',
        goalType: 'achieve_all',
        frequencyType: 'daily',
        autoReset: 'everyday',
      );
      await controller.addRoutine(r);
      await controller.updateRoutine(r.copyWith(name: 'Hydrate'));
      expect(controller.routines.single.name, 'Hydrate');
    });

    test('deleteRoutine also removes its entries', () async {
      final r = Routine(
        name: 'Pushups',
        goalType: 'achieve_all',
        frequencyType: 'daily',
        autoReset: 'everyday',
      );
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

  group('todayRoutines scheduling', () {
    test('daily with weekdays == today is shown', () async {
      final r = Routine(
        name: 'Today',
        goalType: 'achieve_all',
        frequencyType: 'daily',
        weekdays: [todayIdx],
        autoReset: 'everyday',
      );
      await controller.addRoutine(r);
      expect(controller.todayRoutines.map((x) => x.id), contains(r.id));
    });

    test('daily with a different weekday is NOT shown', () async {
      final r = Routine(
        name: 'NotToday',
        goalType: 'achieve_all',
        frequencyType: 'daily',
        weekdays: [otherIdx],
        autoReset: 'everyday',
      );
      await controller.addRoutine(r);
      expect(controller.todayRoutines.map((x) => x.id), isNot(contains(r.id)));
    });

    test('daily with null weekdays is shown every day', () async {
      final r = Routine(
        name: 'EveryDay',
        goalType: 'achieve_all',
        frequencyType: 'daily',
        weekdays: null,
        autoReset: 'everyday',
      );
      await controller.addRoutine(r);
      expect(controller.todayRoutines.map((x) => x.id), contains(r.id));
    });

    test('days_after_complete: never completed is shown', () async {
      final r = Routine(
        name: 'AfterGap',
        goalType: 'achieve_all',
        frequencyType: 'days_after_complete',
        daysAfterComplete: 2,
        autoReset: 'everyday',
      );
      await controller.addRoutine(r);
      expect(controller.todayRoutines.map((x) => x.id), contains(r.id));
    });

    test('days_after_complete: completed today with gap=2 is NOT shown today',
        () async {
      final r = Routine(
        name: 'AfterGap',
        goalType: 'achieve_all',
        frequencyType: 'days_after_complete',
        daysAfterComplete: 2,
        autoReset: 'everyday',
      );
      await controller.addRoutine(r);
      await controller.recordProgress(r); // completes today

      // next due = today + 2, so it is hidden today.
      expect(controller.todayRoutines.map((x) => x.id), isNot(contains(r.id)));
    });
  });

  group('recordProgress: achieve_all', () {
    test('first call completes, second call toggles back off', () async {
      final r = Routine(
        name: 'Meditate',
        goalType: 'achieve_all',
        frequencyType: 'daily',
        autoReset: 'everyday',
      );
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
    test('each call adds recordAmount; reaches goal after 4 calls', () async {
      final r = Routine(
        name: 'Drink',
        goalType: 'certain_amount',
        goalAmount: 8,
        recordAmount: 2,
        goalUnit: 'cup',
        frequencyType: 'daily',
        autoReset: 'everyday',
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
    });
  });

  group('autoReset = none', () {
    test('achieve_all completed on a prior day still counts as completed today',
        () async {
      final r = Routine(
        name: 'Streak',
        goalType: 'achieve_all',
        frequencyType: 'daily',
        autoReset: 'none',
      );
      await controller.addRoutine(r);

      // Insert a prior-day completion directly into the DB.
      final yesterday = today().subtract(const Duration(days: 1));
      await db.insertRoutineEntry(
        RoutineEntry(routineId: r.id, date: yesterday, amount: 1),
      );

      final fresh = RoutineController(db);
      await fresh.load();
      final reloaded = fresh.routines.firstWhere((x) => x.id == r.id);
      // No entry today, but a prior completion exists -> still completed.
      expect(fresh.entryForToday(r.id), isNull);
      expect(fresh.isTodayCompleted(reloaded), isTrue);
    });
  });
}
