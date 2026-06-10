import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;

  setUp(() {
    db = DatabaseService(
        dbName: 'test_updatedat_${DateTime.now().microsecondsSinceEpoch}.db');
  });

  tearDown(() async {
    await db.close();
  });

  Future<Map<String, dynamic>> rowFor(String id) async {
    final rows = await db.exportTasks();
    return rows.firstWhere((r) => r['id'] == id);
  }

  test('insertTask stamps updatedAt > 0', () async {
    final task = Task(title: 'Buy milk');
    await db.insertTask(task);

    final row = await rowFor(task.id);
    expect(row['updatedAt'], isA<int>());
    expect(row['updatedAt'] as int, greaterThan(0));
  });

  test('updateTask re-stamps updatedAt (>= previous) on change', () async {
    final task = Task(title: 'Original');
    await db.insertTask(task);
    final before = (await rowFor(task.id))['updatedAt'] as int;

    // Small delay so the wall clock advances and the stamp can move forward.
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await db.updateTask(task.copyWith(title: 'Edited'));
    final after = await rowFor(task.id);

    expect(after['title'], 'Edited');
    expect(after['updatedAt'] as int, greaterThanOrEqualTo(before));
    expect(after['updatedAt'] as int, greaterThan(0));
  });

  test('permanentlyDeleteTask records a tombstone for the task', () async {
    final task = Task(title: 'Disposable');
    await db.insertTask(task);

    await db.permanentlyDeleteTask(task.id);

    // Row is gone.
    final tasks = await db.exportTasks();
    expect(tasks.any((r) => r['id'] == task.id), isFalse);

    // Tombstone exists with the right table + id.
    final tombstones = await db.exportTombstones();
    final match = tombstones.where(
        (t) => t['tbl'] == 'tasks' && t['id'] == task.id);
    expect(match, isNotEmpty);
    expect(match.first['deletedAt'] as int, greaterThan(0));
  });
}
