import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/routine.dart';
import '../models/routine_entry.dart';

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

  static DateTime _normalizeDate(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// Routines that should appear in today's list.
  List<Routine> get todayRoutines {
    final today = _normalizeDate(DateTime.now());
    // Dart weekday: 1=Mon … 7=Sun; convert to 0=Mon … 6=Sun
    final todayWeekday = today.weekday - 1;

    return _routines.where((r) {
      if (r.frequencyType == 'daily') {
        final days = r.weekdays ?? [0, 1, 2, 3, 4, 5, 6];
        return days.contains(todayWeekday);
      } else {
        // days_after_complete: show when today >= last completion + gap
        final lastCompletion = _lastCompletedEntry(r);
        if (lastCompletion == null) return true; // never completed
        final nextDate = _normalizeDate(lastCompletion.date)
            .add(Duration(days: r.daysAfterComplete ?? 1));
        return !today.isBefore(nextDate);
      }
    }).toList();
  }

  /// Today's entry for a routine (null if none recorded yet today).
  RoutineEntry? entryForToday(String routineId) {
    final today = _normalizeDate(DateTime.now());
    for (final e in _entries) {
      if (e.routineId == routineId && _normalizeDate(e.date) == today) {
        return e;
      }
    }
    return null;
  }

  /// Current progress amount to display for a routine today.
  int todayProgress(String routineId) {
    final routine = _routineById(routineId);
    if (routine == null) return 0;
    final todayEntry = entryForToday(routineId);
    if (todayEntry != null) return todayEntry.amount;
    // autoReset='none': carry over last recorded amount
    if (routine.autoReset == 'none') {
      return _lastEntryForRoutine(routineId)?.amount ?? 0;
    }
    return 0;
  }

  bool isTodayCompleted(Routine r) {
    if (r.goalType == 'achieve_all') {
      if (r.autoReset == 'none') {
        // stays completed if ever completed (until toggled off today)
        final todayEntry = entryForToday(r.id);
        if (todayEntry != null) return todayEntry.amount >= 1;
        return _lastCompletedEntry(r) != null;
      }
      final entry = entryForToday(r.id);
      return entry != null && entry.amount >= 1;
    }
    return todayProgress(r.id) >= (r.goalAmount ?? 1);
  }

  /// Record one unit of progress (toggle for achieve_all, +recordAmount for certain_amount).
  Future<void> recordProgress(Routine r) async {
    final today = _normalizeDate(DateTime.now());
    final existing = entryForToday(r.id);

    if (r.goalType == 'achieve_all') {
      if (existing == null) {
        final entry = RoutineEntry(routineId: r.id, date: today, amount: 1);
        await _db.insertRoutineEntry(entry);
        _entries.insert(0, entry);
      } else {
        final updated = existing.copyWith(amount: existing.amount >= 1 ? 0 : 1);
        await _db.updateRoutineEntry(updated);
        _replaceEntry(updated);
      }
    } else {
      final add = r.recordAmount ?? 1;
      if (existing == null) {
        final startAmount = r.autoReset == 'none'
            ? (_lastEntryForRoutine(r.id)?.amount ?? 0) + add
            : add;
        final entry =
            RoutineEntry(routineId: r.id, date: today, amount: startAmount);
        await _db.insertRoutineEntry(entry);
        _entries.insert(0, entry);
      } else {
        final updated = existing.copyWith(amount: existing.amount + add);
        await _db.updateRoutineEntry(updated);
        _replaceEntry(updated);
      }
    }
    notifyListeners();
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

  Routine? _routineById(String id) {
    for (final r in _routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  RoutineEntry? _lastEntryForRoutine(String routineId) {
    RoutineEntry? latest;
    for (final e in _entries) {
      if (e.routineId == routineId) {
        if (latest == null || e.date.isAfter(latest.date)) latest = e;
      }
    }
    return latest;
  }

  RoutineEntry? _lastCompletedEntry(Routine r) {
    RoutineEntry? latest;
    for (final e in _entries) {
      if (e.routineId != r.id) continue;
      final completed = r.goalType == 'achieve_all'
          ? e.amount >= 1
          : e.amount >= (r.goalAmount ?? 1);
      if (completed) {
        if (latest == null || e.date.isAfter(latest.date)) latest = e;
      }
    }
    return latest;
  }

  void _replaceEntry(RoutineEntry updated) {
    final i = _entries.indexWhere((e) => e.id == updated.id);
    if (i != -1) _entries[i] = updated;
  }
}
