import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/finance/finance_controller.dart';
import 'package:planom/src/finance/finance_format.dart';
import 'package:planom/src/models/finance_account.dart';
import 'package:planom/src/models/finance_category.dart';
import 'package:planom/src/models/finance_transaction.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late FinanceController controller;

  setUp(() async {
    FinanceCurrency.code = 'USD';
    FinanceCurrency.symbol = r'$';
    FinanceCurrency.showDecimals = true;
    db = freshDb();
    controller = FinanceController(db);
    await controller.load();
  });

  Future<FinanceAccount> addAccount(
    String name, {
    String currency = 'USD',
    int initial = 0,
  }) async {
    final account = FinanceAccount(
      name: name,
      currencyCode: currency,
      initialBalance: initial,
    );
    await controller.addAccount(account);
    return account;
  }

  FinanceTransaction expense(int amount, {String? accountId, DateTime? date}) =>
      FinanceTransaction(
        title: 'Expense',
        amount: amount,
        type: FinanceEntryType.expense,
        accountId: accountId,
        date: date ?? today(),
      );

  FinanceTransaction income(int amount, {String? accountId, DateTime? date}) =>
      FinanceTransaction(
        title: 'Income',
        amount: amount,
        type: FinanceEntryType.income,
        accountId: accountId,
        date: date ?? today(),
      );

  FinanceTransaction transfer(
    int amount, {
    required String from,
    required String to,
    int? toAmount,
    DateTime? date,
  }) =>
      FinanceTransaction(
        title: 'Transfer',
        amount: amount,
        type: FinanceEntryType.transfer,
        accountId: from,
        toAccountId: to,
        toAmount: toAmount,
        date: date ?? today(),
      );

  group('seeding', () {
    test('an untouched space gets one starter account', () {
      expect(controller.accounts.length, 1);
      expect(controller.accounts.single.currencyCode, 'USD');
    });

    test('does not re-seed once entries exist', () async {
      final account = controller.accounts.single;
      await controller.addTransaction(expense(100, accountId: account.id));
      await controller.deleteAccount(account.id);

      final reloaded = FinanceController(db);
      await reloaded.load();
      expect(reloaded.accounts, isEmpty);
    });
  });

  group('balances', () {
    test('opening balance plus income minus expenses', () async {
      final account = await addAccount('Card', initial: 10000);
      await controller.addTransaction(income(2500, accountId: account.id));
      await controller.addTransaction(expense(700, accountId: account.id));

      expect(controller.balanceOf(controller.accountById(account.id)!), 11800);
    });

    test('a transfer moves value between the two accounts', () async {
      final from = await addAccount('Cash', initial: 5000);
      final to = await addAccount('Bank', initial: 0);
      await controller
          .addTransaction(transfer(2000, from: from.id, to: to.id));

      expect(controller.balanceOf(controller.accountById(from.id)!), 3000);
      expect(controller.balanceOf(controller.accountById(to.id)!), 2000);
    });

    test('a cross-currency transfer credits the destination leg', () async {
      final from = await addAccount('USD wallet', currency: 'USD', initial: 50000);
      final to = await addAccount('EUR wallet', currency: 'EUR', initial: 0);
      // $100 out, €92 in — the app stores both legs because it holds no rates.
      await controller.addTransaction(
          transfer(10000, from: from.id, to: to.id, toAmount: 9200));

      expect(controller.balanceOf(controller.accountById(from.id)!), 40000);
      expect(controller.balanceOf(controller.accountById(to.id)!), 9200);
    });

    test('totals are grouped per currency, never summed across them', () async {
      await addAccount('USD wallet', currency: 'USD', initial: 10000);
      await addAccount('EUR wallet', currency: 'EUR', initial: 5000);

      final totals = controller.totalsByCurrency();
      // Includes the seeded USD starter account (balance 0).
      expect(totals['USD'], 10000);
      expect(totals['EUR'], 5000);
    });
  });

  group('summaries', () {
    test('transfers are neither income nor expense', () async {
      final from = await addAccount('Cash');
      final to = await addAccount('Bank');
      await controller.addTransaction(expense(300, accountId: from.id));
      await controller.addTransaction(income(900, accountId: from.id));
      await controller.addTransaction(transfer(500, from: from.id, to: to.id));

      final summary = controller.summaryForMonth(today());
      expect(summary.expenses, 300);
      expect(summary.income, 900);
      expect(summary.balance, 600);
    });

    test('scoping to an account covers both legs of a transfer', () async {
      final from = await addAccount('Cash');
      final to = await addAccount('Bank');
      await controller.addTransaction(expense(300, accountId: from.id));
      await controller.addTransaction(transfer(500, from: from.id, to: to.id));

      expect(
        controller.transactionsForMonth(today(), accountId: to.id).length,
        1,
        reason: 'the receiving account sees the transfer',
      );
      expect(
        controller.transactionsForMonth(today(), accountId: from.id).length,
        2,
      );
      expect(
        controller.summaryForMonth(today(), accountId: to.id).expenses,
        0,
        reason: 'a transfer in is not spending',
      );
    });

    test('currency scoping keeps other currencies out of the figures',
        () async {
      final usd = await addAccount('USD wallet', currency: 'USD');
      final eur = await addAccount('EUR wallet', currency: 'EUR');
      await controller.addTransaction(expense(1000, accountId: usd.id));
      await controller.addTransaction(expense(2000, accountId: eur.id));

      expect(
        controller.summaryForMonth(today(), currency: 'USD').expenses,
        1000,
      );
      expect(
        controller.summaryForMonth(today(), currency: 'EUR').expenses,
        2000,
      );
    });

    test('budgets only count the currency they are denominated in', () async {
      final usd = await addAccount('USD wallet', currency: 'USD');
      final eur = await addAccount('EUR wallet', currency: 'EUR');
      await controller.addTransaction(expense(1000, accountId: usd.id));
      await controller.addTransaction(expense(5000, accountId: eur.id));
      await controller.setBudget(null, 4000);

      final progress = controller.budgetProgress(today()).single;
      expect(progress.spent, 1000, reason: 'the EUR entry is not converted');
      expect(progress.isOver, isFalse);
    });

    test('entries without an account count in the space default currency',
        () async {
      await controller.addTransaction(expense(750));
      expect(controller.currencyOf(controller.transactions.single), 'USD');
      expect(
        controller.summaryForMonth(today(), currency: 'USD').expenses,
        750,
      );
    });
  });

  group('account lifecycle', () {
    test('deleting an account detaches its entries but keeps them', () async {
      final from = await addAccount('Cash');
      final to = await addAccount('Bank');
      final spend = expense(400, accountId: from.id);
      final move = transfer(600, from: from.id, to: to.id);
      await controller.addTransaction(spend);
      await controller.addTransaction(move);

      await controller.deleteAccount(from.id);

      expect(controller.accountById(from.id), isNull);
      expect(controller.transactions.length, 2);
      expect(controller.transactionById(spend.id)?.accountId, isNull);
      expect(controller.transactionById(move.id)?.accountId, isNull);
      expect(controller.transactionById(move.id)?.toAccountId, to.id);

      final reloaded = FinanceController(db);
      await reloaded.load();
      expect(reloaded.transactionById(spend.id)?.accountId, isNull);
    });

    test('archiving hides an account from pickers but keeps its history',
        () async {
      final account = await addAccount('Old card');
      await controller.addTransaction(expense(100, accountId: account.id));
      await controller.setAccountArchived(account.id, true);

      expect(controller.activeAccounts.any((a) => a.id == account.id), isFalse);
      expect(controller.accounts.any((a) => a.id == account.id), isTrue);
      expect(controller.transactions.length, 1);
    });

    test('reorderAccounts renumbers and persists', () async {
      final a = await addAccount('A');
      await addAccount('B');
      // Index 0 is the seeded starter account.
      final before = controller.accounts.map((x) => x.name).toList();
      await controller.reorderAccounts(before.indexOf('A'), 0);

      final reloaded = FinanceController(db);
      await reloaded.load();
      expect(reloaded.accounts.first.id, a.id);
    });
  });

  group('currency formatting', () {
    test('renders each account currency with its own symbol', () {
      expect(formatMoney(123456, currencyCode: 'EUR'), '€1,234.56');
      expect(formatMoney(123456, currencyCode: 'GBP'), '£1,234.56');
    });

    test('a zero-decimal currency never shows cents', () {
      expect(formatMoney(123400, currencyCode: 'JPY'), '¥1,234');
    });

    test('an unknown code falls back to the code itself', () {
      expect(formatMoney(100, currencyCode: 'XYZ'), 'XYZ1.00');
    });
  });
}
