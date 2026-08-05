import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../models/goal.dart';
import '../models/task.dart';
import '../tasks/task_controller.dart';
import '../utils/day_boundary.dart';

/// How much of a goal is done. [total] counts every task the goal currently
/// resolves to, so a goal whose rules pick up a new task immediately reads as
/// less complete — which is the point of a live goal.
class GoalProgress {
  const GoalProgress({required this.total, required this.completed});

  final int total;
  final int completed;

  int get remaining => total - completed;
  bool get isEmpty => total == 0;
  bool get isComplete => total > 0 && completed >= total;

  /// 0.0 … 1.0. An empty goal reads as 0 rather than "done".
  double get fraction => total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();
}

/// Owns the space's goals and resolves each one's task set on demand.
///
/// Nothing about a goal's membership is denormalised: [tasksForGoal] re-runs
/// the goal's sources against the live [TaskController] every call, so tasks
/// created after the goal was made join it automatically when they satisfy a
/// rule. Deletes are permanent (there's no Goals trash) but tombstoned, and
/// the UI pairs each with an Undo banner that re-inserts the row.
class GoalController with ChangeNotifier {
  GoalController(
    this._db, {
    required TaskController taskController,
    required FolderController folderController,
  })  : _tasks = taskController,
        _folders = folderController;

  final DatabaseService _db;
  final TaskController _tasks;
  final FolderController _folders;

  List<Goal> _goals = [];

  List<Goal> get goals => List.unmodifiable(_goals);

