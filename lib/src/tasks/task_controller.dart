import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import '../database/database_service.dart';
import '../models/task.dart';

enum TaskSortOrder { defaultOrder, creationDate, name, priority, dateTime }

class TaskController with ChangeNotifier {
  TaskController(this._db);

  final DatabaseService _db;
  List<Task> _tasks = [];
  List<Task> _trashedTasks = [];

  TaskSortOrder _sortOrder = TaskSortOrder.defaultOrder;
  final List<String> _completionOrder = [];
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

  List<Task> get allCompletedTasks =>
      _tasks.where((t) => t.isCompleted).toList();

  int get completedTasksCount => allCompletedTasks.length;

  List<Task> get trashedTasks => List.unmodifiable(_trashedTasks);

  Future<void> load() async {
    _tasks = await _db.getTasks();
    _trashedTasks = await _db.getTrashedTasks();
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
    final completing = !_tasks[i].isCompleted;
    final updated = _tasks[i].copyWith(
      isCompleted: completing,
      completionDate: completing ? DateTime.now() : null,
      clearCompletionDate: !completing,
    );
    await _db.updateTask(updated);
    _tasks = [..._tasks]..[i] = updated;
    if (updated.isCompleted) {
      _completionOrder.remove(id);
      _completionOrder.insert(0, id);
    } else {
      _completionOrder.remove(id);
    }
    _updateBadge();
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    final now = DateTime.now();
    final trashed = _tasks[i].copyWith(isDeleted: true, deletedDate: now);
    await _db.softDeleteTask(id, now);
    _tasks = _tasks.where((t) => t.id != id).toList();
    _trashedTasks = [trashed, ..._trashedTasks];
    _updateBadge();
    notifyListeners();
  }

  Future<void> deleteTasksForList(String listId) async {
    final now = DateTime.now();
    await _db.softDeleteTasksForList(listId, now);
    final toTrash = _tasks
        .where((t) => t.listId == listId)
        .map((t) => t.copyWith(isDeleted: true, deletedDate: now))
        .toList();
    _tasks = _tasks.where((t) => t.listId != listId).toList();
    _trashedTasks = [...toTrash, ..._trashedTasks];
    _updateBadge();
    notifyListeners();
  }

  Future<void> permanentlyDeleteTask(String id) async {
    await _db.permanentlyDeleteTask(id);
    _trashedTasks = _trashedTasks.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<void> permanentlyDeleteAllTrashed() async {
    await _db.clearTrashedTasks();
    _trashedTasks = [];
    notifyListeners();
  }

  Future<void> restoreTask(String id, String? targetListId) async {
    final i = _trashedTasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    final orig = _trashedTasks[i];
    final restored = orig.copyWith(
      listId: targetListId,
      clearListId: targetListId == null,
      isDeleted: false,
      clearDeletedDate: true,
    );
    await _db.restoreTask(id);
    if (targetListId != orig.listId) {
      await _db.updateTask(restored);
    }
    _trashedTasks = List.of(_trashedTasks)..removeAt(i);
    _tasks = [restored, ..._tasks];
    _updateBadge();
    notifyListeners();
  }

  /// Reorders tasks in a scope (inbox when [listId] is null, or a specific list).
  Future<void> reorderTasks({
    required String? listId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final scopeRaw = _tasks.where((t) => t.listId == listId).toList();
    _sortByDefault(scopeRaw);
    final displayed = _completedLast(scopeRaw);

    if (newIndex > oldIndex) newIndex--;
    final task = displayed.removeAt(oldIndex);
    displayed.insert(newIndex, task);

    for (int i = 0; i < displayed.length; i++) {
      displayed[i] = displayed[i].copyWith(sortOrder: i + 1);
    }

    for (final updated in displayed) {
      final idx = _tasks.indexWhere((t) => t.id == updated.id);
      if (idx != -1) _tasks[idx] = updated;
    }

    // Notify before awaiting the DB so SliverReorderableList sees the new
    // order on its next frame — otherwise the dropped item flashes back to
    // its original slot until the write completes.
    notifyListeners();
    await _db.updateTaskSortOrders(displayed);
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

  /// Incomplete tasks first, completed at end — most recently completed first.
  List<Task> _completedLast(Iterable<Task> tasks) {
    final incomplete = <Task>[];
    final completed = <Task>[];
    for (final t in tasks) {
      (t.isCompleted ? completed : incomplete).add(t);
    }
    completed.sort((a, b) {
      final ai = _completionOrder.indexOf(a.id);
      final bi = _completionOrder.indexOf(b.id);
      if (ai == -1 && bi == -1) return 0;
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
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
