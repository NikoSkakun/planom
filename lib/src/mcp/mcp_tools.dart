/// Tool definitions exposed by the Planom MCP server.
///
/// Each entry has a JSON Schema describing the arguments the model is
/// allowed to pass. The dispatcher in `mcp_dispatcher.dart` looks tools up
/// by [McpTool.name] and routes to the appropriate handler.
library;

import 'mcp_types.dart';

const kPlanomMcpTools = <McpTool>[
  // ── Tasks ─────────────────────────────────────────────────────────────────
  McpTool(
    name: 'list_tasks',
    description:
        'List tasks. Scope filters: inbox, today, tomorrow, upcoming, '
        'completed, trash, or a specific list by id.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'scope': {
          'type': 'string',
          'enum': [
            'inbox',
            'today',
            'tomorrow',
            'upcoming',
            'completed',
            'trash',
            'list',
            'all',
          ],
          'description': 'Which set of tasks to return. Default: all.',
        },
        'listId': {
          'type': 'string',
          'description': 'List id, required when scope = "list".',
        },
      },
    },
  ),
  McpTool(
    name: 'create_task',
    description: 'Create a new task. Returns the created task id.',
    inputSchema: {
      'type': 'object',
      'required': ['title'],
      'properties': {
        'title': {'type': 'string'},
        'note': {'type': 'string'},
        'listId': {
          'type': 'string',
          'description': 'Place the task in this list (omit for Inbox).',
        },
        'dueDate': {
          'type': 'string',
          'description': 'ISO-8601 date or datetime.',
        },
        'doTime': {
          'type': 'integer',
          'description': 'Minutes since midnight (0-1439).',
        },
        'duration': {
          'type': 'integer',
          'description': 'Duration in minutes.',
        },
        'priority': {
          'type': 'integer',
          'enum': [0, 1, 2, 3],
          'description': '0=none, 1=low, 2=medium, 3=high',
        },
        'tagIds': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
    },
  ),
  McpTool(
    name: 'update_task',
    description: 'Patch an existing task. Only fields you pass are changed.',
    inputSchema: {
      'type': 'object',
      'required': ['id'],
      'properties': {
        'id': {'type': 'string'},
        'title': {'type': 'string'},
        'note': {'type': 'string'},
        'isCompleted': {'type': 'boolean'},
        'listId': {'type': 'string'},
        'dueDate': {'type': 'string'},
        'doTime': {'type': 'integer'},
        'duration': {'type': 'integer'},
        'priority': {'type': 'integer'},
      },
    },
  ),
  McpTool(
    name: 'complete_task',
    description: 'Toggle a task between completed and incomplete.',
    inputSchema: {
      'type': 'object',
      'required': ['id'],
      'properties': {
        'id': {'type': 'string'},
      },
    },
  ),
  McpTool(
    name: 'delete_task',
    description:
        'Move a task to Trash (soft-delete). Use restore_task to undo.',
    inputSchema: {
      'type': 'object',
      'required': ['id'],
      'properties': {
        'id': {'type': 'string'},
      },
    },
  ),
  McpTool(
    name: 'restore_task',
    description: 'Restore a task from Trash to its original list (or Inbox).',
    inputSchema: {
      'type': 'object',
      'required': ['id'],
      'properties': {
        'id': {'type': 'string'},
      },
    },
  ),

  // ── Lists & Folders ────────────────────────────────────────────────────────
  McpTool(
    name: 'list_lists',
    description: 'List all task lists. Optional folderId filters by parent.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'folderId': {'type': 'string'},
      },
    },
  ),
  McpTool(
    name: 'list_folders',
    description: 'List task folders. Optional parentId filters by parent.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'parentId': {'type': 'string'},
      },
    },
  ),
  McpTool(
    name: 'create_list',
    description: 'Create a new task list. Returns the list id.',
    inputSchema: {
      'type': 'object',
      'required': ['name'],
      'properties': {
        'name': {'type': 'string'},
        'folderId': {'type': 'string'},
        'color': {
          'type': 'integer',
          'description': 'ARGB color value.',
        },
      },
    },
  ),
  McpTool(
    name: 'create_folder',
    description: 'Create a new task folder. Returns the folder id.',
    inputSchema: {
      'type': 'object',
      'required': ['name'],
      'properties': {
        'name': {'type': 'string'},
        'parentId': {'type': 'string'},
      },
    },
  ),

  // ── Notes ──────────────────────────────────────────────────────────────────
  McpTool(
    name: 'list_notes',
    description: 'List notes. Optional folderId filters by parent.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'folderId': {'type': 'string'},
      },
    },
  ),
  McpTool(
    name: 'create_note',
    description: 'Create a new note. Returns the note id.',
    inputSchema: {
      'type': 'object',
      'required': ['title'],
      'properties': {
        'title': {'type': 'string'},
        'content': {
          'type': 'string',
          'description': 'Markdown body of the note.',
        },
        'folderId': {'type': 'string'},
      },
    },
  ),
  McpTool(
    name: 'update_note',
    description: 'Patch an existing note. Only fields you pass are changed.',
    inputSchema: {
      'type': 'object',
      'required': ['id'],
      'properties': {
        'id': {'type': 'string'},
        'title': {'type': 'string'},
        'content': {'type': 'string'},
        'folderId': {'type': 'string'},
      },
    },
  ),
  McpTool(
    name: 'delete_note',
    description: 'Move a note to Trash (soft-delete).',
    inputSchema: {
      'type': 'object',
      'required': ['id'],
      'properties': {
        'id': {'type': 'string'},
      },
    },
  ),

  // ── Routines ───────────────────────────────────────────────────────────────
  McpTool(
    name: 'list_routines',
    description: 'List all routines with today\'s progress.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'todayOnly': {
          'type': 'boolean',
          'description': 'If true, only routines scheduled for today.',
        },
      },
    },
  ),
  McpTool(
    name: 'record_routine_progress',
    description:
        'Record progress for a routine today. For achieve_all routines '
        'this toggles done/undone; for certain_amount it adds recordAmount.',
    inputSchema: {
      'type': 'object',
      'required': ['routineId'],
      'properties': {
        'routineId': {'type': 'string'},
      },
    },
  ),

  // ── Calendar events ────────────────────────────────────────────────────────
  McpTool(
    name: 'list_events',
    description:
        'List calendar events. Pass startDate and endDate (ISO-8601) to scope.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'startDate': {'type': 'string'},
        'endDate': {'type': 'string'},
      },
    },
  ),

  // ── Spaces ─────────────────────────────────────────────────────────────────
  McpTool(
    name: 'list_spaces',
    description:
        'List all data spaces and indicate which one is currently active.',
    inputSchema: {
      'type': 'object',
      'properties': {},
    },
  ),
  McpTool(
    name: 'switch_space',
    description: 'Switch the active space to the one with the given id.',
    inputSchema: {
      'type': 'object',
      'required': ['id'],
      'properties': {
        'id': {'type': 'string'},
      },
    },
  ),

  // ── Search ─────────────────────────────────────────────────────────────────
  McpTool(
    name: 'search',
    description:
        'Full-text search across tasks, notes, and events in the active space.',
    inputSchema: {
      'type': 'object',
      'required': ['query'],
      'properties': {
        'query': {'type': 'string'},
        'limit': {
          'type': 'integer',
          'description': 'Max results per category (default 20).',
        },
      },
    },
  ),
];
