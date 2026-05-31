import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/routine.dart';
import '../models/routine_entry.dart';

/// Owns the list of routines and their per-day progress entries.
///
/// Each calendar day is tracked independently by a [RoutineEntry] row, so a
/// routine automatically "resets" every day and the full history is preserved
/// (useful for revisiting past days and, later, for streaks). All progress
/// queries take an explicit `date` so the UI can show and edit any day, not
/// just today. A routine shows on a given day per its schedule: `daily` every
/// day, `specific_days` only on its selected weekdays.
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
  }

  static DateTime normalizeDate(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// Routines that should appear on [date], from their creation day onward
  /// (never before they existed, so past-day history stays accurate). A
  /// `specific_days` routine additionally only shows on its selected weekdays.
  List<Routine> routinesForDate(DateTime date) {
    final day = normalizeDate(date);
    // Dart weekday is 1=Mon … 7=Sun; convert to 0=Mon … 6=Sun.
    final weekdayIndex = day.weekday - 1;
    return _routines.where((r) {
      if (normalizeDate(r.creationDate).isAfter(day)) return false;
      if (r.frequencyType == 'specific_days') {
        final days = r.weekdays;
        return days != null && days.contains(weekdayIndex);
      }
      return true;
    }).toList();
  }

  /// Convenience for the default "today" view.
  List<Routine> get todayRoutines => routinesForDate(DateTime.now());

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

  /// Recorded amount for a routine on [date] (0 if nothing recorded).
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
    if (r.goalType == 'achieve_all') {
      next = current >= 1 ? 0 : 1;
    } else {
      final add = r.recordAmount ?? 1;
      next = current >= goal ? 0 : current + add;
    }
    await _setAmount(r.id, day, existing, next);
    notifyListeners();
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

  Future<void> addRoutine(Routine routine) async {
    await _db.insertRoutine(routine);
    _routines.add(routine);
    notifyListeners();
  }

  Future<void> updateRoutine(Routine updated) async {
    await _db.updateRoutine(updated);
    final i = _routines.indexWhere((r) => r.id == updated.id);
    if (i != -1) _routines[i] = updated;
    notifyListeners();
  }

  Future<void> deleteRoutine(String id) async {
    await _db.deleteRoutine(id);
    _routines.removeWhere((r) => r.id == id);
    _entries.removeWhere((e) => e.routineId == id);
    notifyListeners();
  }
}
