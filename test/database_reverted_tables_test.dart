import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/models/finance_category.dart';
import 'package:planom/src/models/goal.dart';

import 'support/test_db.dart';

/// A Goals/Finance build shipped once and was reverted before release. Its
/// tables use the same names as today's with different columns, and every
/// `CREATE TABLE` in the schema is `IF NOT EXISTS` — so on a device that ran
/// that build the current schema was never applied and the app read columns
/// that do not exist. `goals.name` came back null, the cast to String threw
/// while the space was loading, and nothing was ever drawn: a white screen.
///
/// These are the reverted build's definitions, verbatim from commit 6745e0e.
const _legacyGoals = '''
  CREATE TABLE IF NOT EXISTS goals (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    note TEXT,
    iconId TEXT NOT NULL DEFAULT 'flag',
    colorValue INTEGER NOT NULL DEFAULT 0,
    type TEXT NOT NULL DEFAULT 'milestone',
    targetAmount INTEGER,
    currentAmount INTEGER NOT NULL DEFAULT 0,
    unit TEXT,
    startDate INTEGER NOT NULL,
    targetDate INTEGER,
    isCompleted INTEGER NOT NULL DEFAULT 0,
    completionDate INTEGER,
    isArchived INTEGER NOT NULL DEFAULT 0,
    sortOrder INTEGER NOT NULL DEFAULT 0,
    creationDate INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL DEFAULT 0
  )
''';

const _legacyCategories = '''
  CREATE TABLE IF NOT EXISTS finance_categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'expense',
    iconId TEXT NOT NULL DEFAULT 'tag',
    colorValue INTEGER NOT NULL DEFAULT 0,
    sortOrder INTEGER NOT NULL DEFAULT 0,
    creationDate INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL DEFAULT 0
  )
''';

const _legacyAccounts = '''
  CREATE TABLE IF NOT EXISTS finance_accounts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    iconId TEXT NOT NULL DEFAULT 'wallet',
    colorValue INTEGER NOT NULL DEFAULT 0,
    type TEXT NOT NULL DEFAULT 'cash',
    openingBalance INTEGER NOT NULL DEFAULT 0,
    currencyCode TEXT NOT NULL DEFAULT 'USD',
    isArchived INTEGER NOT NULL DEFAULT 0,
    sortOrder INTEGER NOT NULL DEFAULT 0,
    creationDate INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL DEFAULT 0
  )
''';

void main() {
  initTestDatabaseFactory();

  /// A database as the reverted build left it: at v38 (so the v39 branch is
  /// the one under test) with all three tables in their old shape.
  Future<String> seedRevertedDatabase() async {
    final name = 'reverted_${DateTime.now().microsecondsSinceEpoch}.db';
    final dir = await databaseFactory.getDatabasesPath();
    final db = await databaseFactory.openDatabase(
      p.join(dir, name),
      options: OpenDatabaseOptions(
        version: 38,
        onCreate: (db, _) async {
          await db.execute(_legacyGoals);
          await db.execute(_legacyCategories);
          await db.execute(_legacyAccounts);
        },
      ),
    );
    final now = DateTime(2026, 7, 1).millisecondsSinceEpoch;
    await db.insert('goals', {
      'id': 'g1',
      'title': 'Run a marathon',
      'note': 'before winter',
      'iconId': 'flame',
      'colorValue': 0xFF34C759,
      'type': 'amount',
      'currentAmount': 12,
      'startDate': now,
      'sortOrder': 3,
      'creationDate': now,
    });
    await db.insert('finance_categories', {
      'id': 'c1',
      'name': 'Salary',
      'kind': 'income',
      'iconId': 'wallet',
      'colorValue': 0xFF30B0C7,
      'sortOrder': 1,
      'creationDate': now,
    });
    await db.insert('finance_accounts', {
      'id': 'a1',
      'name': 'Revolut',
      'iconId': 'creditcard',
      'colorValue': 0xFFAF52DE,
      'type': 'card',
      'openingBalance': 25000,
      'currencyCode': 'EUR',
      'sortOrder': 2,
      'creationDate': now,
    });
    await db.close();
    return name;
  }

  test('a database from the reverted build opens and reads back', () async {
    final svc = DatabaseService(dbName: await seedRevertedDatabase());

    // Reading goals at all is the regression: this threw
    // "type 'Null' is not a subtype of type 'String' in type cast".
    final goals = await svc.getGoals();
    expect(goals.length, 1);
    expect(goals.single.name, 'Run a marathon');
    expect(goals.single.description, 'before winter');
    expect(goals.single.iconId, 'flame');
    expect(goals.single.color, 0xFF34C759);
    expect(goals.single.sortOrder, 3);
    // The reverted feature tracked an amount, not a set of tasks, so there is
    // nothing to carry into `sources`.
    expect(goals.single.sources, isEmpty);

    await svc.close();
  });

  test('finance rows keep their type, colour and balance', () async {
    final svc = DatabaseService(dbName: await seedRevertedDatabase());

    final categories = await svc.getFinanceCategories();
    expect(categories.single.name, 'Salary');
    // `kind` → `type`: without the rebuild every category read back as an
    // expense, silently turning income into spending.
    expect(categories.single.type, FinanceEntryType.income);
    expect(categories.single.color, 0xFF30B0C7);

    final accounts = await svc.getFinanceAccounts();
    expect(accounts.single.name, 'Revolut');
    expect(accounts.single.currencyCode, 'EUR');
    // `openingBalance` → `initialBalance`, which otherwise read back as zero.
    expect(accounts.single.initialBalance, 25000);
    expect(accounts.single.color, 0xFFAF52DE);

    await svc.close();
  });

  test('the rebuilt tables accept new rows', () async {
    // The old `goals.title` is NOT NULL with no default, so an insert that
    // does not mention it fails until the table is actually rebuilt.
    final svc = DatabaseService(dbName: await seedRevertedDatabase());
    await svc.insertGoal(Goal(name: 'Ship v2'));
    expect((await svc.getGoals()).map((g) => g.name), contains('Ship v2'));
    await svc.close();
  });

  test('re-opening a repaired database leaves it alone', () async {
    final name = await seedRevertedDatabase();
    final first = DatabaseService(dbName: name);
    expect((await first.getGoals()).single.name, 'Run a marathon');
    await first.close();

    final second = DatabaseService(dbName: name);
    expect((await second.getGoals()).single.name, 'Run a marathon');
    await second.close();
  });

  test('a database that never saw the reverted build is untouched', () async {
    final fresh = freshDb();
    await fresh.insertGoal(Goal(name: 'Fresh', sortOrder: 1));
    expect((await fresh.getGoals()).single.name, 'Fresh');
    expect(await fresh.getFinanceAccounts(), isEmpty);
  });
}
