import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_folder.dart';
import '../models/app_list.dart';
import '../models/event.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/routine.dart';
import '../models/routine_entry.dart';
import '../models/task.dart';

class DatabaseService {
  DatabaseService({this.dbName = 'planom.db'});

  final String dbName;
  static const _dbVersion = 20;

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
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
            recurrence TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color INTEGER,
            creationDate INTEGER NOT NULL
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
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedDate INTEGER
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
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedDate INTEGER
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
            deletedDate INTEGER
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
            deletedDate INTEGER
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
            frequencyType TEXT NOT NULL,
            weekdays TEXT,
            daysAfterComplete INTEGER,
            autoReset TEXT NOT NULL
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
            reminderOffsets TEXT
          )
        ''');
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
      },
    );
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
    await db.insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTask(Task task) async {
    final db = await _database;
    await db.update('tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> softDeleteTask(String id, DateTime deletedDate) async {
    final db = await _database;
    await db.update(
      'tasks',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> softDeleteTasksForList(
      String listId, DateTime deletedDate) async {
    final db = await _database;
    await db.update(
      'tasks',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'listId = ? AND isDeleted = 0',
      whereArgs: [listId],
    );
  }

  Future<void> restoreTask(String id) async {
    final db = await _database;
    await db.update(
      'tasks',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> permanentlyDeleteTask(String id) async {
    final db = await _database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTasksForList(String listId) async {
    final db = await _database;
    await db.delete('tasks', where: 'listId = ?', whereArgs: [listId]);
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
    await db.insert('folders', folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateFolder(AppFolder folder) async {
    final db = await _database;
    await db.update('folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> softDeleteFolder(String id, DateTime deletedDate) async {
    final db = await _database;
    await db.update(
      'folders',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreFolder(String id) async {
    final db = await _database;
    await db.update(
      'folders',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFolder(String id) async {
    final db = await _database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
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
    await db.insert('app_lists', list.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateList(AppList list) async {
    final db = await _database;
    await db.update('app_lists', list.toMap(),
        where: 'id = ?', whereArgs: [list.id]);
  }

  Future<void> softDeleteList(String id, DateTime deletedDate) async {
    final db = await _database;
    await db.update(
      'app_lists',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreList(String id) async {
    final db = await _database;
    await db.update(
      'app_lists',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteList(String id) async {
    final db = await _database;
    await db.delete('app_lists', where: 'id = ?', whereArgs: [id]);
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
    await db.insert('note_folders', folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateNoteFolder(NoteFolder folder) async {
    final db = await _database;
    await db.update('note_folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> softDeleteNoteFolder(String id, DateTime deletedDate) async {
    final db = await _database;
    await db.update(
      'note_folders',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreNoteFolder(String id) async {
    final db = await _database;
    await db.update(
      'note_folders',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNoteFolder(String id) async {
    final db = await _database;
    await db.delete('note_folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTrashedNoteFolders() async {
    final db = await _database;
    await db.delete('note_folders', where: 'isDeleted = 1');
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
    await db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateNote(Note note) async {
    final db = await _database;
    await db.update('notes', note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> softDeleteNote(String id, DateTime deletedDate) async {
    final db = await _database;
    await db.update(
      'notes',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> softDeleteNotesForFolder(
      String folderId, DateTime deletedDate) async {
    final db = await _database;
    await db.update(
      'notes',
      {'isDeleted': 1, 'deletedDate': deletedDate.millisecondsSinceEpoch},
      where: 'folderId = ? AND isDeleted = 0',
      whereArgs: [folderId],
    );
  }

  Future<void> restoreNote(String id) async {
    final db = await _database;
    await db.update(
      'notes',
      {'isDeleted': 0, 'deletedDate': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await _database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNotesForFolder(String folderId) async {
    final db = await _database;
    await db.delete('notes', where: 'folderId = ?', whereArgs: [folderId]);
  }

  Future<void> clearTrashedNotes() async {
    final db = await _database;
    await db.delete('notes', where: 'isDeleted = 1');
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
    final rows = await db.query('routines', orderBy: 'creationDate ASC');
    return rows.map(Routine.fromMap).toList();
  }

  Future<void> insertRoutine(Routine routine) async {
    final db = await _database;
    await db.insert('routines', routine.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRoutine(Routine routine) async {
    final db = await _database;
    await db.update('routines', routine.toMap(),
        where: 'id = ?', whereArgs: [routine.id]);
  }

  Future<void> deleteRoutine(String id) async {
    final db = await _database;
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
    await db.delete('routine_entries',
        where: 'routineId = ?', whereArgs: [id]);
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
    await db.insert('routine_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRoutineEntry(RoutineEntry entry) async {
    final db = await _database;
    await db.update('routine_entries', entry.toMap(),
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
    await db.insert('events', event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateEvent(Event event) async {
    final db = await _database;
    await db.update('events', event.toMap(),
        where: 'id = ?', whereArgs: [event.id]);
  }

  Future<void> permanentlyDeleteEvent(String id) async {
    final db = await _database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> exportEvents() async {
    final db = await _database;
    final rows = await db.query('events');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }


  Future<void> clearTrashedTasks() async {
    final db = await _database;
    await db.delete('tasks', where: 'isDeleted = 1');
  }

  Future<void> clearTrashedFolders() async {
    final db = await _database;
    await db.delete('folders', where: 'isDeleted = 1');
  }

  Future<void> clearTrashedLists() async {
    final db = await _database;
    await db.delete('app_lists', where: 'isDeleted = 1');
  }

  // Tags — flat, name-uniqueness enforced in the controller
  Future<List<Map<String, dynamic>>> getTags() async {
    final db = await _database;
    final rows = await db.query('tags', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> insertTag(Map<String, dynamic> tag) async {
    final db = await _database;
    await db.insert('tags', tag,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTag(Map<String, dynamic> tag) async {
    final db = await _database;
    await db.update('tags', tag, where: 'id = ?', whereArgs: [tag['id']]);
  }

  Future<void> deleteTag(String id) async {
    final db = await _database;
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
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

  static const _allTables = [
    'events',
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
    await db.delete('events');
    await db.delete('routine_entries');
    await db.delete('routines');
    await db.delete('notes');
    await db.delete('note_folders');
    await db.delete('app_lists');
    await db.delete('folders');
    await db.delete('tags');
    await db.delete('tasks');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
