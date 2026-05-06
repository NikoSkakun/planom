import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import '../database/database_service.dart';
import '../models/task.dart';

enum TaskSortOrder { defaultOrder, creationDate, name, priority, dateTime }

class TaskController with ChangeNotifier {
  TaskController(this._db);

  final DatabaseService _db;
  List<Task> _tasks = [];

  TaskSortOrder _sortOrder = TaskSortOrder.defaultOrder;
  TaskSortOrder get sortOrder => _sortOrder;

  void setSortOrder(TaskSortOrder order) {
    if (_sortOrder == order) return;
    _sortOrder = order;
    notifyListeners();
  }

  List<Task> get inboxTasks => List.unmodifiable(
      _completedLast(_applySort(_tasks.where((t) => t.listId == null))));

  int get inboxUncompletedCount =>
      _tasks.where((t) => t.listId == null && !t.isCompleted).length;

  List<Task> get todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _completedLast(_applySort(_tasks.where((t) {
      if (t.dueDate == null) return false;
      final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      if (due == today) return true;
      if (due.isBefore(today)) return !t.isCompleted;
      return false;
    })));
  }

  int get todayUncompletedCount =>
      todayTasks.where((t) => !t.isCompleted).length;

  List<Task> get upcomingTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final filtered = _tasks.where((t) {
      if (t.dueDate == null) return false;
      final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return due.isAfter(today);
    }).toList()
      ..sort((a, b) {
        final dc = a.dueDate!.compareTo(b.dueDate!);
        if (dc != 0) return dc;
        return (a.doTime ?? 0).compareTo(b.doTime ?? 0);
      });
    return _completedLast(filtered);
  }

  int get upcomingUncompletedCount =>
      upcomingTasks.where((t) => !t.isCompleted).length;

  List<Task> tasksForDate(DateTime date) => _tasks
      .where((t) =>
          t.dueDate != null &&
          t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day)
      .toList();

  List<Task> tasksForList(String listId) => List.unmodifiable(
      _completedLast(_applySort(_tasks.where((t) => t.listId == listId))));

  int uncompletedCountForList(String listId) =>
      _tasks.where((t) => t.listId == listId && !t.isCompleted).length;

  Future<void> load() async {
    _tasks = await _db.getTasks();
    _updateBadge();
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    await _db.insertTask(task);
    _tasks = [task, ..._tasks];
    _updateBadge();
    notifyListeners();
  }

  Future<void> updateTask(Task updated) async {
    await _db.updateTask(updated);
    final i = _tasks.indexWhere((t) => t.id == updated.id);
    if (i == -1) return;
    _tasks = [..._tasks]..[i] = updated;
    _updateBadge();
    notifyListeners();
  }

  Future<void> toggleCompleted(String id) async {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    final updated = _tasks[i].copyWith(isCompleted: !_tasks[i].isCompleted);
    await _db.updateTask(updated);
    _tasks = [..._tasks]..[i] = updated;
    _updateBadge();
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    await _db.deleteTask(id);
    _tasks = _tasks.where((t) => t.id != id).toList();
    _updateBadge();
    notifyListeners();
  }

  Future<void> deleteTasksForList(String listId) async {
    await _db.deleteTasksForList(listId);
    _tasks = _tasks.where((t) => t.listId != listId).toList();
    _updateBadge();
    notifyListeners();
  }

  /// Reorders tasks in a scope (inbox when [listId] is null, or a specific list).
  /// [oldIndex] and [newIndex] are positions in the displayed list (after
  /// [_completedLast] is applied), matching what the UI's SliverReorderableList
  /// reports.
  Future<void> reorderTasks({
    required String? listId,
    required int oldIndex,
    required int newIndex,
  }) async {
    // Build the currently displayed list for this scope.
    final scopeRaw = _tasks.where((t) => t.listId == listId).toList();
    _sortByDefault(scopeRaw);
    final displayed = _completedLast(scopeRaw);

    // SliverReorderableList passes newIndex *before* the removed item is
    // taken out; adjust when moving downward.
    if (newIndex > oldIndex) newIndex--;
    final task = displayed.removeAt(oldIndex);
    displayed.insert(newIndex, task);

    // Assign sequential sortOrder so the new positions are persisted (1-indexed,
    // queried ASC so 1 = top of list).
    for (int i = 0; i < displayed.length; i++) {
      displayed[i] = displayed[i].copyWith(sortOrder: i + 1);
    }

    // Patch _tasks in place.
    for (final updated in displayed) {
      final idx = _tasks.indexWhere((t) => t.id == updated.id);
      if (idx != -1) _tasks[idx] = updated;
    }

    await _db.updateTaskSortOrders(displayed);
    notifyListeners();
  }

  // ── Sorting helpers ──────────────────────────────────────────────────────

  Iterable<Task> _applySort(Iterable<Task> tasks) {
    switch (_sortOrder) {
      case TaskSortOrder.defaultOrder:
        final list = tasks.toList();
        _sortByDefault(list);
        return list;
      case TaskSortOrder.creationDate:
        return tasks.toList()
          ..sort((a, b) => b.creationDate.compareTo(a.creationDate));
      case TaskSortOrder.name:
        return tasks.toList()
          ..sort((a, b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case TaskSortOrder.priority:
        return tasks.toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));
      case TaskSortOrder.dateTime:
        return tasks.toList()
          ..sort((a, b) {
            if (a.dueDate == null && b.dueDate == null) return 0;
            if (a.dueDate == null) return 1;
            if (b.dueDate == null) return -1;
            final dc = a.dueDate!.compareTo(b.dueDate!);
            if (dc != 0) return dc;
            return (a.doTime ?? 0).compareTo(b.doTime ?? 0);
          });
    }
  }

  static void _sortByDefault(List<Task> list) {
    list.sort((a, b) {
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return b.creationDate.compareTo(a.creationDate);
    });
  }

  /// Incomplete tasks first (preserving current order), completed at end.
  static List<Task> _completedLast(Iterable<Task> tasks) {
    final incomplete = <Task>[];
    final completed = <Task>[];
    for (final t in tasks) {
      (t.isCompleted ? completed : incomplete).add(t);
    }
    return [...incomplete, ...completed];
  }

  void _updateBadge() {
    final count = todayUncompletedCount;
    if (count > 0) {
      FlutterAppBadger.updateBadgeCount(count);
    } else {
      FlutterAppBadger.removeBadge();
    }
  }
}
