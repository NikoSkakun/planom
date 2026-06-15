import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/routine.dart';
import '../models/routine_entry.dart';
import '../models/routine_reminder.dart';
import '../notifications/notification_service.dart';

/// A reconstructed interval occurrence: its scheduled date and, if done, the
/// date the completion was recorded on (null while still open).
class RoutineOccurrence {
  const RoutineOccurrence(this.scheduled, this.completed);
  final DateTime scheduled;
  final DateTime? completed;
  bool get isOpen => completed == null;
}

/// Owns the list of routines and their per-day progress entries.
///
/// Each calendar day is tracked independently by a [RoutineEntry] row, so a
/// routine "resets" every day and the full history is preserved. All progress
/// queries take an explicit `date` so the UI can show and edit any day.
///
/// A routine appears on a given day per its schedule:
/// - `daily` every day,
/// - `specific_days` only on its selected weekdays,
/// - `interval` every N days from its start date. In `waitForCompletion` mode
///   an occurrence stays visible (overdue) from its scheduled date through
///   today until completed, and the next one is anchored to the completion.
class RoutineController with ChangeNotifier {
  RoutineController(this._db);

  final DatabaseService _db;
  List<Routine> _routines = [];
  List<RoutineEntry> _entries = [];

  List<Routine> get routines => List.unmodifiable(_routines);

  Future<void> load() async {
    _routines = await _db.getRoutines();
    _entries = await _db.getRoutineEntries();
    notifyListeners();
    for (final r in _routines) {
      _syncReminders(r);
    }
  }

