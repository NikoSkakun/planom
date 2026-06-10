import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/database/database_service.dart';

/// Exercises DatabaseService.mergeAllData — the per-record convergence
/// primitive. mergeAllData inserts incoming rows with their own `updatedAt`,
/// so we can seed "local" state by merging one payload and then assert how a
/// second ("remote") payload merges into it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;

  setUp(() {
    db = DatabaseService(
        dbName: 'test_merge_${DateTime.now().microsecondsSinceEpoch}.db');
  });

  tearDown(() async {
    await db.close();
  });

  Map<String, Object?> task(String id, String title, int updatedAt) => {
        'id': id,
        'creationDate': 1,
        'iconId': 'x',
        'title': title,
        'isCompleted': 0,
        'updatedAt': updatedAt,
      };

  Future<Map<String, dynamic>?> taskRow(String id) async {
    final rows = await db.exportTasks();
    final match = rows.where((r) => r['id'] == id);
    return match.isEmpty ? null : match.first;
  }

  Future<void> merge({
    List<Map<String, Object?>> tasks = const [],
    List<Map<String, Object?>> tombstones = const [],
  }) =>
      db.mergeAllData({'tasks': tasks, 'tombstones': tombstones});

  test('inserts rows that do not exist locally', () async {
    await merge(tasks: [task('a', 'Alpha', 100)]);
    expect((await taskRow('a'))?['title'], 'Alpha');
  });

  test('newer incoming row wins; older incoming row is ignored', () async {
    await merge(tasks: [task('a', 'v1', 100)]);

    // Newer remote edit overwrites.
    await merge(tasks: [task('a', 'v2', 200)]);
    expect((await taskRow('a'))?['title'], 'v2');

    // Stale remote edit must NOT clobber the newer local copy.
    await merge(tasks: [task('a', 'v0', 50)]);
    expect((await taskRow('a'))?['title'], 'v2');
  });

  test('a newer tombstone deletes the local row', () async {
    await merge(tasks: [task('a', 'Alpha', 100)]);
    await merge(tombstones: [
      {'tbl': 'tasks', 'id': 'a', 'deletedAt': 300}
    ]);
    expect(await taskRow('a'), isNull);
  });

  test('a tombstone suppresses re-adding a staler incoming row', () async {
    await merge(tombstones: [
      {'tbl': 'tasks', 'id': 'a', 'deletedAt': 300}
    ]);
    // Remote still has an older copy — it must not resurrect.
    await merge(tasks: [task('a', 'Zombie', 250)]);
    expect(await taskRow('a'), isNull);
  });

  test('an edit newer than the tombstone wins over the deletion', () async {
    await merge(tombstones: [
      {'tbl': 'tasks', 'id': 'a', 'deletedAt': 300}
    ]);
    await merge(tasks: [task('a', 'Revived', 400)]);
    expect((await taskRow('a'))?['title'], 'Revived');
  });

  test('an older tombstone does not delete a newer local row', () async {
    await merge(tasks: [task('a', 'Current', 500)]);
    await merge(tombstones: [
      {'tbl': 'tasks', 'id': 'a', 'deletedAt': 200}
    ]);
    expect((await taskRow('a'))?['title'], 'Current');
  });

  test('tombstone ledger keeps the newest deletion on merge', () async {
    await merge(tombstones: [
      {'tbl': 'tasks', 'id': 'a', 'deletedAt': 100}
    ]);
    await merge(tombstones: [
      {'tbl': 'tasks', 'id': 'a', 'deletedAt': 300}
    ]);
    final tombstones = await db.exportTombstones();
    final match = tombstones.where((t) => t['id'] == 'a').toList();
    expect(match.length, 1);
    expect(match.first['deletedAt'], 300);
  });
}
