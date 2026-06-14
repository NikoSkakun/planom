import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/platform_capabilities.dart';
import '../models/app_folder.dart';
import '../models/app_list.dart';
import '../models/contact.dart';
import '../models/event.dart';
import '../models/list_section.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/routine.dart';
import '../models/routine_entry.dart';
import '../models/task.dart';

class DatabaseService {
  DatabaseService({this.dbName = 'planom.db'});

  final String dbName;
  static const _dbVersion = 35;

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  /// Directory the DB file lives in. On Android we use the FFI factory (for the
  /// bundled SQLite with FTS5), but its `getDatabasesPath()` doesn't resolve to a
  /// writable app directory there ("unable to open database file"), so fall back
  /// to the app support dir. Native sqflite (iOS/macOS) and the desktop FFI
  /// default already return valid paths.
  Future<String> _databasesDir() async {
    if (PlatformCapabilities.isAndroid) {
      return (await getApplicationSupportDirectory()).path;
    }
    return getDatabasesPath();
  }

  Future<Database> _open() async {
    final dbPath = await _databasesDir();
    return openDatabase(
      join(dbPath, dbName),
      version: _dbVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            creationDate INTEGER NOT NULL,
            iconId TEXT NOT NULL,
            title TEXT NOT NULL,
            note TEXT,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            dueDate INTEGER,
            doTime INTEGER,
            duration INTEGER,
            listId TEXT,
            priority INTEGER NOT NULL DEFAULT 0,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedDate INTEGER,
            completionDate INTEGER,
            reminderOffsets TEXT,
            parentTaskId TEXT,
            tagIds TEXT,
            recurrence TEXT,
            sectionId TEXT,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            note TEXT,
            listId TEXT NOT NULL,
            birthMonth INTEGER NOT NULL,
            birthDay INTEGER NOT NULL,
            birthYear INTEGER,
            isCompletable INTEGER NOT NULL DEFAULT 0,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            completionDate INTEGER,
            reminderOffsets TEXT,
            creationDate INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedDate INTEGER,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color INTEGER,
            creationDate INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentFolderId TEXT,
            creationDate INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            iconId TEXT,
            iconColor INTEGER,
            description TEXT,
            defaultListId TEXT,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedDate INTEGER,
            viewMode TEXT,
            kanbanScrollMode TEXT,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE app_lists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            folderId TEXT,
            creationDate INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            color INTEGER,
            iconId TEXT,
            iconColor INTEGER,
            description TEXT,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedDate INTEGER,
            listType TEXT NOT NULL DEFAULT 'tasks',
            viewMode TEXT,
            kanbanScrollMode TEXT,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE note_folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentFolderId TEXT,
            creationDate INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            iconId TEXT,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedDate INTEGER,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            folderId TEXT,
            creationDate INTEGER NOT NULL,
            modifiedDate INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedDate INTEGER,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE routines (
            id TEXT PRIMARY KEY,
            creationDate INTEGER NOT NULL,
            iconId TEXT NOT NULL,
            iconColor INTEGER NOT NULL,
            name TEXT NOT NULL,
            goalType TEXT NOT NULL,
            goalAmount INTEGER,
            goalUnit TEXT,
            recordAmount INTEGER,
            frequencyType TEXT NOT NULL DEFAULT 'daily',
            weekdays TEXT,
            startDate INTEGER,
            intervalDays INTEGER,
            waitForCompletion INTEGER NOT NULL DEFAULT 0,
            reminders TEXT,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            manualEntry INTEGER NOT NULL DEFAULT 0,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE routine_entries (
            id TEXT PRIMARY KEY,
            routineId TEXT NOT NULL,
            date INTEGER NOT NULL,
            amount INTEGER NOT NULL DEFAULT 0,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE events (
            id TEXT PRIMARY KEY,
            creationDate INTEGER NOT NULL,
            iconId TEXT NOT NULL,
            title TEXT NOT NULL,
            note TEXT,
            date INTEGER NOT NULL,
            doTime INTEGER,
            duration INTEGER,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedDate INTEGER,
            reminderOffsets TEXT,
            recurrence TEXT,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE list_sections (
            id TEXT PRIMARY KEY,
            listId TEXT NOT NULL,
            name TEXT NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            isCollapsed INTEGER NOT NULL DEFAULT 0,
            creationDate INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE tombstones (
            tbl TEXT NOT NULL,
            id TEXT NOT NULL,
            deletedAt INTEGER NOT NULL,
            PRIMARY KEY (tbl, id)
          )
        ''');
        await _createFtsTables(db);
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN dueDate INTEGER');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE tasks ADD COLUMN listId TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE tasks ADD COLUMN doTime INTEGER');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS folders (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              parentFolderId TEXT,
              creationDate INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_lists (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              folderId TEXT,
              creationDate INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS note_folders (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              parentFolderId TEXT,
              creationDate INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS notes (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              folderId TEXT,
              creationDate INTEGER NOT NULL,
              modifiedDate INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS routines (
              id TEXT PRIMARY KEY,
              creationDate INTEGER NOT NULL,
              iconId TEXT NOT NULL,
              iconColor INTEGER NOT NULL,
              name TEXT NOT NULL,
              goalType TEXT NOT NULL,
              goalAmount INTEGER,
              goalUnit TEXT,
              recordAmount INTEGER,
              frequencyType TEXT NOT NULL,
              weekdays TEXT,
              daysAfterComplete INTEGER,
              autoReset TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS routine_entries (
              id TEXT PRIMARY KEY,
              routineId TEXT NOT NULL,
              date INTEGER NOT NULL,
              amount INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 7) {
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN priority INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE folders ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE app_lists ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE note_folders ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE notes ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 8) {
          await db.execute(
              'ALTER TABLE app_lists ADD COLUMN color INTEGER');
        }
        if (oldVersion < 9) {
          await db.execute(
              'ALTER TABLE folders ADD COLUMN iconId TEXT');
          await db.execute(
              'ALTER TABLE app_lists ADD COLUMN iconId TEXT');
        }
        if (oldVersion < 10) {
          await db.execute(
              'ALTER TABLE note_folders ADD COLUMN iconId TEXT');
        }
        if (oldVersion < 11) {
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN deletedDate INTEGER');
          await db.execute(
              'ALTER TABLE folders ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE folders ADD COLUMN deletedDate INTEGER');
          await db.execute(
              'ALTER TABLE app_lists ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE app_lists ADD COLUMN deletedDate INTEGER');
        }
        if (oldVersion < 12) {
          await db.execute(
              'ALTER TABLE note_folders ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE note_folders ADD COLUMN deletedDate INTEGER');
          await db.execute(
              'ALTER TABLE notes ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE notes ADD COLUMN deletedDate INTEGER');
        }
        if (oldVersion < 13) {
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN completionDate INTEGER');
        }
        if (oldVersion < 14) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 15) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS events (
              id TEXT PRIMARY KEY,
              creationDate INTEGER NOT NULL,
              iconId TEXT NOT NULL,
              title TEXT NOT NULL,
              note TEXT,
              date INTEGER NOT NULL,
              doTime INTEGER,
              duration INTEGER,
              isDeleted INTEGER NOT NULL DEFAULT 0,
              deletedDate INTEGER
            )
          ''');
        }
        if (oldVersion < 16) {
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN duration INTEGER');
        }
        if (oldVersion < 17) {
          await db.execute('ALTER TABLE tasks ADD COLUMN reminderOffsets TEXT');
          await db.execute('ALTER TABLE events ADD COLUMN reminderOffsets TEXT');
        }
        if (oldVersion < 18) {
          await db.execute('ALTER TABLE tasks ADD COLUMN parentTaskId TEXT');
        }
        if (oldVersion < 19) {
          await db.execute('ALTER TABLE tasks ADD COLUMN tagIds TEXT');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tags (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color INTEGER,
              creationDate INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 20) {
          await db.execute('ALTER TABLE tasks ADD COLUMN recurrence TEXT');
        }
        if (oldVersion < 21) {
          await _createFtsTables(db);
          await _backfillFts(db);
        }
        if (oldVersion < 22) {
          await db.execute('ALTER TABLE folders ADD COLUMN iconColor INTEGER');
          await db.execute('ALTER TABLE app_lists ADD COLUMN iconColor INTEGER');
        }
        if (oldVersion < 23) {
          await db.execute(
              "ALTER TABLE app_lists ADD COLUMN listType TEXT NOT NULL DEFAULT 'tasks'");
        }
        if (oldVersion < 24) {
          await db.execute('ALTER TABLE tasks ADD COLUMN birthMonth INTEGER');
          await db.execute('ALTER TABLE tasks ADD COLUMN birthDay INTEGER');
          await db.execute('ALTER TABLE tasks ADD COLUMN birthYear INTEGER');
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN isCompletable INTEGER NOT NULL DEFAULT 1');
          await db.execute('ALTER TABLE tasks ADD COLUMN sectionId TEXT');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS list_sections (
              id TEXT PRIMARY KEY,
              listId TEXT NOT NULL,
              name TEXT NOT NULL,
              sortOrder INTEGER NOT NULL DEFAULT 0,
              isCollapsed INTEGER NOT NULL DEFAULT 0,
              creationDate INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 25) {
          // Move birthday tasks to the new contacts table, then drop the
          // birthday columns from tasks. SQLite can't drop columns directly
          // pre-3.35, so we recreate the tasks table.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS contacts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              note TEXT,
              listId TEXT NOT NULL,
              birthMonth INTEGER NOT NULL,
              birthDay INTEGER NOT NULL,
              birthYear INTEGER,
              isCompletable INTEGER NOT NULL DEFAULT 0,
              isCompleted INTEGER NOT NULL DEFAULT 0,
              completionDate INTEGER,
              reminderOffsets TEXT,
              creationDate INTEGER NOT NULL,
              sortOrder INTEGER NOT NULL DEFAULT 0,
              isDeleted INTEGER NOT NULL DEFAULT 0,
              deletedDate INTEGER
            )
          ''');
          await db.execute('''
            INSERT INTO contacts (
              id, name, note, listId,
              birthMonth, birthDay, birthYear,
              isCompletable, isCompleted, completionDate,
              reminderOffsets, creationDate, sortOrder,
              isDeleted, deletedDate
            )
            SELECT id, title, note, listId,
                   birthMonth, birthDay, birthYear,
                   isCompletable, isCompleted, completionDate,
                   reminderOffsets, creationDate, sortOrder,
                   isDeleted, deletedDate
            FROM tasks
            WHERE birthMonth IS NOT NULL AND birthDay IS NOT NULL
          ''');
          await db.execute('''
            DELETE FROM tasks
            WHERE birthMonth IS NOT NULL AND birthDay IS NOT NULL
          ''');
          // Recreate `tasks` without the birthday columns. Preserve every
          // remaining row by copying through a temp table.
          await db.execute('''
            CREATE TABLE tasks_new (
              id TEXT PRIMARY KEY,
              creationDate INTEGER NOT NULL,
              iconId TEXT NOT NULL,
              title TEXT NOT NULL,
              note TEXT,
              isCompleted INTEGER NOT NULL DEFAULT 0,
              dueDate INTEGER,
              doTime INTEGER,
              duration INTEGER,
              listId TEXT,
              priority INTEGER NOT NULL DEFAULT 0,
              sortOrder INTEGER NOT NULL DEFAULT 0,
              isDeleted INTEGER NOT NULL DEFAULT 0,
              deletedDate INTEGER,
              completionDate INTEGER,
              reminderOffsets TEXT,
              parentTaskId TEXT,
              tagIds TEXT,
              recurrence TEXT,
              sectionId TEXT
            )
          ''');
          await db.execute('''
            INSERT INTO tasks_new (
              id, creationDate, iconId, title, note, isCompleted,
              dueDate, doTime, duration, listId, priority, sortOrder,
              isDeleted, deletedDate, completionDate, reminderOffsets,
              parentTaskId, tagIds, recurrence, sectionId
            )
            SELECT id, creationDate, iconId, title, note, isCompleted,
                   dueDate, doTime, duration, listId, priority, sortOrder,
                   isDeleted, deletedDate, completionDate, reminderOffsets,
                   parentTaskId, tagIds, recurrence, sectionId
            FROM tasks
          ''');
          await db.execute('DROP TABLE tasks');
          await db.execute('ALTER TABLE tasks_new RENAME TO tasks');
          // FTS triggers reference the old `tasks` table by name and
          // SQLite re-points them automatically when the table is renamed;
          // but to be safe, drop and recreate them.
          await db.execute('DROP TRIGGER IF EXISTS tasks_ai');
          await db.execute('DROP TRIGGER IF EXISTS tasks_ad');
          await db.execute('DROP TRIGGER IF EXISTS tasks_au');
          await _createTaskFtsTriggers(db);
        }
        if (oldVersion < 26) {
          // Routines were reimplemented as daily-only with strict per-day
          // history. The old schedule columns (weekdays, daysAfterComplete)
          // and the auto-reset / carry-over model are no longer compatible, so
          // recreate the routine tables clean. Pre-existing routine data is
          // intentionally discarded (sanctioned by the refactor).
          await db.execute('DROP TABLE IF EXISTS routine_entries');
          await db.execute('DROP TABLE IF EXISTS routines');
          await db.execute('''
            CREATE TABLE routines (
              id TEXT PRIMARY KEY,
              creationDate INTEGER NOT NULL,
              iconId TEXT NOT NULL,
              iconColor INTEGER NOT NULL,
              name TEXT NOT NULL,
              goalType TEXT NOT NULL,
              goalAmount INTEGER,
              goalUnit TEXT,
              recordAmount INTEGER,
              frequencyType TEXT NOT NULL DEFAULT 'daily'
            )
          ''');
          await db.execute('''
            CREATE TABLE routine_entries (
              id TEXT PRIMARY KEY,
              routineId TEXT NOT NULL,
              date INTEGER NOT NULL,
              amount INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 27) {
          // Re-introduce a weekday schedule: `specific_days` routines store the
          // selected weekdays (0=Mon … 6=Sun) as a comma-joined string; daily
          // routines leave it null.
          await db.execute('ALTER TABLE routines ADD COLUMN weekdays TEXT');
        }
        if (oldVersion < 28) {
          // Routine start date, interval scheduling, and reminders.
          await db.execute('ALTER TABLE routines ADD COLUMN startDate INTEGER');
          await db
              .execute('ALTER TABLE routines ADD COLUMN intervalDays INTEGER');
          await db.execute(
              'ALTER TABLE routines ADD COLUMN waitForCompletion INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE routines ADD COLUMN reminders TEXT');
        }
        if (oldVersion < 29) {
          // Manual routine ordering. Seed sortOrder from the existing
          // creation-date order so the first reorder doesn't reshuffle.
          await db.execute(
              'ALTER TABLE routines ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0');
          final rows =
              await db.query('routines', orderBy: 'creationDate ASC');
          for (var i = 0; i < rows.length; i++) {
            await db.update('routines', {'sortOrder': i},
                where: 'id = ?', whereArgs: [rows[i]['id']]);
          }
        }
        if (oldVersion < 30) {
          // Manual amount entry for certain_amount routines.
          await db.execute(
              'ALTER TABLE routines ADD COLUMN manualEntry INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 31) {
          // Folder/list descriptions + a folder's default list (used when
          // creating a task from inside the folder via the + button).
          await db.execute('ALTER TABLE folders ADD COLUMN description TEXT');
          await db.execute('ALTER TABLE folders ADD COLUMN defaultListId TEXT');
          await db.execute('ALTER TABLE app_lists ADD COLUMN description TEXT');
        }
        if (oldVersion < 32) {
          // Indexes on the columns controllers filter/join on. Purely a
          // performance change — query results are unaffected.
          await _createIndexes(db);
        }
        if (oldVersion < 33) {
          // Recurring events: a JSON-encoded Recurrence rule on the event,
          // expanded onto each repeat day in the view layer.
          await db.execute('ALTER TABLE events ADD COLUMN recurrence TEXT');
        }
        if (oldVersion < 34) {
          // Persisted per-list / per-folder view mode (list | kanban) and the
          // Kanban horizontal-scroll mode (free | snap). Null → defaults.
          await db.execute('ALTER TABLE folders ADD COLUMN viewMode TEXT');
          await db.execute(
              'ALTER TABLE folders ADD COLUMN kanbanScrollMode TEXT');
          await db.execute('ALTER TABLE app_lists ADD COLUMN viewMode TEXT');
          await db.execute(
              'ALTER TABLE app_lists ADD COLUMN kanbanScrollMode TEXT');
        }
        if (oldVersion < 35) {
          // Per-record updatedAt (merge-sync foundation) + a tombstones table
          // that records permanent deletions so they propagate across devices.
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE contacts ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE tags ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE folders ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE app_lists ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE note_folders ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE notes ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE routines ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE routine_entries ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE events ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE list_sections ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tombstones (
              tbl TEXT NOT NULL, id TEXT NOT NULL, deletedAt INTEGER NOT NULL,
              PRIMARY KEY (tbl, id)
            )
          ''');
          // Backfill updatedAt from the best existing timestamp so an unchanged
          // device doesn't clobber a newer one on first merge.
          await db.execute(
              'UPDATE tasks SET updatedAt = COALESCE(deletedDate, completionDate, creationDate, 0)');
          await db.execute(
              'UPDATE contacts SET updatedAt = COALESCE(deletedDate, creationDate, 0)');
          await db.execute(
              'UPDATE tags SET updatedAt = COALESCE(creationDate, 0)');
          await db.execute(
              'UPDATE folders SET updatedAt = COALESCE(deletedDate, creationDate, 0)');
          await db.execute(
              'UPDATE app_lists SET updatedAt = COALESCE(deletedDate, creationDate, 0)');
          await db.execute(
              'UPDATE note_folders SET updatedAt = COALESCE(deletedDate, creationDate, 0)');
          await db.execute(
              'UPDATE notes SET updatedAt = COALESCE(deletedDate, modifiedDate, creationDate, 0)');
          await db.execute(
              'UPDATE routines SET updatedAt = COALESCE(creationDate, 0)');
          await db.execute(
              'UPDATE routine_entries SET updatedAt = COALESCE(date, 0)');
          await db.execute(
              'UPDATE events SET updatedAt = COALESCE(deletedDate, creationDate, 0)');
          await db.execute(
              'UPDATE list_sections SET updatedAt = COALESCE(creationDate, 0)');
        }
      },
    );
  }

  /// Creates indexes on the columns the controllers repeatedly filter on
  /// (`WHERE listId = ?`, soft-delete scans, calendar/birthday date lookups,
  /// routine-entry joins, …). Idempotent (`IF NOT EXISTS`) so it can be shared
  /// by both `onCreate` and the v32 upgrade branch. Indexes are transparent to
  /// query results — they only reduce per-query CPU (battery) and latency.
  Future<void> _createIndexes(Database db) async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_tasks_listId ON tasks(listId)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_parentTaskId ON tasks(parentTaskId)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_isDeleted ON tasks(isDeleted)',
      'CREATE INDEX IF NOT EXISTS idx_app_lists_folderId ON app_lists(folderId)',
      'CREATE INDEX IF NOT EXISTS idx_app_lists_isDeleted ON app_lists(isDeleted)',
      'CREATE INDEX IF NOT EXISTS idx_folders_parentFolderId ON folders(parentFolderId)',
      'CREATE INDEX IF NOT EXISTS idx_folders_isDeleted ON folders(isDeleted)',
      'CREATE INDEX IF NOT EXISTS idx_notes_folderId ON notes(folderId)',
      'CREATE INDEX IF NOT EXISTS idx_notes_isDeleted ON notes(isDeleted)',
      'CREATE INDEX IF NOT EXISTS idx_note_folders_parentFolderId ON note_folders(parentFolderId)',
      'CREATE INDEX IF NOT EXISTS idx_note_folders_isDeleted ON note_folders(isDeleted)',
      'CREATE INDEX IF NOT EXISTS idx_contacts_listId ON contacts(listId)',
      'CREATE INDEX IF NOT EXISTS idx_contacts_isDeleted ON contacts(isDeleted)',
      'CREATE INDEX IF NOT EXISTS idx_contacts_birthday ON contacts(birthMonth, birthDay)',
      'CREATE INDEX IF NOT EXISTS idx_events_date ON events(date)',
      'CREATE INDEX IF NOT EXISTS idx_events_isDeleted ON events(isDeleted)',
      'CREATE INDEX IF NOT EXISTS idx_list_sections_listId ON list_sections(listId)',
      'CREATE INDEX IF NOT EXISTS idx_routine_entries_routineId ON routine_entries(routineId)',
      'CREATE INDEX IF NOT EXISTS idx_routine_entries_date ON routine_entries(date)',
    ];
    for (final stmt in statements) {
      await db.execute(stmt);
    }
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Insert-or-replace a user row, stamping updatedAt = now. Use for all
  /// user-initiated creates/edits so merge can tell which copy is newer.
  Future<void> _putRow(
      DatabaseExecutor db, String table, Map<String, Object?> values) {
    return db.insert(table, {...values, 'updatedAt': _nowMs()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Patch a user row, stamping updatedAt = now.
  Future<int> _patchRow(
      DatabaseExecutor db, String table, Map<String, Object?> values,
      {required String where, required List<Object?> whereArgs}) {
    return db.update(table, {...values, 'updatedAt': _nowMs()},
        where: where, whereArgs: whereArgs);
  }

  /// Records a permanent deletion so it propagates across devices on merge.
  Future<void> _recordTombstone(DatabaseExecutor db, String table, String id) {
    return db.insert('tombstones',
        {'tbl': table, 'id': id, 'deletedAt': _nowMs()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Tasks — active (non-deleted), sorted by manual order first, then newest first
  Future<List<Task>> getTasks() async {
    final db = await _database;
    final rows = await db.query('tasks',
        where: 'isDeleted = 0',
        orderBy: 'sortOrder ASC, creationDate DESC');
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> getTrashedTasks() async {
    final db = await _database;
    final rows = await db.query('tasks',
        where: 'isDeleted = 1',
        orderBy: 'deletedDate DESC');
    return rows.map(Task.fromMap).toList();
  }

  Future<void> insertTask(Task task) async {
    final db = await _database;
    await _putRow(db, 'tasks', task.toMap());
  }

  Future<void> updateTask(Task task) async {
    final db = await _database;
    await _patchRow(db, 'tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> softDeleteTask(String id, DateTime deletedDate) async {
    final db = await _database;
    await _patchRow(
      db,
      'tasks',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> softDeleteTasksForList(
      String listId, DateTime deletedDate) async {
    final db = await _database;
    await _patchRow(
      db,
      'tasks',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'listId = ? AND isDeleted = 0',
      whereArgs: [listId],
    );
  }

  Future<void> restoreTask(String id) async {
    final db = await _database;
    await _patchRow(
      db,
      'tasks',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> permanentlyDeleteTask(String id) async {
    final db = await _database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await _recordTombstone(db, 'tasks', id);
  }

  Future<void> deleteTasksForList(String listId) async {
    final db = await _database;
    final ids = (await db.query('tasks',
            columns: ['id'], where: 'listId = ?', whereArgs: [listId]))
        .map((r) => r['id'] as String)
        .toList();
    await db.delete('tasks', where: 'listId = ?', whereArgs: [listId]);
    for (final id in ids) {
      await _recordTombstone(db, 'tasks', id);
    }
  }

  Future<void> updateTaskSortOrders(List<Task> tasks) async {
    final db = await _database;
    final batch = db.batch();
    for (final task in tasks) {
      batch.update('tasks', {'sortOrder': task.sortOrder},
          where: 'id = ?', whereArgs: [task.id]);
    }
    await batch.commit(noResult: true);
  }

  // Task folders — active only
  Future<List<AppFolder>> getFolders() async {
    final db = await _database;
    final rows = await db.query('folders',
        where: 'isDeleted = 0',
        orderBy: 'sortOrder ASC, creationDate ASC');
    return rows.map(AppFolder.fromMap).toList();
  }

  Future<List<AppFolder>> getTrashedFolders() async {
    final db = await _database;
    final rows = await db.query('folders',
        where: 'isDeleted = 1',
        orderBy: 'deletedDate DESC');
    return rows.map(AppFolder.fromMap).toList();
  }

  Future<void> insertFolder(AppFolder folder) async {
    final db = await _database;
    await _putRow(db, 'folders', folder.toMap());
  }

  Future<void> updateFolder(AppFolder folder) async {
    final db = await _database;
    await _patchRow(db, 'folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> softDeleteFolder(String id, DateTime deletedDate) async {
    final db = await _database;
    await _patchRow(
      db,
      'folders',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreFolder(String id) async {
    final db = await _database;
    await _patchRow(
      db,
      'folders',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFolder(String id) async {
    final db = await _database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
    await _recordTombstone(db, 'folders', id);
  }

  Future<void> updateFolderSortOrders(List<AppFolder> folders) async {
    final db = await _database;
    final batch = db.batch();
    for (final f in folders) {
      batch.update('folders', {'sortOrder': f.sortOrder},
          where: 'id = ?', whereArgs: [f.id]);
    }
    await batch.commit(noResult: true);
  }

  // Lists — active only
  Future<List<AppList>> getLists() async {
    final db = await _database;
    final rows = await db.query('app_lists',
        where: 'isDeleted = 0',
        orderBy: 'sortOrder ASC, creationDate ASC');
    return rows.map(AppList.fromMap).toList();
  }

  Future<List<AppList>> getTrashedLists() async {
    final db = await _database;
    final rows = await db.query('app_lists',
        where: 'isDeleted = 1',
        orderBy: 'deletedDate DESC');
    return rows.map(AppList.fromMap).toList();
  }

  Future<void> insertList(AppList list) async {
    final db = await _database;
    await _putRow(db, 'app_lists', list.toMap());
  }

  Future<void> updateList(AppList list) async {
    final db = await _database;
    await _patchRow(db, 'app_lists', list.toMap(),
        where: 'id = ?', whereArgs: [list.id]);
  }

  Future<void> softDeleteList(String id, DateTime deletedDate) async {
    final db = await _database;
    await _patchRow(
      db,
      'app_lists',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreList(String id) async {
    final db = await _database;
    await _patchRow(
      db,
      'app_lists',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteList(String id) async {
    final db = await _database;
    await db.delete('app_lists', where: 'id = ?', whereArgs: [id]);
    await _recordTombstone(db, 'app_lists', id);
  }

  Future<void> updateListSortOrders(List<AppList> lists) async {
    final db = await _database;
    final batch = db.batch();
    for (final l in lists) {
      batch.update('app_lists', {'sortOrder': l.sortOrder},
          where: 'id = ?', whereArgs: [l.id]);
    }
    await batch.commit(noResult: true);
  }

  // Note folders — active only
  Future<List<NoteFolder>> getNoteFolders() async {
    final db = await _database;
    final rows = await db.query('note_folders',
        where: 'isDeleted = 0',
        orderBy: 'sortOrder ASC, creationDate ASC');
    return rows.map(NoteFolder.fromMap).toList();
  }

  Future<List<NoteFolder>> getTrashedNoteFolders() async {
    final db = await _database;
    final rows = await db.query('note_folders',
        where: 'isDeleted = 1', orderBy: 'deletedDate DESC');
    return rows.map(NoteFolder.fromMap).toList();
  }

  Future<void> insertNoteFolder(NoteFolder folder) async {
    final db = await _database;
    await _putRow(db, 'note_folders', folder.toMap());
  }

  Future<void> updateNoteFolder(NoteFolder folder) async {
    final db = await _database;
    await _patchRow(db, 'note_folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> softDeleteNoteFolder(String id, DateTime deletedDate) async {
    final db = await _database;
    await _patchRow(
      db,
      'note_folders',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreNoteFolder(String id) async {
    final db = await _database;
    await _patchRow(
      db,
      'note_folders',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNoteFolder(String id) async {
    final db = await _database;
    await db.delete('note_folders', where: 'id = ?', whereArgs: [id]);
    await _recordTombstone(db, 'note_folders', id);
  }

  Future<void> clearTrashedNoteFolders() async {
    final db = await _database;
    final ids = (await db.query('note_folders',
            columns: ['id'], where: 'isDeleted = 1'))
        .map((r) => r['id'] as String)
        .toList();
    await db.delete('note_folders', where: 'isDeleted = 1');
    for (final id in ids) {
      await _recordTombstone(db, 'note_folders', id);
    }
  }

  Future<void> updateNoteFolderSortOrders(List<NoteFolder> folders) async {
    final db = await _database;
    final batch = db.batch();
    for (final f in folders) {
      batch.update('note_folders', {'sortOrder': f.sortOrder},
          where: 'id = ?', whereArgs: [f.id]);
    }
    await batch.commit(noResult: true);
  }

  // Notes — active only
  Future<List<Note>> getNotes() async {
    final db = await _database;
    final rows = await db.query('notes',
        where: 'isDeleted = 0',
        orderBy: 'sortOrder ASC, modifiedDate DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> getTrashedNotes() async {
    final db = await _database;
    final rows = await db.query('notes',
        where: 'isDeleted = 1', orderBy: 'deletedDate DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<void> insertNote(Note note) async {
    final db = await _database;
    await _putRow(db, 'notes', note.toMap());
  }

  Future<void> updateNote(Note note) async {
    final db = await _database;
    await _patchRow(db, 'notes', note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> softDeleteNote(String id, DateTime deletedDate) async {
    final db = await _database;
    await _patchRow(
      db,
      'notes',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> softDeleteNotesForFolder(
      String folderId, DateTime deletedDate) async {
    final db = await _database;
    await _patchRow(
      db,
      'notes',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'folderId = ? AND isDeleted = 0',
      whereArgs: [folderId],
    );
  }

  Future<void> restoreNote(String id) async {
    final db = await _database;
    await _patchRow(
      db,
      'notes',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await _database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    await _recordTombstone(db, 'notes', id);
  }

  Future<void> deleteNotesForFolder(String folderId) async {
    final db = await _database;
    final ids = (await db.query('notes',
            columns: ['id'], where: 'folderId = ?', whereArgs: [folderId]))
        .map((r) => r['id'] as String)
        .toList();
    await db.delete('notes', where: 'folderId = ?', whereArgs: [folderId]);
    for (final id in ids) {
      await _recordTombstone(db, 'notes', id);
    }
  }

  Future<void> clearTrashedNotes() async {
    final db = await _database;
    final ids =
        (await db.query('notes', columns: ['id'], where: 'isDeleted = 1'))
            .map((r) => r['id'] as String)
            .toList();
    await db.delete('notes', where: 'isDeleted = 1');
    for (final id in ids) {
      await _recordTombstone(db, 'notes', id);
    }
  }

  Future<void> updateNoteSortOrders(List<Note> notes) async {
    final db = await _database;
    final batch = db.batch();
    for (final n in notes) {
      batch.update('notes', {'sortOrder': n.sortOrder},
          where: 'id = ?', whereArgs: [n.id]);
    }
    await batch.commit(noResult: true);
  }

  // Routines
  Future<List<Routine>> getRoutines() async {
    final db = await _database;
    final rows = await db.query('routines',
        orderBy: 'sortOrder ASC, creationDate ASC');
    return rows.map(Routine.fromMap).toList();
  }

  Future<void> updateRoutineSortOrders(List<Routine> routines) async {
    final db = await _database;
    final batch = db.batch();
    for (final r in routines) {
      batch.update('routines', {'sortOrder': r.sortOrder},
          where: 'id = ?', whereArgs: [r.id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertRoutine(Routine routine) async {
    final db = await _database;
    await _putRow(db, 'routines', routine.toMap());
  }

  Future<void> updateRoutine(Routine routine) async {
    final db = await _database;
    await _patchRow(db, 'routines', routine.toMap(),
        where: 'id = ?', whereArgs: [routine.id]);
  }

  Future<void> deleteRoutine(String id) async {
    final db = await _database;
    final entryIds = (await db.query('routine_entries',
            columns: ['id'], where: 'routineId = ?', whereArgs: [id]))
        .map((r) => r['id'] as String)
        .toList();
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
    await db.delete('routine_entries',
        where: 'routineId = ?', whereArgs: [id]);
    await _recordTombstone(db, 'routines', id);
    for (final entryId in entryIds) {
      await _recordTombstone(db, 'routine_entries', entryId);
    }
  }

  // Routine entries
  Future<List<RoutineEntry>> getRoutineEntries() async {
    final db = await _database;
    final rows =
        await db.query('routine_entries', orderBy: 'date DESC');
    return rows.map(RoutineEntry.fromMap).toList();
  }

  Future<void> insertRoutineEntry(RoutineEntry entry) async {
    final db = await _database;
    await _putRow(db, 'routine_entries', entry.toMap());
  }

  Future<void> updateRoutineEntry(RoutineEntry entry) async {
    final db = await _database;
    await _patchRow(db, 'routine_entries', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  // Events — calendar-only entity
  Future<List<Event>> getEvents() async {
    final db = await _database;
    final rows = await db.query('events',
        where: 'isDeleted = 0', orderBy: 'date ASC');
    return rows.map(Event.fromMap).toList();
  }

  Future<void> insertEvent(Event event) async {
    final db = await _database;
    await _putRow(db, 'events', event.toMap());
  }

  Future<void> updateEvent(Event event) async {
    final db = await _database;
    await _patchRow(db, 'events', event.toMap(),
        where: 'id = ?', whereArgs: [event.id]);
  }

  Future<void> permanentlyDeleteEvent(String id) async {
    final db = await _database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
    await _recordTombstone(db, 'events', id);
  }

  Future<List<Map<String, dynamic>>> exportEvents() async {
    final db = await _database;
    final rows = await db.query('events');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // List sections — user-defined groups of tasks within a list
  Future<List<ListSection>> getListSections() async {
    final db = await _database;
    final rows =
        await db.query('list_sections', orderBy: 'sortOrder ASC, creationDate ASC');
    return rows.map(ListSection.fromMap).toList();
  }

  Future<void> insertListSection(ListSection section) async {
    final db = await _database;
    await _putRow(db, 'list_sections', section.toMap());
  }

  Future<void> updateListSection(ListSection section) async {
    final db = await _database;
    await _patchRow(db, 'list_sections', section.toMap(),
        where: 'id = ?', whereArgs: [section.id]);
  }

  Future<void> deleteListSection(String id) async {
    final db = await _database;
    await db.delete('list_sections', where: 'id = ?', whereArgs: [id]);
    await _recordTombstone(db, 'list_sections', id);
  }

  Future<void> deleteSectionsForList(String listId) async {
    final db = await _database;
    final ids = (await db.query('list_sections',
            columns: ['id'], where: 'listId = ?', whereArgs: [listId]))
        .map((r) => r['id'] as String)
        .toList();
    await db.delete('list_sections',
        where: 'listId = ?', whereArgs: [listId]);
    for (final id in ids) {
      await _recordTombstone(db, 'list_sections', id);
    }
  }

  Future<void> updateListSectionSortOrders(List<ListSection> sections) async {
    final db = await _database;
    final batch = db.batch();
    for (final s in sections) {
      batch.update('list_sections', {'sortOrder': s.sortOrder},
          where: 'id = ?', whereArgs: [s.id]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> exportListSections() async {
    final db = await _database;
    final rows = await db.query('list_sections');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // Contacts — birthday entries that belong to a Birthdays-type AppList.
  Future<List<Contact>> getContacts() async {
    final db = await _database;
    final rows = await db.query('contacts',
        where: 'isDeleted = 0',
        orderBy: 'sortOrder ASC, creationDate ASC');
    return rows.map(Contact.fromMap).toList();
  }

  Future<List<Contact>> getTrashedContacts() async {
    final db = await _database;
    final rows = await db.query('contacts',
        where: 'isDeleted = 1', orderBy: 'deletedDate DESC');
    return rows.map(Contact.fromMap).toList();
  }

  Future<void> insertContact(Contact contact) async {
    final db = await _database;
    await _putRow(db, 'contacts', contact.toMap());
  }

  Future<void> updateContact(Contact contact) async {
    final db = await _database;
    await _patchRow(db, 'contacts', contact.toMap(),
        where: 'id = ?', whereArgs: [contact.id]);
  }

  Future<void> softDeleteContact(String id, DateTime deletedDate) async {
    final db = await _database;
    await _patchRow(
      db,
      'contacts',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> softDeleteContactsForList(
      String listId, DateTime deletedDate) async {
    final db = await _database;
    await _patchRow(
      db,
      'contacts',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'listId = ? AND isDeleted = 0',
      whereArgs: [listId],
    );
  }

  Future<void> restoreContact(String id) async {
    final db = await _database;
    await _patchRow(
      db,
      'contacts',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> permanentlyDeleteContact(String id) async {
    final db = await _database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    await _recordTombstone(db, 'contacts', id);
  }

  Future<void> deleteContactsForList(String listId) async {
    final db = await _database;
    final ids = (await db.query('contacts',
            columns: ['id'], where: 'listId = ?', whereArgs: [listId]))
        .map((r) => r['id'] as String)
        .toList();
    await db.delete('contacts', where: 'listId = ?', whereArgs: [listId]);
    for (final id in ids) {
      await _recordTombstone(db, 'contacts', id);
    }
  }

  Future<void> clearTrashedContacts() async {
    final db = await _database;
    final ids =
        (await db.query('contacts', columns: ['id'], where: 'isDeleted = 1'))
            .map((r) => r['id'] as String)
            .toList();
    await db.delete('contacts', where: 'isDeleted = 1');
    for (final id in ids) {
      await _recordTombstone(db, 'contacts', id);
    }
  }

  Future<List<Map<String, dynamic>>> exportContacts() async {
    final db = await _database;
    final rows = await db.query('contacts');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }


  Future<void> clearTrashedTasks() async {
    final db = await _database;
    final ids =
        (await db.query('tasks', columns: ['id'], where: 'isDeleted = 1'))
            .map((r) => r['id'] as String)
            .toList();
    await db.delete('tasks', where: 'isDeleted = 1');
    for (final id in ids) {
      await _recordTombstone(db, 'tasks', id);
    }
  }

  Future<void> clearTrashedFolders() async {
    final db = await _database;
    final ids =
        (await db.query('folders', columns: ['id'], where: 'isDeleted = 1'))
            .map((r) => r['id'] as String)
            .toList();
    await db.delete('folders', where: 'isDeleted = 1');
    for (final id in ids) {
      await _recordTombstone(db, 'folders', id);
    }
  }

  Future<void> clearTrashedLists() async {
    final db = await _database;
    final ids =
        (await db.query('app_lists', columns: ['id'], where: 'isDeleted = 1'))
            .map((r) => r['id'] as String)
            .toList();
    await db.delete('app_lists', where: 'isDeleted = 1');
    for (final id in ids) {
      await _recordTombstone(db, 'app_lists', id);
    }
  }

  // Tags — flat, name-uniqueness enforced in the controller
  Future<List<Map<String, dynamic>>> getTags() async {
    final db = await _database;
    final rows = await db.query('tags', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> insertTag(Map<String, dynamic> tag) async {
    final db = await _database;
    await _putRow(db, 'tags', tag);
  }

  Future<void> updateTag(Map<String, dynamic> tag) async {
    final db = await _database;
    await _patchRow(db, 'tags', tag, where: 'id = ?', whereArgs: [tag['id']]);
  }

  Future<void> deleteTag(String id) async {
    final db = await _database;
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
    await _recordTombstone(db, 'tags', id);
  }

  Future<List<Map<String, dynamic>>> exportTags() async {
    final db = await _database;
    final rows = await db.query('tags');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // App settings — generic key/value store for app-level preferences
  Future<List<Map<String, dynamic>>> getAppSettings() async {
    final db = await _database;
    return db.query('app_settings');
  }

  Future<void> setAppSetting(String key, String value) async {
    final db = await _database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAppSetting(String key) async {
    final db = await _database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
  }

  // ── Backup / Restore ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> exportTasks() async {
    final db = await _database;
    final rows = await db.query('tasks');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> exportFolders() async {
    final db = await _database;
    final rows = await db.query('folders');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> exportLists() async {
    final db = await _database;
    final rows = await db.query('app_lists');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> exportNoteFolders() async {
    final db = await _database;
    final rows = await db.query('note_folders');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> exportNotes() async {
    final db = await _database;
    final rows = await db.query('notes');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> exportRoutines() async {
    final db = await _database;
    final rows = await db.query('routines');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> exportRoutineEntries() async {
    final db = await _database;
    final rows = await db.query('routine_entries');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> exportAppSettings() async {
    final db = await _database;
    final rows = await db.query('app_settings');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> exportTombstones() async {
    final db = await _database;
    final rows = await db.query('tombstones');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static const _allTables = [
    'tombstones',
    'contacts',
    'events',
    'list_sections',
    'app_settings',
    'routine_entries',
    'routines',
    'notes',
    'note_folders',
    'app_lists',
    'folders',
    'tags',
    'tasks',
  ];

  /// Atomically replaces all data: clears every table and re-inserts the given
  /// rows inside a single transaction, keyed by table name. If any insert (or
  /// the clear) throws, the whole transaction rolls back and the existing data
  /// is left intact — so a corrupt or partial backup can never destroy it.
  Future<void> replaceAllData(
      Map<String, List<Map<String, dynamic>>> tables) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final table in _allTables) {
        await txn.delete(table);
      }
      for (final entry in tables.entries) {
        if (entry.value.isEmpty) continue;
        final batch = txn.batch();
        for (final row in entry.value) {
          batch.insert(entry.key, row,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<void> resetUserData() async {
    final db = await _database;
    await db.delete('contacts');
    await db.delete('events');
    await db.delete('list_sections');
    await db.delete('routine_entries');
    await db.delete('routines');
    await db.delete('notes');
    await db.delete('note_folders');
    await db.delete('app_lists');
    await db.delete('folders');
    await db.delete('tags');
    await db.delete('tasks');
    await db.delete('tombstones');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── Full-text search (FTS5) ────────────────────────────────────────────────

  /// Searches tasks, notes and events for [query] and returns up to [limit]
  /// matching ids per source table. Excludes trashed rows. Quotes/escapes the
  /// query so user input can't poison the FTS MATCH expression.
  Future<SearchResults> searchAll(String query, {int limit = 50}) async {
    final db = await _database;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const SearchResults({}, {}, {});

    // Wrap each whitespace-separated token in double quotes (with internal
    // quotes doubled) and join with a space — gives the user implicit AND
    // matching without exposing FTS5 syntax to typos.
    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*')
        .join(' ');

    Future<Set<String>> idsFrom(String fts) async {
      final rows = await db.rawQuery(
        'SELECT id FROM $fts WHERE $fts MATCH ? LIMIT ?',
        [tokens, limit],
      );
      return rows.map((r) => r['id'] as String).toSet();
    }

    final tasks = await idsFrom('tasks_fts');
    final notes = await idsFrom('notes_fts');
    final events = await idsFrom('events_fts');
    return SearchResults(tasks, notes, events);
  }

  static Future<void> _createFtsTables(Database db) async {
    // Contentless FTS5 tables keyed by the source row's id (UNINDEXED so it
    // doesn't get tokenised). Triggers below keep them in sync — see
    // _backfillFts for the one-time population on migration.
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS tasks_fts
      USING fts5(id UNINDEXED, title, body, tokenize='unicode61');
    ''');
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts
      USING fts5(id UNINDEXED, title, body, tokenize='unicode61');
    ''');
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS events_fts
      USING fts5(id UNINDEXED, title, body, tokenize='unicode61');
    ''');

    await _createTaskFtsTriggers(db);

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
        DELETE FROM notes_fts WHERE id = new.id;
        INSERT INTO notes_fts(id, title, body)
          VALUES (new.id, new.title, new.content);
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
        DELETE FROM notes_fts WHERE id = old.id;
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
        DELETE FROM notes_fts WHERE id = old.id;
        INSERT INTO notes_fts(id, title, body)
          VALUES (new.id, new.title, new.content);
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS events_ai AFTER INSERT ON events BEGIN
        DELETE FROM events_fts WHERE id = new.id;
        INSERT INTO events_fts(id, title, body)
          VALUES (new.id, new.title, COALESCE(new.note, ''));
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS events_ad AFTER DELETE ON events BEGIN
        DELETE FROM events_fts WHERE id = old.id;
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS events_au AFTER UPDATE ON events BEGIN
        DELETE FROM events_fts WHERE id = old.id;
        INSERT INTO events_fts(id, title, body)
          VALUES (new.id, new.title, COALESCE(new.note, ''));
      END;
    ''');
  }

  /// Tasks FTS triggers — extracted so [onUpgrade] can re-create them after
  /// rebuilding the `tasks` table (DROP/RENAME breaks the original triggers).
  static Future<void> _createTaskFtsTriggers(Database db) async {
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS tasks_ai AFTER INSERT ON tasks BEGIN
        DELETE FROM tasks_fts WHERE id = new.id;
        INSERT INTO tasks_fts(id, title, body)
          VALUES (new.id, new.title, COALESCE(new.note, ''));
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS tasks_ad AFTER DELETE ON tasks BEGIN
        DELETE FROM tasks_fts WHERE id = old.id;
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS tasks_au AFTER UPDATE ON tasks BEGIN
        DELETE FROM tasks_fts WHERE id = old.id;
        INSERT INTO tasks_fts(id, title, body)
          VALUES (new.id, new.title, COALESCE(new.note, ''));
      END;
    ''');
  }

  /// One-shot backfill of every row that existed before FTS arrived.
  /// Idempotent: triggers above start the moment the tables exist, so any new
  /// rows are already in fts; this catches the legacy ones.
  static Future<void> _backfillFts(Database db) async {
    await db.execute(
      "INSERT INTO tasks_fts(id, title, body) "
      "SELECT id, title, COALESCE(note, '') FROM tasks "
      "WHERE id NOT IN (SELECT id FROM tasks_fts);",
    );
    await db.execute(
      "INSERT INTO notes_fts(id, title, body) "
      "SELECT id, title, content FROM notes "
      "WHERE id NOT IN (SELECT id FROM notes_fts);",
    );
    await db.execute(
      "INSERT INTO events_fts(id, title, body) "
      "SELECT id, title, COALESCE(note, '') FROM events "
      "WHERE id NOT IN (SELECT id FROM events_fts);",
    );
  }
}

/// Container for the three buckets returned by [DatabaseService.searchAll].
class SearchResults {
  const SearchResults(this.taskIds, this.noteIds, this.eventIds);

  final Set<String> taskIds;
  final Set<String> noteIds;
  final Set<String> eventIds;

  bool get isEmpty =>
      taskIds.isEmpty && noteIds.isEmpty && eventIds.isEmpty;
  int get total => taskIds.length + noteIds.length + eventIds.length;
}
