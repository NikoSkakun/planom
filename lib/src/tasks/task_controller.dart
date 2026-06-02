import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import '../database/database_service.dart';
import '../models/recurrence.dart';
import '../models/tag.dart';
import '../models/task.dart';
import '../notifications/notification_service.dart';
import '../settings/settings_controller.dart';
import '../utils/platform_capabilities.dart';

enum TaskSortOrder { defaultOrder, creationDate, name, priority, dateTime }

/// Outcome of [TaskController.toggleCompleted], so callers can react to what
/// actually happened (e.g. only show an Undo banner when a task was checked
/// off, not when it was un-checked or when a recurring task merely advanced).
enum TaskToggleResult {
  /// The task transitioned from incomplete → completed.
  completed,

  /// The task transitioned from completed → incomplete.
  uncompleted,

  /// A recurring task's due date advanced to its next occurrence instead of
  /// being marked done.
  recurrenceAdvanced,

  /// Nothing happened (e.g. the id was not found).
  none,
}

class TaskController with ChangeNotifier {
  TaskController(this._db);

  final DatabaseService _db;

  // Optional context for the app icon badge. The controller computes the
  // count itself for task-only modes; for modes that involve events it asks
  // the host (SpaceManager / main wiring) via [_eventCountToday].
  SettingsController? _settings;
  int Function()? _eventCountToday;
  int Function()? _routineCountToday;
  List<String> Function(String folderId)? _listIdsInFolder;
  VoidCallback? _settingsListener;

  /// Wires the data the badge needs from outside the controller. Pass the
  /// global [SettingsController] and an optional getter that returns the
  /// count of today's not-yet-started events. Idempotent — calling again
  /// detaches the previous listener.
  void attachBadgeContext({
    SettingsController? settings,
    int Function()? eventCountToday,
    int Function()? routineCountToday,
    List<String> Function(String folderId)? listIdsInFolder,
  }) {
    if (_settings != null && _settingsListener != null) {
      _settings!.removeListener(_settingsListener!);
    }
    _settings = settings;
    _eventCountToday = eventCountToday;
    _routineCountToday = routineCountToday;
    _listIdsInFolder = listIdsInFolder;
    if (_settings != null) {
      _settingsListener = _updateBadge;
      _settings!.addListener(_settingsListener!);
    }
    _updateBadge();
  }

  /// Re-evaluate and apply the badge count. Hosts that drive event/task
  /// changes outside the controller (e.g. EventController) can call this to
  /// keep the badge in sync.
  void refreshBadge() => _updateBadge();
  List<Task> _tasks = [];
  List<Task> _trashedTasks = [];
  List<Tag> _tags = [];

  TaskSortOrder _sortOrder = TaskSortOrder.defaultOrder;
  final List<String> _completionOrder = [];
  TaskSortOrder get sortOrder => _sortOrder;

  void setSortOrder(TaskSortOrder order) {
    if (_sortOrder == order) return;
    _sortOrder = order;
    notifyListeners();
  }

  // Subtasks (parentTaskId != null) are scoped to their parent's detail view
  // and intentionally excluded from every top-level list, smart list, and
  // count below. Use `subtasksOf(parentId)` to access them.
  Iterable<Task> get _topLevel => _tasks.where((t) => t.parentTaskId == null);

  List<Task> get inboxTasks => List.unmodifiable(
      _completedLast(_applySort(_topLevel.where((t) => t.listId == null))));

  int get inboxUncompletedCount =>
      _topLevel.where((t) => t.listId == null && !t.isCompleted).length;

