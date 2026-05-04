import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_folder.dart';
import '../models/app_list.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/routine.dart';
import '../models/routine_entry.dart';
import '../models/task.dart';

class DatabaseService {
  static const _dbName = 'planom.db';
  static const _dbVersion = 7;

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, _dbName),
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
            listId TEXT,
            priority INTEGER NOT NULL DEFAULT 0,
            sortOrder INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentFolderId TEXT,
            creationDate INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE app_lists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            folderId TEXT,
            creationDate INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE note_folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentFolderId TEXT,
            creationDate INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0
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
            sortOrder INTEGER NOT NULL DEFAULT 0
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
      },
    );
  }

  // Tasks — sorted by manual order first, then newest first for unsorted items
  Future<List<Task>> getTasks() async {
    final db = await _database;
    final rows = await db.query('tasks',
        orderBy: 'sortOrder ASC, creationDate DESC');
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

  Future<void> deleteTask(String id) async {
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

  // Task folders
  Future<List<AppFolder>> getFolders() async {
    final db = await _database;
    final rows = await db.query('folders',
        orderBy: 'sortOrder ASC, creationDate ASC');
    return rows.map(AppFolder.fromMap).toList();
  }

  Future<void> insertFolder(AppFolder folder) async {
    final db = await _database;
    await db.insert('folders', folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
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

  // Lists
  Future<List<AppList>> getLists() async {
    final db = await _database;
    final rows = await db.query('app_lists',
        orderBy: 'sortOrder ASC, creationDate ASC');
    return rows.map(AppList.fromMap).toList();
  }

  Future<void> insertList(AppList list) async {
    final db = await _database;
    await db.insert('app_lists', list.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
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

  // Note folders
  Future<List<NoteFolder>> getNoteFolders() async {
    final db = await _database;
    final rows = await db.query('note_folders',
        orderBy: 'sortOrder ASC, creationDate ASC');
    return rows.map(NoteFolder.fromMap).toList();
  }

  Future<void> insertNoteFolder(NoteFolder folder) async {
    final db = await _database;
    await db.insert('note_folders', folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteNoteFolder(String id) async {
    final db = await _database;
    await db.delete('note_folders', where: 'id = ?', whereArgs: [id]);
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

  // Notes
  Future<List<Note>> getNotes() async {
    final db = await _database;
    final rows = await db.query('notes',
        orderBy: 'sortOrder ASC, modifiedDate DESC');
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

  Future<void> deleteNote(String id) async {
    final db = await _database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNotesForFolder(String folderId) async {
    final db = await _database;
    await db.delete('notes', where: 'folderId = ?', whereArgs: [folderId]);
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
}