  static DateTime normalizeDate(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  // Calendar-day index (UTC midnight) so day arithmetic is DST-safe.
  static int _epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// The day a routine starts being active (falls back to its creation day).
  DateTime startFloor(Routine r) =>
      normalizeDate(r.startDate ?? r.creationDate);

  int _interval(Routine r) {
    final v = r.intervalDays ?? 1;
    return v < 1 ? 1 : v;
  }

  // ── Visibility ─────────────────────────────────────────────────────────────

  /// Routines that should appear on [date], in their stored order.
  List<Routine> routinesForDate(DateTime date) {
    final day = normalizeDate(date);
    return _routines.where((r) => _appearsOn(r, day)).toList();
  }

  /// Convenience for the default "today" view.
  List<Routine> get todayRoutines => routinesForDate(DateTime.now());

  /// Count of today's routines that aren't completed yet (used by the app
  /// icon badge when routines are included).
  int get todayUncompletedCount =>
      todayRoutines.where((r) => !isTodayCompleted(r)).length;

  bool _appearsOn(Routine r, DateTime day) {
    if (_epochDay(day) < _epochDay(startFloor(r))) return false;
    switch (r.frequencyType) {
      case 'specific_days':
        // Month mode (selected days-of-month) takes precedence over weekly.
        final monthdays = r.monthdays;
        if (monthdays != null && monthdays.isNotEmpty) {
          return monthdays.contains(day.day);
        }
        return r.weekdays?.contains(day.weekday - 1) ?? false;
      case 'interval':
        return _intervalAppearsOn(r, day);
      case 'daily':
      default:
        return true;
    }
  }

  bool _intervalAppearsOn(Routine r, DateTime day) {
    final start = startFloor(r);
    if (!r.waitForCompletion) {
      return (_epochDay(day) - _epochDay(start)) % _interval(r) == 0;
    }
    final today = normalizeDate(DateTime.now());
    for (final o in intervalOccurrences(r)) {
      if (o.completed != null) {
        if (_epochDay(o.completed!) == _epochDay(day)) return true;
      } else if (_epochDay(day) >= _epochDay(o.scheduled) &&
          _epochDay(day) <= _epochDay(today)) {
        return true;
      }
    }
    return false;
  }

  /// Reconstructs the occurrence sequence for a `waitForCompletion` interval
  /// routine from its completion history. The final entry is the open
  /// occurrence (`completed == null`). Empty for other routine kinds.
  List<RoutineOccurrence> intervalOccurrences(Routine r) {
    if (r.frequencyType != 'interval' || !r.waitForCompletion) return const [];
    final result = <RoutineOccurrence>[];
    var scheduled = startFloor(r);
    for (final c in _completionDates(r)) {
      result.add(RoutineOccurrence(scheduled, c));
      scheduled = _addDays(c, _interval(r));
    }
    result.add(RoutineOccurrence(scheduled, null));
    return result;
  }

  /// Scheduled date of the current open occurrence (interval+wait only).
  DateTime? openOccurrenceDate(Routine r) {
    final occs = intervalOccurrences(r);
    return occs.isEmpty ? null : occs.last.scheduled;
  }

  /// True when [date] is past the open occurrence's scheduled date and the
  /// occurrence isn't yet completed there (interval+wait only).
  bool isOverdueOn(Routine r, DateTime date) {
    final open = openOccurrenceDate(r);
    if (open == null) return false;
    final day = normalizeDate(date);
    return _epochDay(day) > _epochDay(open) && !isCompletedOnDate(r, day);
  }

  List<DateTime> _completionDates(Routine r) {
    final goal = goalFor(r);
    final dates = _entries
        .where((e) => e.routineId == r.id && e.amount >= goal)
        .map((e) => normalizeDate(e.date))
        .toList()
      ..sort();
    return dates;
  }

  // ── Progress ─────────────────────────────────────────────────────────────

  /// The progress entry for a routine on a specific day, or null if untouched.
  RoutineEntry? entryForDate(String routineId, DateTime date) {
    final day = normalizeDate(date);
    for (final e in _entries) {
      if (e.routineId == routineId && normalizeDate(e.date) == day) return e;
    }
    return null;
  }

  RoutineEntry? entryForToday(String routineId) =>
      entryForDate(routineId, DateTime.now());

  /// The earliest day on which any routine progress was recorded, or null when
  /// there is no history. Used by the Day view's day selector to know how far
  /// back the user can scroll.
  DateTime? get earliestEntryDate {
    DateTime? min;
    for (final e in _entries) {
      final d = normalizeDate(e.date);
      if (min == null || d.isBefore(min)) min = d;
    }
    return min;
  }

  /// The earliest start day (start date, falling back to creation date) across
  /// all routines, or null when there are none. Lets the Day view scroll back
  /// far enough to reach an old, never-completed routine's first occurrence.
  DateTime? get earliestStartDate {
    DateTime? min;
    for (final r in _routines) {
      final d = startFloor(r);
      if (min == null || d.isBefore(min)) min = d;
    }
    return min;
  }

  int progressForDate(String routineId, DateTime date) =>
      entryForDate(routineId, date)?.amount ?? 0;

  int todayProgress(String routineId) =>
      progressForDate(routineId, DateTime.now());

  /// The goal threshold that marks a routine complete for a day.
  int goalFor(Routine r) =>
      r.goalType == 'achieve_all' ? 1 : (r.goalAmount ?? 1);

  bool isCompletedOnDate(Routine r, DateTime date) =>
      progressForDate(r.id, date) >= goalFor(r);

  bool isTodayCompleted(Routine r) => isCompletedOnDate(r, DateTime.now());

  /// A routine that has reached its goal but is configured to keep tracking
  /// progress afterwards. Such routines sit in a "middle" state in the day
  /// list — done, yet still interactive — rather than sinking to the bottom.
  bool isContinuingOnDate(Routine r, DateTime date) =>
      r.continueAfterCompletion && isCompletedOnDate(r, date);

  /// Records progress for [r] on [date].
  ///
  /// - achieve_all: toggles done/undone.
  /// - certain_amount: adds `recordAmount`; once the goal is reached another
  ///   tap wraps back to 0 so a day can be un-completed/corrected.
  Future<void> recordProgress(Routine r, [DateTime? date]) async {
    final day = normalizeDate(date ?? DateTime.now());
    final existing = entryForDate(r.id, day);
    final goal = goalFor(r);
    final current = existing?.amount ?? 0;

    final int next;
    if (r.continueAfterCompletion) {
      // Keep tracking beyond the goal — taps never auto-reset, so progress can
      // accumulate past completion (the "continue tracking" middle state).
      next = current + (r.goalType == 'achieve_all' ? 1 : (r.recordAmount ?? 1));
    } else if (r.goalType == 'achieve_all') {
      next = current >= 1 ? 0 : 1;
    } else {
      final add = r.recordAmount ?? 1;
      next = current >= goal ? 0 : current + add;
    }
    await _setAmount(r.id, day, existing, next);
    notifyListeners();

    // Reactively (re)schedule reminders. "After each" reminders are anchored to
    // this tap when progress was added today and the goal isn't met yet.
    final today = normalizeDate(DateTime.now());
    final anchor = (_epochDay(day) == _epochDay(today) && next > current && next < goal)
        ? DateTime.now()
        : null;
    _syncReminders(r, afterEachAnchor: anchor);
  }

  /// Sets the absolute recorded amount for [r] on [date] (clamped to ≥ 0).
  /// Used by manual-entry routines where the user types the amount completed.
  Future<void> setProgress(Routine r, DateTime date, int amount) async {
    final day = normalizeDate(date);
    final existing = entryForDate(r.id, day);
    await _setAmount(r.id, day, existing, amount < 0 ? 0 : amount);
    notifyListeners();
    _syncReminders(r);
  }

  Future<void> _setAmount(
      String routineId, DateTime day, RoutineEntry? existing, int amount) async {
    if (existing == null) {
      final entry =
          RoutineEntry(routineId: routineId, date: day, amount: amount);
      await _db.insertRoutineEntry(entry);
      _entries.insert(0, entry);
    } else {
      final updated = existing.copyWith(amount: amount);
      await _db.updateRoutineEntry(updated);
      final i = _entries.indexWhere((e) => e.id == updated.id);
      if (i != -1) _entries[i] = updated;
    }
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> addRoutine(Routine routine) async {
    // New routines go to the end of the manual order.
    final maxOrder = _routines.fold<int>(
        -1, (m, r) => r.sortOrder > m ? r.sortOrder : m);
    final ordered = routine.sortOrder == 0
        ? routine.copyWith(sortOrder: maxOrder + 1)
        : routine;
    await _db.insertRoutine(ordered);
    _routines.add(ordered);
    notifyListeners();
    _syncReminders(ordered);
  }

  /// Moves the routine at [oldIndex] to [newIndex] within the full ordered
  /// list and persists the new manual order.
  Future<void> reorderRoutines(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _routines.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target > _routines.length - 1) target = _routines.length - 1;
    final moved = _routines.removeAt(oldIndex);
    _routines.insert(target, moved);
    for (var i = 0; i < _routines.length; i++) {
      _routines[i] = _routines[i].copyWith(sortOrder: i);
    }
    notifyListeners();
    await _db.updateRoutineSortOrders(_routines);
  }

  Future<void> updateRoutine(Routine updated) async {
    await _db.updateRoutine(updated);
    final i = _routines.indexWhere((r) => r.id == updated.id);
    if (i != -1) _routines[i] = updated;
    notifyListeners();
    _syncReminders(updated);
  }

  Future<void> deleteRoutine(String id) async {
    await _db.deleteRoutine(id);
    _routines.removeWhere((r) => r.id == id);
    _entries.removeWhere((e) => e.routineId == id);
    notifyListeners();
    NotificationService.instance.cancelRoutineReminders(id);
  }

  // ── Reminders ──────────────────────────────────────────────────────────────

  /// Number of planned iterations per active day (for `spread` reminders).
  int iterationsPerDay(Routine r) {
    if (r.goalType != 'certain_amount') return 1;
    final goal = r.goalAmount ?? 1;
    final step = (r.recordAmount ?? 1) < 1 ? 1 : r.recordAmount!;
    return math.max(1, (goal / step).ceil());
  }

  /// Concrete future fire times for [r]'s `time` / `spread` reminders across the
  /// next [horizonDays] active days. `afterEach` reminders are handled
  /// reactively via [afterEachAnchor].
  List<DateTime> reminderFireTimes(
    Routine r, {
    int horizonDays = 16,
    DateTime? afterEachAnchor,
  }) {
    if (r.reminders.isEmpty) return const [];
    final now = DateTime.now();
    final today = normalizeDate(now);
    final times = <DateTime>[];

    // The active days within the horizon to attach time/spread reminders to.
    final activeDays = <DateTime>[];
    if (r.frequencyType == 'interval' && r.waitForCompletion) {
      // The next occurrence isn't on a fixed grid; use the open occurrence
      // (clamped to today if it's already overdue).
      final open = openOccurrenceDate(r);
      if (open != null) {
        final day = open.isBefore(today) ? today : open;
        if (_epochDay(day) - _epochDay(today) <= horizonDays &&
            !isCompletedOnDate(r, day)) {
          activeDays.add(day);
        }
      }
    } else {
      for (int i = 0; i <= horizonDays; i++) {
        final day = _addDays(today, i);
        if (_appearsOn(r, day) && !isCompletedOnDate(r, day)) {
          activeDays.add(day);
        }
      }
    }

    for (final day in activeDays) {
      for (final rem in r.reminders) {
        switch (rem.type) {
          case RoutineReminder.typeTime:
            times.add(_at(day, rem.value));
            break;
          case RoutineReminder.typeSpread:
            final every = (rem.interval ?? 60) < 1 ? 60 : rem.interval!;
            final count = iterationsPerDay(r);
            for (int k = 0; k < count; k++) {
              final minute = rem.value + k * every;
              if (minute > 1439) break; // stays within the day
              times.add(_at(day, minute));
            }
            break;
          // afterEach is reactive (see below).
        }
      }
    }

    if (afterEachAnchor != null) {
      for (final rem in r.reminders) {
        if (rem.type == RoutineReminder.typeAfterEach) {
          times.add(afterEachAnchor.add(Duration(minutes: rem.value)));
        }
      }
    }

    return times.where((t) => t.isAfter(now)).toList()..sort();
  }

  static DateTime _at(DateTime day, int minuteOfDay) =>
      DateTime(day.year, day.month, day.day, minuteOfDay ~/ 60, minuteOfDay % 60);

  void _syncReminders(Routine r, {DateTime? afterEachAnchor}) {
    final times = reminderFireTimes(r, afterEachAnchor: afterEachAnchor);
    NotificationService.instance
        .scheduleRoutineReminders(r.id, r.name, times);
  }
}
