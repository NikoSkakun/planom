import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/finance/finance_controller.dart';
import 'package:planom/src/finance/money.dart';
import 'package:planom/src/models/budget.dart';
import 'package:planom/src/models/finance_account.dart';
import 'package:planom/src/models/finance_category.dart';
import 'package:planom/src/models/finance_transaction.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  test('seeds default categories on first load', () async {
    final db = freshDb();
    final c = FinanceController(db);
    await c.load();
    expect(c.categories, isNotEmpty);
    expect(c.incomeCategories, isNotEmpty);
    expect(c.expenseCategories, isNotEmpty);
  });

  test('balance reflects income, expense and transfers', () async {
    final db = freshDb();
    final c = FinanceController(db);
    await c.load();

    final checking = FinanceAccount(
        name: 'Checking', currencyCode: 'USD', openingBalance: 10000);
    final savings = FinanceAccount(
        name: 'Savings', currencyCode: 'USD', openingBalance: 0);
    await c.addAccount(checking);
    await c.addAccount(savings);

    await c.addTransaction(FinanceTransaction(
        type: FinanceTransaction.typeIncome,
        amount: 5000,
        accountId: checking.id,
        date: DateTime.now()));
    await c.addTransaction(FinanceTransaction(
        type: FinanceTransaction.typeExpense,
        amount: 2000,
        accountId: checking.id,
        date: DateTime.now()));
    await c.addTransaction(FinanceTransaction(
        type: FinanceTransaction.typeTransfer,
        amount: 3000,
        accountId: checking.id,
        toAccountId: savings.id,
        date: DateTime.now()));

    // 10000 + 5000 - 2000 - 3000 = 10000
    expect(c.balanceOf(checking.id), 10000);
    // 0 + 3000 = 3000
    expect(c.balanceOf(savings.id), 3000);
    expect(c.netWorthByCurrency()['USD'], 13000);
  });

  test('monthly totals and budget spend exclude transfers', () async {
    final db = freshDb();
    final c = FinanceController(db);
    await c.load();
    final acc = FinanceAccount(name: 'Cash', currencyCode: 'USD');
    await c.addAccount(acc);
    final groceries = FinanceCategory(name: 'Groceries', kind: 'expense');
    await c.addCategory(groceries);

    final now = DateTime.now();
    await c.addTransaction(FinanceTransaction(
        type: FinanceTransaction.typeIncome,
        amount: 100000,
        accountId: acc.id,
        date: now));
    await c.addTransaction(FinanceTransaction(
        type: FinanceTransaction.typeExpense,
        amount: 4000,
        accountId: acc.id,
        categoryId: groceries.id,
        date: now));

    expect(c.periodIncome('USD', Budget.periodMonthly), 100000);
    expect(c.periodExpense('USD', Budget.periodMonthly), 4000);

    final budget = Budget(
        name: 'Food',
        categoryId: groceries.id,
        amount: 10000,
        period: Budget.periodMonthly,
        currencyCode: 'USD');
    await c.addBudget(budget);
    expect(c.spentForBudget(budget), 4000);
  });

  test('persists across reloads', () async {
    final db = freshDb();
    final c = FinanceController(db);
    await c.load();
    final acc = FinanceAccount(name: 'Wallet', currencyCode: 'EUR');
    await c.addAccount(acc);
    await c.addTransaction(FinanceTransaction(
        type: FinanceTransaction.typeExpense,
        amount: 999,
        accountId: acc.id,
        date: DateTime.now()));

    final c2 = FinanceController(db);
    await c2.load();
    expect(c2.accounts.any((a) => a.name == 'Wallet'), isTrue);
    expect(c2.balanceOf(acc.id), -999);
  });

  test('deleting an account removes its transactions', () async {
    final db = freshDb();
    final c = FinanceController(db);
    await c.load();
    final acc = FinanceAccount(name: 'Temp', currencyCode: 'USD');
    await c.addAccount(acc);
    await c.addTransaction(FinanceTransaction(
        type: FinanceTransaction.typeExpense,
        amount: 100,
        accountId: acc.id,
        date: DateTime.now()));
    await c.deleteAccount(acc.id);
    expect(c.accounts, isEmpty);
    expect(c.transactions, isEmpty);
  });

  test('money parsing and formatting round-trips', () {
    final usd = Currencies.byCode('USD');
    expect(usd.parse('12.50'), 1250);
    expect(usd.parse('1,234.56'), 123456);
    expect(usd.format(123456), r'$1,234.56');
    final jpy = Currencies.byCode('JPY');
    expect(jpy.parse('1500'), 1500);
    expect(jpy.format(1500), '¥1,500');
  });
}
