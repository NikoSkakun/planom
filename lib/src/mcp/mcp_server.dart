/// Wires Planom's controllers into the MCP dispatcher.
///
/// This is a scaffolding layer in preparation for an AI integration. It does
/// NOT open any transport (stdio, websocket, http) — instead it exposes a
/// [PlanomMcpServer.handle] method that takes a parsed [McpRequest] and
/// returns an [McpResponse]. Wire it into whatever surface makes sense (a
/// debug console, an in-app chat, a stdio server in a desktop build, etc.).
///
/// Each tool handler is a pure function over the active space's controllers,
/// so calling them from a test or from generated mock data is straightforward.
library;

import 'dart:convert';

import '../models/app_folder.dart';
import '../models/app_list.dart';
import '../models/note.dart';
import '../models/task.dart';
import '../spaces/space_manager.dart';
import 'mcp_dispatcher.dart';
import 'mcp_tools.dart';
import 'mcp_types.dart';

const String kPlanomMcpServerName = 'planom';
const String kPlanomMcpServerVersion = '0.1.0';

/// Top-level facade. Holds a [SpaceManager] and routes MCP requests to the
/// controllers of the currently-active space.
class PlanomMcpServer {
  PlanomMcpServer(this.spaceManager) {
    _dispatcher = McpDispatcher(
      serverInfo: const McpServerInfo(
        name: kPlanomMcpServerName,
        version: kPlanomMcpServerVersion,
      ),
      handlers: _buildHandlers(),
      tools: kPlanomMcpTools,
    );
  }

  final SpaceManager spaceManager;
  late final McpDispatcher _dispatcher;

  Future<McpResponse> handle(McpRequest req) => _dispatcher.handle(req);

  /// Convenience wrapper: takes a JSON string in, returns a JSON string out.
  /// Useful for transport layers (stdio, websocket) that pass raw frames.
  Future<String> handleJson(String body) async {
    final req = McpRequest.fromJson(
        jsonDecode(body) as Map<String, dynamic>);
    final res = await handle(req);
    return jsonEncode(res.toJson());
  }

  Map<String, McpToolHandler> _buildHandlers() => {
        // Tasks
        'list_tasks': _listTasks,
        'create_task': _createTask,
        'update_task': _updateTask,
        'complete_task': _completeTask,
        'delete_task': _deleteTask,
        'restore_task': _restoreTask,
        // Lists & folders
        'list_lists': _listLists,
        'list_folders': _listFolders,
        'create_list': _createList,
        'create_folder': _createFolder,
        // Notes
        'list_notes': _listNotes,
        'create_note': _createNote,
        'update_note': _updateNote,
        'delete_note': _deleteNote,
        // Routines
        'list_routines': _listRoutines,
        'record_routine_progress': _recordRoutineProgress,
        // Events
        'list_events': _listEvents,
        // Spaces
        'list_spaces': _listSpaces,
        'switch_space': _switchSpace,
        // Search
        'search': _search,
      };

  // ── Tasks ──────────────────────────────────────────────────────────────────

  Future<String> _listTasks(Map<String, dynamic> args) async {
    final c = spaceManager.taskController;
    final scope = (args['scope'] as String?) ?? 'all';
    final List<Task> tasks;
    switch (scope) {
      case 'inbox':
        tasks = c.inboxTasks;
      case 'today':
        tasks = c.todayTasks;
      case 'tomorrow':
        tasks = c.tomorrowTasks;
      case 'upcoming':
        tasks = c.upcomingTasks;
      case 'completed':
        tasks = c.allCompletedTasks;
      case 'trash':
        tasks = c.trashedTasks;
      case 'list':
        final listId = args['listId'] as String?;
        if (listId == null) {
          throw McpException('listId is required when scope = "list"');
        }
        tasks = c.tasksForList(listId);
      case 'all':
      default:
        tasks = [
          ...c.inboxTasks,
          for (final l in spaceManager.folderController.listsIn(null))
            ...c.tasksForList(l.id),
        ];
    }
    return jsonEncode(tasks.map(_taskToJson).toList());
  }

  Future<String> _createTask(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    if (title == null || title.trim().isEmpty) {
      throw McpException('title is required');
    }
    final task = Task(
      title: title,
      note: args['note'] as String?,
      listId: args['listId'] as String?,
      dueDate: _parseDate(args['dueDate']),
      doTime: args['doTime'] as int?,
      duration: args['duration'] as int?,
      priority: (args['priority'] as int?) ?? 0,
      tagIds: (args['tagIds'] as List?)?.cast<String>() ?? const [],
    );
    await spaceManager.taskController.addTask(task);
    return jsonEncode({'id': task.id});
  }

