import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/database/database_service.dart';

/// Initializes the sqflite FFI backend so [DatabaseService] can open real
/// (on-disk, temp-dir) SQLite files during tests. Call once from `main()`.
void initTestDatabaseFactory() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

int _dbSeq = 0;

/// Returns a fresh [DatabaseService] backed by a uniquely-named DB file so
/// each test is fully isolated. The schema is created on first access.
DatabaseService freshDb() {
  _dbSeq++;
  return DatabaseService(
    dbName: 'test_${DateTime.now().microsecondsSinceEpoch}_$_dbSeq.db',
  );
}

/// Midnight of today (handy for date-based assertions).
DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
