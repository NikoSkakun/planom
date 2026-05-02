import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import '../database/database_service.dart';
import '../models/task.dart';

class TaskController with ChangeNotifier {
  TaskController(this._db);

  final DatabaseService _db;
  List<Task> _tasks = [];

  List<Task> get inboxTasks =>
      List.unmodifiable(_completedLast(_tasks.where((t) => t.listId == null)));

  int get inboxUncompletedCount =>
      _tasks.where((t) => t.listId == null && !t.isCompleted).length;

  List<Task> get todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _completedLast(_tasks.where((t) {
      if (t.dueDate == null) return false;
      final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return !due.isAfter(today);
    }));
  }

  int get todayUncompletedCount =>
      todayTasks.where((t) => !t.isCompleted).length;

  List<Task> tasksForDate(DateTime date) => _tasks
      .where((t) =>
          t.dueDate != null &&
          t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day)
      .toList();

  List<Task> tasksForList(String listId) =>
      List.unmodifiable(_completedLast(_tasks.where((t) => t.listId == listId)));

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

  /// Incomplete tasks first (preserving creationDate order), completed at end.
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
