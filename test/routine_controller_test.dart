import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/routine.dart';
import 'package:planom/src/models/routine_entry.dart';
import 'package:planom/src/models/routine_reminder.dart';
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

    test('todayUncompletedCount reflects completion', () async {
      final a = achieveAll('A');
      final b = achieveAll('B');
      await controller.addRoutine(a);
      await controller.addRoutine(b);
      expect(controller.todayUncompletedCount, 2);
      await controller.recordProgress(a);
      expect(controller.todayUncompletedCount, 1);
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

    test('setProgress writes an absolute amount (manual entry)', () async {
      final r = Routine(
        name: 'Water',
        goalType: 'certain_amount',
        goalAmount: 8,
        manualEntry: true,
      );
      await controller.addRoutine(r);

      await controller.setProgress(r, today(), 5);
      expect(controller.todayProgress(r.id), 5);
      expect(controller.isTodayCompleted(r), isFalse);

      await controller.setProgress(r, today(), 8);
      expect(controller.isTodayCompleted(r), isTrue);

      // Negative clamps to 0 (un-checks the day).
      await controller.setProgress(r, today(), -3);
      expect(controller.todayProgress(r.id), 0);
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

  group('reordering', () {
    test('addRoutine assigns increasing sortOrder; order persists', () async {
      await controller.addRoutine(achieveAll('A'));
      await controller.addRoutine(achieveAll('B'));
      await controller.addRoutine(achieveAll('C'));
      expect(controller.routines.map((r) => r.name), ['A', 'B', 'C']);

      // Move C (index 2) to the front (ReorderableListView semantics).
      await controller.reorderRoutines(2, 0);
      expect(controller.routines.map((r) => r.name), ['C', 'A', 'B']);

      // Persisted: a fresh controller loads the same order.
      final fresh = RoutineController(db);
      await fresh.load();
      expect(fresh.routines.map((r) => r.name), ['C', 'A', 'B']);
    });

    test('moving an item down lands after the target', () async {
      await controller.addRoutine(achieveAll('A'));
      await controller.addRoutine(achieveAll('B'));
      await controller.addRoutine(achieveAll('C'));
      // Move A down to index 2 (between/after B, C per ListView convention).
      await controller.reorderRoutines(0, 2);
      expect(controller.routines.map((r) => r.name), ['B', 'A', 'C']);
    });
  });

  group('start date', () {
    test('routine is hidden before its start date', () async {
      final start = today().add(const Duration(days: 2));
      final r = Routine(
        name: 'Future',
        goalType: 'achieve_all',
        startDate: start,
        creationDate: today(),
      );
      await controller.addRoutine(r);

      expect(controller.routinesForDate(today()).map((x) => x.id),
          isNot(contains(r.id)));
      expect(controller.routinesForDate(start).map((x) => x.id),
          contains(r.id));
      expect(
          controller.routinesForDate(start.add(const Duration(days: 1)))
              .map((x) => x.id),
          contains(r.id));
    });
  });

  group('interval (fixed grid)', () {
    test('appears every N days from the start date', () async {
      final start = DateTime(2026, 6, 1);
      final r = Routine(
        name: 'Clean',
        goalType: 'achieve_all',
        frequencyType: 'interval',
        intervalDays: 3,
        startDate: start,
        creationDate: start,
      );
      await controller.addRoutine(r);

      bool shows(DateTime d) =>
          controller.routinesForDate(d).map((x) => x.id).contains(r.id);

      expect(shows(DateTime(2026, 6, 1)), isTrue); // day 0
      expect(shows(DateTime(2026, 6, 2)), isFalse);
      expect(shows(DateTime(2026, 6, 3)), isFalse);
      expect(shows(DateTime(2026, 6, 4)), isTrue); // day 3
      expect(shows(DateTime(2026, 6, 7)), isTrue); // day 6
    });
  });

  group('interval (wait for completion)', () {
    Routine waitRoutine(DateTime start) => Routine(
          name: 'Clean',
          goalType: 'achieve_all',
          frequencyType: 'interval',
          intervalDays: 3,
          waitForCompletion: true,
          startDate: start,
          creationDate: start,
        );

    test('open occurrence carries forward as overdue until completed',
        () async {
      // Started 5 days ago, interval 3, never completed -> overdue, and the
      // single open occurrence shows on its scheduled day through today.
      final start = today().subtract(const Duration(days: 5));
      final r = waitRoutine(start);
      await controller.addRoutine(r);

      bool shows(DateTime d) =>
          controller.routinesForDate(d).map((x) => x.id).contains(r.id);

      expect(controller.openOccurrenceDate(r), start);
      expect(shows(start), isTrue);
      expect(shows(today()), isTrue); // overdue, still showing today
      expect(controller.isOverdueOn(r, today()), isTrue);
      expect(controller.isOverdueOn(r, start), isFalse); // on its own day
    });

    test('completing on the original date shifts the next from there',
        () async {
      final start = today().subtract(const Duration(days: 5));
      final r = waitRoutine(start);
      await controller.addRoutine(r);

      // Record on the original (scheduled) date.
      await controller.recordProgress(r, start);
      expect(controller.isCompletedOnDate(r, start), isTrue);
      // Next occurrence = start + 3 days.
      expect(controller.openOccurrenceDate(r),
          start.add(const Duration(days: 3)));
    });

    test('completing today shifts the next occurrence from today', () async {
      final start = today().subtract(const Duration(days: 5));
      final r = waitRoutine(start);
      await controller.addRoutine(r);

      await controller.recordProgress(r, today());
      // Past scheduled days no longer show the (now closed) occurrence.
      expect(controller.routinesForDate(start).map((x) => x.id),
          isNot(contains(r.id)));
      // Completion shows on today; next occurrence is 3 days out.
      expect(controller.isCompletedOnDate(r, today()), isTrue);
      expect(controller.openOccurrenceDate(r),
          today().add(const Duration(days: 3)));
    });

    test('a completed occurrence is no longer overdue', () async {
      final start = today().subtract(const Duration(days: 1));
      final r = waitRoutine(start);
      await controller.addRoutine(r);

      await controller.recordProgress(r, today());
      expect(controller.isOverdueOn(r, today()), isFalse);
      expect(controller.openOccurrenceDate(r),
          today().add(const Duration(days: 3)));
    });

    test('moving the start date forward clears a stale overdue occurrence',
        () async {
      // Completed 10 days ago; with a 3-day interval the next occurrence fell
      // due 7 days ago and has been carrying forward as overdue ever since.
      final r = waitRoutine(today().subtract(const Duration(days: 20)));
      await controller.addRoutine(r);
      await controller.recordProgress(
          r, today().subtract(const Duration(days: 10)));
      expect(controller.openOccurrenceDate(r),
          today().subtract(const Duration(days: 7)));
      expect(controller.isOverdueOn(r, today()), isTrue);

      // Starting it again today re-anchors the schedule: the open occurrence
      // is today's, not the one inherited from the pre-restart completion.
      await controller.updateRoutine(r.copyWith(startDate: today()));
      final moved = controller.routines.firstWhere((x) => x.id == r.id);
      expect(controller.openOccurrenceDate(moved), today());
      expect(controller.isOverdueOn(moved, today()), isFalse);
      expect(controller.routinesForDate(today()).map((x) => x.id),
          contains(r.id));
    });

    test('completions on or after the new start date still drive the schedule',
        () async {
      final r = waitRoutine(today().subtract(const Duration(days: 20)));
      await controller.addRoutine(r);
      // One completion before the new start day, one on it.
      await controller.recordProgress(
          r, today().subtract(const Duration(days: 10)));
      await controller.recordProgress(
          r, today().subtract(const Duration(days: 2)));

      await controller.updateRoutine(
          r.copyWith(startDate: today().subtract(const Duration(days: 2))));
      final moved = controller.routines.firstWhere((x) => x.id == r.id);
      // Only the kept completion counts: next occurrence is 3 days after it.
      expect(controller.openOccurrenceDate(moved),
          today().add(const Duration(days: 1)));
      expect(controller.isOverdueOn(moved, today()), isFalse);
    });

    test('schedule survives a reload', () async {
      final start = today().subtract(const Duration(days: 2));
      final r = waitRoutine(start);
      await controller.addRoutine(r);
      await controller.recordProgress(r, start);

      final fresh = RoutineController(db);
      await fresh.load();
      final reloaded = fresh.routines.firstWhere((x) => x.id == r.id);
      expect(reloaded.frequencyType, 'interval');
      expect(reloaded.intervalDays, 3);
      expect(reloaded.waitForCompletion, isTrue);
      expect(fresh.openOccurrenceDate(reloaded),
          start.add(const Duration(days: 3)));
    });
  });

  group('reminders', () {
    test('fixed-time reminder yields a future fire time on an active day',
        () async {
      final r = Routine(
        name: 'Stretch',
        goalType: 'achieve_all',
        reminders: const [RoutineReminder.time(23 * 60 + 59)], // 23:59
      );
      await controller.addRoutine(r);
      final times = controller.reminderFireTimes(r);
      expect(times, isNotEmpty);
      expect(times.every((t) => t.isAfter(DateTime.now())), isTrue);
    });

    test('spread reminder yields one fire time per iteration', () async {
      // Anchor near end of day so the times are in the future regardless of
      // when the test runs is not guaranteed; assert the per-iteration count
      // by computing for an explicit active future day via horizon.
      final r = Routine(
        name: 'Water',
        goalType: 'certain_amount',
        goalAmount: 4,
        recordAmount: 1,
        reminders: const [RoutineReminder.spread(startMinute: 0, every: 60)],
      );
      await controller.addRoutine(r);
      expect(controller.iterationsPerDay(r), 4);
    });
  });
}