  List<Task> get todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _completedLast(_applySort(_topLevel.where((t) {
      if (t.dueDate == null) return false;
      final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      if (due == today) return true;
      if (due.isBefore(today)) return !t.isCompleted;
      return false;
    })));
  }

  int get todayUncompletedCount =>
      todayTasks.where((t) => !t.isCompleted).length;

  List<Task> get tomorrowTasks {
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return _completedLast(_applySort(_topLevel.where((t) {
      if (t.dueDate == null) return false;
      final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return due == tomorrow;
    })));
  }

  int get tomorrowUncompletedCount =>
      tomorrowTasks.where((t) => !t.isCompleted).length;

  List<Task> get upcomingTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final filtered = _topLevel.where((t) {
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

  List<Task> tasksForDate(DateTime date) => _topLevel
      .where((t) =>
          t.dueDate != null &&
          t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day)
      .toList();

  List<Task> tasksForList(String listId) => List.unmodifiable(
      _completedLast(_applySort(_topLevel.where((t) => t.listId == listId))));

  /// Active (non-completed) tasks in [listId] that live in [sectionId].
  /// Pass null to scope to the implicit "Top" group (no section assigned).
  List<Task> tasksForListSection(String listId, String? sectionId) {
    final filtered = _topLevel.where((t) =>
        t.listId == listId && !t.isCompleted && t.sectionId == sectionId);
    final list = filtered.toList();
    _sortByDefault(list);
    return List.unmodifiable(list);
  }

  /// Completed tasks within [listId] — these always live in the implicit
  /// "Completed" virtual section, regardless of which section they were in
  /// before being checked off.
  List<Task> completedTasksForList(String listId) {
    final filtered =
        _topLevel.where((t) => t.listId == listId && t.isCompleted);
    final list = filtered.toList();
    _sortByDefault(list);
    return List.unmodifiable(list);
  }

  int uncompletedCountForList(String listId) =>
      _topLevel.where((t) => t.listId == listId && !t.isCompleted).length;

  /// Sum of uncompleted top-level tasks across every list in [listIds].
  int uncompletedCountForLists(Iterable<String> listIds) {
    if (listIds.isEmpty) return 0;
    final set = listIds.toSet();
    return _topLevel
        .where((t) =>
            !t.isCompleted && t.listId != null && set.contains(t.listId))
        .length;
  }

  List<Task> get allCompletedTasks =>
      _topLevel.where((t) => t.isCompleted).toList();

  int get completedTasksCount => allCompletedTasks.length;

  /// Every top-level task across every list and Inbox (active, non-trashed).
  /// Drives the "All Tasks" smart list.
  List<Task> get allTasks =>
      List.unmodifiable(_completedLast(_applySort(_topLevel)));

  int get allTasksCount => _topLevel.length;

  int get allTasksUncompletedCount =>
      _topLevel.where((t) => !t.isCompleted).length;

  /// Subtasks of [parentId], in creation order (oldest first) so the list reads
  /// like a checklist rather than a feed.
  List<Task> subtasksOf(String parentId) {
    final subs = _tasks.where((t) => t.parentTaskId == parentId).toList()
      ..sort((a, b) => a.creationDate.compareTo(b.creationDate));
    return List.unmodifiable(subs);
  }

  int subtaskCount(String parentId) =>
      _tasks.where((t) => t.parentTaskId == parentId).length;

  int subtaskCompletedCount(String parentId) =>
      _tasks.where((t) => t.parentTaskId == parentId && t.isCompleted).length;

  List<Task> get trashedTasks => List.unmodifiable(_trashedTasks);

  Task? taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> load() async {
    _tasks = await _db.getTasks();
    _trashedTasks = await _db.getTrashedTasks();
    _tags = (await _db.getTags()).map(Tag.fromMap).toList();
    _updateBadge();
    notifyListeners();
  }

  // ── Tags ─────────────────────────────────────────────────────────────────

  List<Tag> get tags => List.unmodifiable(_tags);

  Tag? tagById(String id) {
    for (final t in _tags) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Tag> tagsForTask(Task task) =>
      task.tagIds.map(tagById).whereType<Tag>().toList();

  List<Task> tasksWithTag(String tagId) =>
      _topLevel.where((t) => t.tagIds.contains(tagId)).toList();

  int taskCountForTag(String tagId) =>
      _topLevel.where((t) => t.tagIds.contains(tagId)).length;

  /// Returns the existing tag if one with the same case-insensitive name
  /// exists; otherwise creates and persists a new one.
  Future<Tag> addOrGetTag(String name, {int? color}) async {
    final trimmed = name.trim();
    final existing = _tags.firstWhere(
      (t) => t.name.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => Tag(name: ''),
    );
    if (existing.name.isNotEmpty) return existing;
    final tag = Tag(name: trimmed, color: color);
    await _db.insertTag(tag.toMap());
    _tags = [..._tags, tag]..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    return tag;
  }

  Future<void> updateTag(Tag tag) async {
    await _db.updateTag(tag.toMap());
    final i = _tags.indexWhere((t) => t.id == tag.id);
    if (i == -1) return;
    _tags = [..._tags]..[i] = tag;
    _tags.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
  }

  /// Removes the tag globally; strips its id from every task that referenced
  /// it so we never leave dangling tagIds behind.
  Future<void> deleteTag(String tagId) async {
    await _db.deleteTag(tagId);
    _tags = _tags.where((t) => t.id != tagId).toList();
    final affected = _tasks.where((t) => t.tagIds.contains(tagId)).toList();
    for (int idx = 0; idx < affected.length; idx++) {
      final t = affected[idx];
      final updated = t.copyWith(
        tagIds: t.tagIds.where((id) => id != tagId).toList(),
      );
      await _db.updateTask(updated);
      final taskIdx = _tasks.indexWhere((x) => x.id == t.id);
      if (taskIdx != -1) _tasks[taskIdx] = updated;
    }
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    await _db.insertTask(task);
    _tasks = [task, ..._tasks];
    _updateBadge();
    notifyListeners();
    if (task.reminderOffsets.isNotEmpty) {
      NotificationService.instance.scheduleTaskReminders(task);
    }
  }

  Future<void> updateTask(Task updated) async {
    await _db.updateTask(updated);
    final i = _tasks.indexWhere((t) => t.id == updated.id);
    if (i == -1) return;
    _tasks = [..._tasks]..[i] = updated;
    _updateBadge();
    notifyListeners();
    NotificationService.instance.scheduleTaskReminders(updated);
  }

  Future<TaskToggleResult> toggleCompleted(String id) async {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return TaskToggleResult.none;
    final original = _tasks[i];
    final completing = !original.isCompleted;

    // Recurring task being completed: don't actually mark it done — advance
    // its due date to the next occurrence and reschedule reminders, so the
    // task keeps showing up forever until the user clears the recurrence.
    if (completing && original.dueDate != null) {
      final rule = Recurrence.parse(original.recurrence);
      if (rule != null) {
        final nextDate = rule.nextAfter(original.dueDate!);
        final advanced = original.copyWith(dueDate: nextDate);
        await _db.updateTask(advanced);
        _tasks = [..._tasks]..[i] = advanced;
        _updateBadge();
        notifyListeners();
        NotificationService.instance.scheduleTaskReminders(advanced);
        return TaskToggleResult.recurrenceAdvanced;
      }
    }

    final updated = original.copyWith(
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
    if (updated.isCompleted) {
      NotificationService.instance.cancelTaskReminders(id);
    } else {
      NotificationService.instance.scheduleTaskReminders(updated);
    }
    return completing
        ? TaskToggleResult.completed
        : TaskToggleResult.uncompleted;
  }

  Future<void> deleteTask(String id) async {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    final now = DateTime.now();

    // Soft-delete the task and its entire subtask subtree at the same instant,
    // so a parent + its children share one deletedDate and surface together in
    // Trash. Restoring the parent leaves children trashed (handled in restore).
    final toTrash = <Task>[
      _tasks[i].copyWith(isDeleted: true, deletedDate: now),
      ..._tasks
          .where((t) => t.parentTaskId == id)
          .map((t) => t.copyWith(isDeleted: true, deletedDate: now)),
    ];

    await _db.softDeleteTask(id, now);
    for (final sub in toTrash.skip(1)) {
      await _db.softDeleteTask(sub.id, now);
      NotificationService.instance.cancelTaskReminders(sub.id);
    }

    final removedIds = toTrash.map((t) => t.id).toSet();
    _tasks = _tasks.where((t) => !removedIds.contains(t.id)).toList();
    _trashedTasks = [...toTrash, ..._trashedTasks];
    _updateBadge();
    notifyListeners();
    NotificationService.instance.cancelTaskReminders(id);
  }

  Future<void> deleteTasksForList(String listId, [DateTime? deletedDate]) async {
    final now = deletedDate ?? DateTime.now();
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

  /// Restores every task soft-deleted at exactly [deletedDate]. Used by Revert
  /// for bulk deletions (folder/list trash) that share one timestamp.
  Future<void> restoreAt(DateTime deletedDate) async {
    final ts = deletedDate.millisecondsSinceEpoch;
    final toRestore = _trashedTasks
        .where((t) => t.deletedDate?.millisecondsSinceEpoch == ts)
        .toList();
    if (toRestore.isEmpty) return;
    for (final t in toRestore) {
      await _db.restoreTask(t.id);
    }
    final restoredIds = toRestore.map((t) => t.id).toSet();
    _trashedTasks = _trashedTasks
        .where((t) => !restoredIds.contains(t.id))
        .toList();
    _tasks = [
      ...toRestore.map((t) =>
          t.copyWith(isDeleted: false, clearDeletedDate: true)),
      ..._tasks,
    ];
    _updateBadge();
    notifyListeners();
    for (final t in toRestore) {
      if (!t.isCompleted) {
        NotificationService.instance.scheduleTaskReminders(t);
      }
    }
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

  /// Updates a task's section assignment, persisting both the in-memory copy
  /// and the row. Used when the user drags a task between section headers.
  Future<void> moveTaskToSection(String taskId, String? sectionId) async {
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i == -1) return;
    final updated = _tasks[i].copyWith(
      sectionId: sectionId,
      clearSectionId: sectionId == null,
    );
    await _db.updateTask(updated);
    _tasks = [..._tasks]..[i] = updated;
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

  /// Moves the task with [movedTaskId] to come right before [beforeTaskId],
  /// both within the same list+section. If [beforeTaskId] is null the moved
  /// task lands at the end of the section. Renumbers sortOrder across the
  /// whole section so the new arrangement persists.
  Future<void> reorderTaskBefore({
    required String movedTaskId,
    String? beforeTaskId,
    required String? listId,
    required String? sectionId,
  }) async {
    final moved = _tasks.firstWhere((t) => t.id == movedTaskId,
        orElse: () => Task(title: ''));
    if (moved.id.isEmpty) return;

    // Build the in-section task list in current display order. Excludes the
    // moved task itself so we can insert it cleanly at the new position.
    final scope = _tasks
        .where((t) =>
            t.listId == listId &&
            t.sectionId == sectionId &&
            !t.isCompleted &&
            t.parentTaskId == null &&
            t.id != movedTaskId)
        .toList();
    _sortByDefault(scope);

    int insertAt;
    if (beforeTaskId == null) {
      insertAt = scope.length;
    } else {
      insertAt = scope.indexWhere((t) => t.id == beforeTaskId);
      if (insertAt == -1) insertAt = scope.length;
    }

    // The moved task may have been in a different section; if so, update
    // its sectionId at the same time. Use copyWith with clearSectionId so
    // null-section assignments persist.
    final movedUpdated = moved.copyWith(
      sectionId: sectionId,
      clearSectionId: sectionId == null,
      listId: listId,
      clearListId: listId == null,
    );
    scope.insert(insertAt, movedUpdated);

    for (int i = 0; i < scope.length; i++) {
      scope[i] = scope[i].copyWith(sortOrder: i + 1);
    }
    // Persist movedUpdated separately (it may have a new sectionId).
    final movedInList = scope.firstWhere((t) => t.id == movedTaskId);
    await _db.updateTask(movedInList);
    await _db.updateTaskSortOrders(scope);

    for (final t in scope) {
      final idx = _tasks.indexWhere((x) => x.id == t.id);
      if (idx != -1) _tasks[idx] = t;
    }
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

  /// Counts the uncompleted top-level tasks matching the selected badge
  /// [sources] (smart lists, lists, folders). Task ids are de-duplicated so
  /// overlapping sources (e.g. Today + a list a today-task lives in) only
  /// count once.
  int _customBadgeCount(List<String> sources) {
    if (sources.isEmpty) return 0;
    final ids = <String>{};
    for (final source in sources) {
      if (source.startsWith(BadgeSource.smartPrefix)) {
        final key = source.substring(BadgeSource.smartPrefix.length);
        for (final t in _smartListTasks(key)) {
          ids.add(t.id);
        }
      } else if (source.startsWith(BadgeSource.listPrefix)) {
        final listId = source.substring(BadgeSource.listPrefix.length);
        for (final t in _topLevel.where(
            (t) => !t.isCompleted && t.listId == listId)) {
          ids.add(t.id);
        }
      } else if (source.startsWith(BadgeSource.folderPrefix)) {
        final folderId = source.substring(BadgeSource.folderPrefix.length);
        final listIds = (_listIdsInFolder?.call(folderId) ?? const []).toSet();
        if (listIds.isEmpty) continue;
        for (final t in _topLevel.where((t) =>
            !t.isCompleted && t.listId != null && listIds.contains(t.listId))) {
          ids.add(t.id);
        }
      }
    }
    return ids.length;
  }

  Iterable<Task> _smartListTasks(String key) {
    switch (key) {
      case 'inbox':
        return _topLevel.where((t) => t.listId == null && !t.isCompleted);
      case 'today':
        return todayTasks.where((t) => !t.isCompleted);
      case 'tomorrow':
        return tomorrowTasks.where((t) => !t.isCompleted);
      case 'upcoming':
        return upcomingTasks.where((t) => !t.isCompleted);
      case 'allTasks':
        return _topLevel.where((t) => !t.isCompleted);
      default:
        return const [];
    }
  }

  void _updateBadge() {
    if (!PlatformCapabilities.supportsAppBadge) return;
    final mode = _settings?.badgeMode ?? BadgeMode.todayTasks;
    int count;
    switch (mode) {
      case BadgeMode.none:
        count = 0;
      case BadgeMode.todayTasks:
        count = todayUncompletedCount;
      case BadgeMode.todayTasksAndEvents:
        count = todayUncompletedCount + (_eventCountToday?.call() ?? 0);
      case BadgeMode.inboxTasks:
        count = inboxUncompletedCount;
      case BadgeMode.allUncompleted:
        count = _topLevel.where((t) => !t.isCompleted).length;
      case BadgeMode.custom:
        count = _customBadgeCount(_settings?.badgeCustomSources ?? const []);
    }
    // Optionally fold in today's uncompleted routines (not when the badge is
    // off entirely).
    if (mode != BadgeMode.none &&
        (_settings?.badgeIncludeRoutines ?? false)) {
      count += _routineCountToday?.call() ?? 0;
    }
    try {
      if (count > 0) {
        FlutterAppBadger.updateBadgeCount(count);
      } else {
        FlutterAppBadger.removeBadge();
      }
    } catch (e, st) {
      // Discontinued plugin — swallow rather than crash the controller if the
      // host OS rejects the channel call (e.g. user hasn't granted badges).
      debugPrint('badge update failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    if (_settings != null && _settingsListener != null) {
      _settings!.removeListener(_settingsListener!);
    }
    super.dispose();
  }
}