  Goal? goalById(String id) {
    for (final g in _goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  Future<void> load() async {
    _goals = await _db.getGoals();
    notifyListeners();
  }

  // ── Resolution ────────────────────────────────────────────────────────────

  /// Every task the goal currently tracks: the union of its sources,
  /// de-duplicated, uncompleted first (each group by due date then title) so
  /// the detail view reads like a work list.
  List<Task> tasksForGoal(Goal goal) {
    final seen = <String>{};
    final result = <Task>[];
    for (final source in goal.sources) {
      for (final task in _resolveSource(source)) {
        if (seen.add(task.id)) result.add(task);
      }
    }
    result.sort(_byWorkOrder);
    return List.unmodifiable(result);
  }

  GoalProgress progressFor(Goal goal) {
    final tasks = tasksForGoal(goal);
    return GoalProgress(
      total: tasks.length,
      completed: tasks.where((t) => t.isCompleted).length,
    );
  }

  /// The tasks one source contributes, before de-duplication. Public so the
  /// source editor can show a live "matches N tasks" preview while the user
  /// is still building the rule.
  List<Task> tasksForSource(GoalSource source) =>
      List.unmodifiable(_resolveSource(source));

  Iterable<Task> _resolveSource(GoalSource source) {
    if (source.kind == GoalSourceKind.manual) {
      // Hand-picked ids: skip any task that has since been deleted.
      return source.taskIds
          .map(_tasks.taskById)
          .whereType<Task>()
          .where((t) => !t.isDeleted);
    }
    // `allTasks` is every active, non-subtask task in the space — the same
    // pool the "All Tasks" smart list draws from.
    return _tasks.allTasks.where((t) => _matchesRule(source, t));
  }

  bool _matchesRule(GoalSource source, Task task) =>
      _inScope(source, task) &&
      _matchesTags(source, task) &&
      _matchesPriority(source, task) &&
      _matchesDate(source, task);

  bool _inScope(GoalSource source, Task task) {
    switch (source.scopeType) {
      case GoalScopeType.all:
        return true;
      case GoalScopeType.folders:
        if (task.listId == null) return false;
        for (final folderId in source.scopeIds) {
          if (_folders.listIdsInRecursive(folderId).contains(task.listId)) {
            return true;
          }
        }
        return false;
      case GoalScopeType.lists:
        return task.listId != null && source.scopeIds.contains(task.listId);
      case GoalScopeType.sections:
        // A section that has since been deleted leaves tasks pointing at a
        // ghost id; those must not keep counting toward the goal.
        return task.sectionId != null &&
            source.scopeIds.contains(task.sectionId) &&
            _folders.sectionById(task.sectionId!) != null;
    }
  }

  bool _matchesTags(GoalSource source, Task task) {
    if (source.tagIds.isEmpty) return true;
    for (final tagId in source.tagIds) {
      if (task.tagIds.contains(tagId)) return true;
    }
    return false;
  }

  bool _matchesPriority(GoalSource source, Task task) =>
      source.priorities.isEmpty || source.priorities.contains(task.priority);

  bool _matchesDate(GoalSource source, Task task) {
    final due = task.dueDate;
    final day = due == null ? null : DateTime(due.year, due.month, due.day);
    final today = DayBoundary.today();
    switch (source.dateFilter) {
      case GoalDateFilter.any:
        return true;
      case GoalDateFilter.noDate:
        return day == null;
      case GoalDateFilter.overdue:
        return day != null && day.isBefore(today);
      case GoalDateFilter.today:
        return day != null && day == today;
      case GoalDateFilter.tomorrow:
        return day != null && day == DayBoundary.tomorrow();
      case GoalDateFilter.thisWeek:
        if (day == null) return false;
        // Honours the user's first-day-of-week setting, and uses calendar
        // arithmetic so a DST change inside the week can't stretch it to 8
        // days or skip one.
        final start = DayBoundary.startOfWeek(today);
        final end = DateTime(start.year, start.month, start.day + 7);
        return !day.isBefore(start) && day.isBefore(end);
      case GoalDateFilter.thisMonth:
        return day != null &&
            day.year == today.year &&
            day.month == today.month;
      case GoalDateFilter.range:
        if (day == null) return false;
        final from = source.from;
        final to = source.to;
        if (from != null &&
            day.isBefore(DateTime(from.year, from.month, from.day))) {
          return false;
        }
        if (to != null && day.isAfter(DateTime(to.year, to.month, to.day))) {
          return false;
        }
        return true;
    }
  }

  /// Uncompleted before completed; then by due date (undated last), then by
  /// title so the order is stable between rebuilds.
  static int _byWorkOrder(Task a, Task b) {
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    final ad = a.dueDate, bd = b.dueDate;
    if (ad != null && bd != null) {
      final byDate = ad.compareTo(bd);
      if (byDate != 0) return byDate;
    } else if (ad != null) {
      return -1;
    } else if (bd != null) {
      return 1;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Re-inserts a goal exactly as it was, keeping its position. Used by the
  /// Undo banner — [addGoal] would treat a `sortOrder` of 0 as "unset" and
  /// send the first goal to the bottom of the list.
  Future<void> restoreGoal(Goal goal) async {
    await _db.insertGoal(goal);
    _goals = [..._goals, goal]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0
            ? byOrder
            : a.creationDate.compareTo(b.creationDate);
      });
    notifyListeners();
  }

  Future<void> addGoal(Goal goal) async {
    final withOrder =
        goal.sortOrder == 0 ? goal.copyWith(sortOrder: _nextSortOrder()) : goal;
    await _db.insertGoal(withOrder);
    _goals = [..._goals, withOrder]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  Future<void> updateGoal(Goal updated) async {
    await _db.updateGoal(updated);
    final i = _goals.indexWhere((g) => g.id == updated.id);
    if (i == -1) return;
    _goals = [..._goals]..[i] = updated;
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    await _db.deleteGoal(id);
    _goals = _goals.where((g) => g.id != id).toList();
    notifyListeners();
  }

  /// ReorderableListView semantics (the caller passes the raw indices).
  Future<void> reorderGoals(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _goals.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final next = [..._goals];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), moved);
    final renumbered = [
      for (var i = 0; i < next.length; i++) next[i].copyWith(sortOrder: i),
    ];
    await _db.updateGoalSortOrders(renumbered);
    _goals = renumbered;
    notifyListeners();
  }

  int _nextSortOrder() {
    var max = -1;
    for (final g in _goals) {
      if (g.sortOrder > max) max = g.sortOrder;
    }
    return max + 1;
  }
}