  Future<String> _updateTask(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) throw McpException('id is required');
    final current = spaceManager.taskController.taskById(id);
    if (current == null) throw McpException('Task not found: $id');
    final updated = current.copyWith(
      title: args['title'] as String?,
      note: args['note'] as String?,
      isCompleted: args['isCompleted'] as bool?,
      listId: args['listId'] as String?,
      clearListId: args.containsKey('listId') && args['listId'] == null,
      dueDate: _parseDate(args['dueDate']),
      clearDueDate: args.containsKey('dueDate') && args['dueDate'] == null,
      doTime: args['doTime'] as int?,
      clearDoTime: args.containsKey('doTime') && args['doTime'] == null,
      duration: args['duration'] as int?,
      clearDuration: args.containsKey('duration') && args['duration'] == null,
      priority: args['priority'] as int?,
    );
    await spaceManager.taskController.updateTask(updated);
    return jsonEncode(_taskToJson(updated));
  }

  Future<String> _completeTask(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) throw McpException('id is required');
    await spaceManager.taskController.toggleCompleted(id);
    final updated = spaceManager.taskController.taskById(id);
    return jsonEncode({
      'id': id,
      'isCompleted': updated?.isCompleted ?? false,
    });
  }

  Future<String> _deleteTask(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) throw McpException('id is required');
    await spaceManager.taskController.deleteTask(id);
    return jsonEncode({'id': id, 'status': 'trashed'});
  }

  Future<String> _restoreTask(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) throw McpException('id is required');
    final trashed = spaceManager.taskController.trashedTasks
        .where((t) => t.id == id)
        .firstOrNull;
    if (trashed == null) throw McpException('Trashed task not found: $id');
    await spaceManager.taskController.restoreTask(id, trashed.listId);
    return jsonEncode({'id': id, 'status': 'restored'});
  }

  // ── Lists & folders ────────────────────────────────────────────────────────

  Future<String> _listLists(Map<String, dynamic> args) async {
    final folderId = args['folderId'] as String?;
    final lists = spaceManager.folderController.listsIn(folderId);
    return jsonEncode(lists.map(_listToJson).toList());
  }

  Future<String> _listFolders(Map<String, dynamic> args) async {
    final parentId = args['parentId'] as String?;
    final folders = spaceManager.folderController.foldersIn(parentId);
    return jsonEncode(folders.map(_folderToJson).toList());
  }

  Future<String> _createList(Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw McpException('name is required');
    }
    final list = AppList(
      name: name,
      folderId: args['folderId'] as String?,
      color: args['color'] as int?,
    );
    await spaceManager.folderController.addList(list);
    return jsonEncode({'id': list.id});
  }

  Future<String> _createFolder(Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw McpException('name is required');
    }
    final folder = AppFolder(
      name: name,
      parentFolderId: args['parentId'] as String?,
    );
    await spaceManager.folderController.addFolder(folder);
    return jsonEncode({'id': folder.id});
  }

  // ── Notes ──────────────────────────────────────────────────────────────────

  Future<String> _listNotes(Map<String, dynamic> args) async {
    final folderId = args['folderId'] as String?;
    final notes = args.containsKey('folderId')
        ? spaceManager.noteController.notesIn(folderId)
        : spaceManager.noteController.allNotes;
    return jsonEncode(notes.map(_noteToJson).toList());
  }

  Future<String> _createNote(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    if (title == null || title.trim().isEmpty) {
      throw McpException('title is required');
    }
    final note = Note(
      title: title,
      content: (args['content'] as String?) ?? '',
      folderId: args['folderId'] as String?,
    );
    await spaceManager.noteController.addNote(note);
    return jsonEncode({'id': note.id});
  }

  Future<String> _updateNote(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) throw McpException('id is required');
    final current = spaceManager.noteController.noteById(id);
    if (current == null) throw McpException('Note not found: $id');
    final updated = current.copyWith(
      title: args['title'] as String?,
      content: args['content'] as String?,
      folderId: args['folderId'] as String?,
      clearFolderId:
          args.containsKey('folderId') && args['folderId'] == null,
    );
    await spaceManager.noteController.updateNote(updated);
    return jsonEncode(_noteToJson(updated));
  }

  Future<String> _deleteNote(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) throw McpException('id is required');
    await spaceManager.noteController.deleteNote(id);
    return jsonEncode({'id': id, 'status': 'trashed'});
  }

  // ── Routines ───────────────────────────────────────────────────────────────

  Future<String> _listRoutines(Map<String, dynamic> args) async {
    final todayOnly = args['todayOnly'] as bool? ?? false;
    final c = spaceManager.routineController;
    final list = todayOnly ? c.todayRoutines : c.routines;
    return jsonEncode(list
        .map((r) => {
              'id': r.id,
              'name': r.name,
              'goalType': r.goalType,
              'goalAmount': r.goalAmount,
              'goalUnit': r.goalUnit,
              'todayProgress': c.todayProgress(r.id),
              'isTodayCompleted': c.isTodayCompleted(r),
            })
        .toList());
  }

  Future<String> _recordRoutineProgress(Map<String, dynamic> args) async {
    final id = args['routineId'] as String?;
    if (id == null) throw McpException('routineId is required');
    final routine = spaceManager.routineController.routines
        .where((r) => r.id == id)
        .firstOrNull;
    if (routine == null) throw McpException('Routine not found: $id');
    await spaceManager.routineController.recordProgress(routine);
    return jsonEncode({
      'id': id,
      'progress': spaceManager.routineController.todayProgress(id),
    });
  }

  // ── Events ─────────────────────────────────────────────────────────────────

  Future<String> _listEvents(Map<String, dynamic> args) async {
    final start = _parseDate(args['startDate']);
    final end = _parseDate(args['endDate']);
    final events = spaceManager.eventController.events.where((e) {
      if (start != null && e.date.isBefore(start)) return false;
      if (end != null && e.date.isAfter(end)) return false;
      return true;
    });
    return jsonEncode(events
        .map((e) => {
              'id': e.id,
              'title': e.title,
              'note': e.note,
              'date': e.date.toIso8601String(),
              'doTime': e.doTime,
              'duration': e.duration,
            })
        .toList());
  }

  // ── Spaces ─────────────────────────────────────────────────────────────────

  Future<String> _listSpaces(Map<String, dynamic> args) async {
    final active = spaceManager.activeSpaceId;
    return jsonEncode(spaceManager.spaces
        .map((s) => {
              'id': s.id,
              'name': s.name,
              'creationDate': s.creationDate.toIso8601String(),
              'isActive': s.id == active,
            })
        .toList());
  }

  Future<String> _switchSpace(Map<String, dynamic> args) async {
    final id = args['id'] as String?;
    if (id == null) throw McpException('id is required');
    await spaceManager.switchSpace(id);
    return jsonEncode({'id': id, 'status': 'active'});
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<String> _search(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim();
    if (query == null || query.isEmpty) {
      throw McpException('query is required');
    }
    final limit = (args['limit'] as int?) ?? 20;
    final q = query.toLowerCase();

    bool matches(String haystack) => haystack.toLowerCase().contains(q);

    final allTasks = <Task>[
      ...spaceManager.taskController.inboxTasks,
      for (final l in spaceManager.folderController.listsIn(null))
        ...spaceManager.taskController.tasksForList(l.id),
    ];
    final tasks = allTasks
        .where((t) =>
            matches(t.title) || (t.note != null && matches(t.note!)))
        .take(limit)
        .map(_taskToJson)
        .toList();

    final notes = spaceManager.noteController.allNotes
        .where((n) => matches(n.title) || matches(n.content))
        .take(limit)
        .map(_noteToJson)
        .toList();

    final events = spaceManager.eventController.events
        .where((e) =>
            matches(e.title) || (e.note != null && matches(e.note!)))
        .take(limit)
        .map((e) => {
              'id': e.id,
              'title': e.title,
              'date': e.date.toIso8601String(),
            })
        .toList();

    return jsonEncode({
      'tasks': tasks,
      'notes': notes,
      'events': events,
    });
  }

  // ── Serializers ────────────────────────────────────────────────────────────

  Map<String, dynamic> _taskToJson(Task t) => {
        'id': t.id,
        'title': t.title,
        'note': t.note,
        'isCompleted': t.isCompleted,
        'dueDate': t.dueDate?.toIso8601String(),
        'doTime': t.doTime,
        'duration': t.duration,
        'listId': t.listId,
        'priority': t.priority,
        'tagIds': t.tagIds,
        'parentTaskId': t.parentTaskId,
        'recurrence': t.recurrence,
      };

  Map<String, dynamic> _listToJson(AppList l) => {
        'id': l.id,
        'name': l.name,
        'folderId': l.folderId,
        'color': l.color,
        'iconId': l.iconId,
      };

  Map<String, dynamic> _folderToJson(AppFolder f) => {
        'id': f.id,
        'name': f.name,
        'parentFolderId': f.parentFolderId,
        'iconId': f.iconId,
      };

  Map<String, dynamic> _noteToJson(Note n) => {
        'id': n.id,
        'title': n.title,
        'content': n.content,
        'folderId': n.folderId,
        'creationDate': n.creationDate.toIso8601String(),
        'modifiedDate': n.modifiedDate.toIso8601String(),
      };

  DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }
}

class McpException implements Exception {
  McpException(this.message);
  final String message;

  @override
  String toString() => message;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
