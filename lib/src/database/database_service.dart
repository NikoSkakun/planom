import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_folder.dart';
import '../models/app_list.dart';
import '../models/task.dart';

class DatabaseService {
  static const _dbName = 'planom.db';
  static const _dbVersion = 4;

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
            listId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentFolderId TEXT,
            creationDate INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE app_lists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            folderId TEXT,
            creationDate INTEGER NOT NULL
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
      },
    );
  }

  // Tasks
  Future<List<Task>> getTasks() async {
    final db = await _database;
    final rows = await db.query('tasks', orderBy: 'creationDate DESC');
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

  // Folders
  Future<List<AppFolder>> getFolders() async {
    final db = await _database;
    final rows = await db.query('folders', orderBy: 'creationDate ASC');
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

  // Lists
  Future<List<AppList>> getLists() async {
    final db = await _database;
    final rows = await db.query('app_lists', orderBy: 'creationDate ASC');
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
}
