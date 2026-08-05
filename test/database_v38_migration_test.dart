import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/finance_account.dart';
import 'package:planom/src/models/finance_category.dart';
import 'package:planom/src/models/finance_transaction.dart';
import 'package:planom/src/models/goal.dart';

import 'support/test_db.dart';

/// The v37 shape of the tables the v38 branch touches. Enough of the schema to
/// prove the upgrade path — the branch only ALTERs `finance_transactions` and
/// creates the two new tables.
const _v37FinanceTransactions = '''
  CREATE TABLE IF NOT EXISTS finance_transactions (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    amount INTEGER NOT NULL DEFAULT 0,
    type TEXT NOT NULL DEFAULT 'expense',
    categoryId TEXT,
    date INTEGER NOT NULL,
    note TEXT,
    creationDate INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL DEFAULT 0
  )
''';

const _v37Tombstones = '''
  CREATE TABLE IF NOT EXISTS tombstones (
    tbl TEXT NOT NULL, id TEXT NOT NULL, deletedAt INTEGER NOT NULL,
    PRIMARY KEY (tbl, id)
  )
''';

/// A v36-era database: the finance tables do not exist at all yet, so opening
/// it runs BOTH the v37 branch (which creates them with today's full column
/// set) and the v38 branch (which must therefore not re-add those columns).
const _v36Tasks = '''
  CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    creationDate INTEGER NOT NULL,
    iconId TEXT NOT NULL,
    title TEXT NOT NULL,
    isCompleted INTEGER NOT NULL DEFAULT 0,
    sortOrder INTEGER NOT NULL DEFAULT 0,
    isDeleted INTEGER NOT NULL DEFAULT 0,
    updatedAt INTEGER NOT NULL DEFAULT 0
  )
''';

void main() {
  initTestDatabaseFactory();

  /// Writes a v37-shaped database file and returns its name, so opening it
  /// through [DatabaseService] runs the real v38 upgrade branch.
  Future<String> seedV37Database({required String legacyEntryId}) async {
    final name = 'migration_${DateTime.now().microsecondsSinceEpoch}.db';
    final dir = await databaseFactory.getDatabasesPath();
    final db = await databaseFactory.openDatabase(
      p.join(dir, name),
      options: OpenDatabaseOptions(
        version: 37,
        onCreate: (db, _) async {
          await db.execute(_v37FinanceTransactions);
          await db.execute(_v37Tombstones);
        },
      ),
    );
    await db.insert('finance_transactions', {
      'id': legacyEntryId,
      'title': 'Groceries',
      'amount': 1250,
      'type': 'expense',
      'categoryId': null,
      'date': DateTime(2026, 3, 1).millisecondsSinceEpoch,
      'note': null,
      'creationDate': DateTime(2026, 3, 1).millisecondsSinceEpoch,
      'updatedAt': 0,
    });
    await db.close();
    return name;
  }

  test('upgrading v37 → v38 adds goals, accounts and the account columns',
      () async {
    final name = await seedV37Database(legacyEntryId: 'legacy-1');
    final svc = DatabaseService(dbName: name);

    // Pre-existing rows survive and read back with the new nullable columns.
    final entries = await svc.getFinanceTransactions();
    expect(entries.length, 1);
    expect(entries.single.id, 'legacy-1');
    expect(entries.single.amount, 1250);
    expect(entries.single.accountId, isNull);
    expect(entries.single.toAccountId, isNull);
    expect(entries.single.toAmount, isNull);

    // The tables the branch creates are usable.
    expect(await svc.getGoals(), isEmpty);
    expect(await svc.getFinanceAccounts(), isEmpty);

    final account = FinanceAccount(name: 'Card', currencyCode: 'EUR');
    await svc.insertFinanceAccount(account);
    expect((await svc.getFinanceAccounts()).single.currencyCode, 'EUR');

    final goal = Goal(name: 'Ship', sources: [
      GoalSource(scopeType: GoalScopeType.lists, scopeIds: const ['l1']),
    ]);
    await svc.insertGoal(goal);
    expect((await svc.getGoals()).single.sources.single.scopeIds, ['l1']);

    // And a transfer can be written against the migrated columns.
    await svc.insertFinanceTransaction(FinanceTransaction(
      title: 'Move',
      amount: 500,
      type: FinanceEntryType.transfer,
      accountId: account.id,
      toAccountId: 'other',
      toAmount: 460,
      date: DateTime(2026, 3, 2),
    ));
    final moved = (await svc.getFinanceTransactions())
        .firstWhere((t) => t.type == FinanceEntryType.transfer);
    expect(moved.toAmount, 460);
    await svc.close();
  });

  test('re-opening an already-migrated database does not re-run the ALTERs',
      () async {
    final name = await seedV37Database(legacyEntryId: 'legacy-2');
    final first = DatabaseService(dbName: name);
    await first.getFinanceTransactions(); // triggers the upgrade
    await first.close();

    // A second open must be a no-op; a repeated ALTER would throw
    // "duplicate column name".
    final second = DatabaseService(dbName: name);
    expect((await second.getFinanceTransactions()).single.id, 'legacy-2');
    expect(await second.getGoals(), isEmpty);
    await second.close();
  });

  test('a fresh v38 database has the same finance columns as a migrated one',
      () async {
    final fresh = freshDb();
    await fresh.insertFinanceTransaction(FinanceTransaction(
      title: 'Direct',
      amount: 900,
      type: FinanceEntryType.transfer,
      accountId: 'a',
      toAccountId: 'b',
      toAmount: 800,
      date: DateTime(2026, 4, 1),
    ));
    final tx = (await fresh.getFinanceTransactions()).single;
    expect(tx.toAccountId, 'b');
    expect(tx.toAmount, 800);
    expect(await fresh.getFinanceAccounts(), isEmpty);
    expect(await fresh.getGoals(), isEmpty);
  });

  test('upgrading from v36 (no finance tables at all) does not crash',
      () async {
    // Regression: the v37 branch creates finance_transactions with the account
    // columns already present, so an unconditional ALTER in the v38 branch
    // threw "duplicate column name: accountId" and the database never opened.
    final name = 'migration_v36_${DateTime.now().microsecondsSinceEpoch}.db';
    final dir = await databaseFactory.getDatabasesPath();
    final legacy = await databaseFactory.openDatabase(
      p.join(dir, name),
      options: OpenDatabaseOptions(
        version: 36,
        onCreate: (db, _) async {
          await db.execute(_v36Tasks);
          await db.execute(_v37Tombstones);
        },
      ),
    );
    await legacy.close();

    final svc = DatabaseService(dbName: name);
    // Opening at all is the assertion; these prove the v38 objects landed.
    expect(await svc.getFinanceTransactions(), isEmpty);
    expect(await svc.getFinanceAccounts(), isEmpty);
    expect(await svc.getGoals(), isEmpty);

    await svc.insertFinanceTransaction(FinanceTransaction(
      title: 'Move',
      amount: 100,
      type: FinanceEntryType.transfer,
      accountId: 'a',
      toAccountId: 'b',
      toAmount: 90,
      date: DateTime(2026, 5, 1),
    ));
    expect((await svc.getFinanceTransactions()).single.toAmount, 90);
    await svc.close();
  });
}
