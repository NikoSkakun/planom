import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/finance/finance_controller.dart';
import 'package:planom/src/finance/finance_format.dart';
import 'package:planom/src/models/finance_budget.dart';
import 'package:planom/src/models/finance_category.dart';
import 'package:planom/src/models/finance_transaction.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late FinanceController controller;

  setUp(() async {
    db = freshDb();
    controller = FinanceController(db);
    await controller.load();
  });

  FinanceTransaction expense(int amount, DateTime date, {String? categoryId}) =>
      FinanceTransaction(
        title: 'Expense',
        amount: amount,
        type: FinanceEntryType.expense,
        categoryId: categoryId,
        date: date,
      );

  FinanceTransaction income(int amount, DateTime date) => FinanceTransaction(
        title: 'Income',
        amount: amount,
        type: FinanceEntryType.income,
        date: date,
      );

  group('seeding', () {
    test('an empty space gets the default categories', () {
      expect(controller.categories, isNotEmpty);
      expect(controller.categoriesOfType(FinanceEntryType.expense), isNotEmpty);
      expect(controller.categoriesOfType(FinanceEntryType.income), isNotEmpty);
    });

    test('does not re-seed when categories already exist', () async {
      final count = controller.categories.length;
      final fresh = FinanceController(db);
      await fresh.load();
      expect(fresh.categories.length, count);
    });

    test('does not re-seed a space whose categories were all deleted but '
        'still holds entries', () async {
      await controller.addTransaction(expense(500, today()));
      for (final c in controller.categories) {
        await controller.deleteCategory(c.id);
      }
      final fresh = FinanceController(db);
      await fresh.load();
      expect(fresh.categories, isEmpty);
    });
  });

  group('transactions', () {
    test('add / update / delete round-trip through the database', () async {
      final tx = expense(1250, today());
      await controller.addTransaction(tx);
      expect(controller.transactions.length, 1);

      await controller.updateTransaction(tx.copyWith(amount: 2000));
      expect(controller.transactionById(tx.id)?.amount, 2000);

      final reloaded = FinanceController(db);
      await reloaded.load();
      expect(reloaded.transactionById(tx.id)?.amount, 2000);

      await controller.deleteTransaction(tx.id);
      expect(controller.transactions, isEmpty);
      final afterDelete = FinanceController(db);
      await afterDelete.load();
      expect(afterDelete.transactions, isEmpty);
    });

    test('re-adding a deleted entry restores it verbatim (undo path)',
        () async {
      final tx = expense(999, today());
      await controller.addTransaction(tx);
      await controller.deleteTransaction(tx.id);
      await controller.addTransaction(tx);

      expect(controller.transactions.length, 1);
      expect(controller.transactionById(tx.id)?.amount, 999);
    });

    test('transactionsInRange excludes the upper bound', () async {
      final start = DateTime(2026, 3, 1);
      await controller.addTransaction(expense(100, DateTime(2026, 2, 28)));
      await controller.addTransaction(expense(200, start));
      await controller.addTransaction(expense(300, DateTime(2026, 3, 31)));
      await controller.addTransaction(expense(400, DateTime(2026, 4, 1)));

      final inMarch =
          controller.transactionsInRange(start, DateTime(2026, 4, 1));
      expect(inMarch.map((t) => t.amount).toSet(), {200, 300});
    });
  });

  group('summaries', () {
    test('summaryForMonth splits income from expenses', () async {
      final month = DateTime(2026, 5, 10);
      await controller.addTransaction(expense(1000, month));
      await controller.addTransaction(expense(250, DateTime(2026, 5, 20)));
      await controller.addTransaction(income(3000, DateTime(2026, 5, 2)));
      // Different month — must not leak in.
      await controller.addTransaction(expense(9999, DateTime(2026, 6, 1)));

      final summary = controller.summaryForMonth(month);
      expect(summary.expenses, 1250);
      expect(summary.income, 3000);
      expect(summary.balance, 1750);
    });

    test('spendByCategory groups expenses, biggest first, ignoring income',
        () async {
      final month = DateTime(2026, 7, 1);
      final food = controller.categories
          .firstWhere((c) => c.type == FinanceEntryType.expense);
      await controller.addTransaction(
          expense(500, month, categoryId: food.id));
      await controller.addTransaction(
          expense(700, month, categoryId: food.id));
      await controller.addTransaction(expense(300, month)); // uncategorized
      await controller.addTransaction(income(5000, month));

      final breakdown = controller.spendByCategoryForMonth(month);
      expect(breakdown.length, 2);
      expect(breakdown.first.categoryId, food.id);
      expect(breakdown.first.amount, 1200);
      expect(breakdown.first.count, 2);
      expect(breakdown.last.categoryId, isNull);
      expect(breakdown.last.amount, 300);
    });
  });

  group('budgets', () {
    test('setBudget creates, then replaces instead of duplicating', () async {
      await controller.setBudget(null, 50000);
      await controller.setBudget(null, 60000);
      expect(controller.budgets.length, 1);
      expect(controller.budgetFor(null)?.amount, 60000);
    });

    test('a non-positive amount clears the budget', () async {
      await controller.setBudget(null, 50000);
      await controller.setBudget(null, 0);
      expect(controller.budgets, isEmpty);
      expect(controller.budgetFor(null), isNull);
    });

    test('overall progress counts every expense; a category budget only its '
        'own', () async {
      final month = DateTime(2026, 8, 1);
      final categories =
          controller.categoriesOfType(FinanceEntryType.expense);
      final a = categories[0];
      final b = categories[1];
      await controller.addTransaction(expense(1000, month, categoryId: a.id));
      await controller.addTransaction(expense(400, month, categoryId: b.id));
      await controller.addTransaction(income(9999, month));

      await controller.setBudget(null, 2000);
      await controller.setBudget(a.id, 800);

      final overall = controller.budgetProgress(month).first;
      expect(overall.budget.isOverall, isTrue);
      expect(overall.spent, 1400);
      expect(overall.isOver, isFalse);
      expect(overall.remaining, 600);

      final forA = controller
          .budgetProgress(month)
          .firstWhere((p) => p.budget.categoryId == a.id);
      expect(forA.spent, 1000);
      expect(forA.isOver, isTrue);
      expect(forA.fraction, 1.0);
    });

    test('a weekly budget only counts the week containing the reference day',
        () async {
      // Wed 2026-08-12; its week runs Mon 10th … Sun 16th.
      final wednesday = DateTime(2026, 8, 12);
      await controller.addTransaction(expense(100, DateTime(2026, 8, 10)));
      await controller.addTransaction(expense(200, wednesday));
      await controller.addTransaction(expense(400, DateTime(2026, 8, 17)));

      await controller.setBudget(null, 1000, period: BudgetPeriod.weekly);
      final progress = controller.budgetProgress(wednesday).first;
      expect(progress.spent, 300);
    });
  });

  group('categories', () {
    test('deleting a category uncategorizes its entries and drops its budget',
        () async {
      final category = controller.categories.first;
      final tx = expense(700, today(), categoryId: category.id);
      await controller.addTransaction(tx);
      await controller.setBudget(category.id, 5000);

      await controller.deleteCategory(category.id);

      expect(controller.categoryById(category.id), isNull);
      expect(controller.transactionById(tx.id)?.categoryId, isNull);
      expect(controller.budgetFor(category.id), isNull);

      final reloaded = FinanceController(db);
      await reloaded.load();
      expect(reloaded.transactionById(tx.id)?.categoryId, isNull);
      expect(reloaded.budgets, isEmpty);
    });

    test('reorderCategories persists the new order of that type only',
        () async {
      final before = controller.categoriesOfType(FinanceEntryType.expense);
      final incomeBefore =
          controller.categoriesOfType(FinanceEntryType.income);
      final moved = before.first;

      await controller.reorderCategories(FinanceEntryType.expense, 0, 3);

      final reloaded = FinanceController(db);
      await reloaded.load();
      final after = reloaded.categoriesOfType(FinanceEntryType.expense);
      expect(after.length, before.length);
      expect(after[2].id, moved.id);
      expect(
        reloaded.categoriesOfType(FinanceEntryType.income).map((c) => c.id),
        incomeBefore.map((c) => c.id),
        reason: 'the other side of the ledger keeps its order',
      );
    });

    test('addCategory appends after the existing ones', () async {
      final count = controller.categories.length;
      final created = FinanceCategory(
        name: 'Travel',
        color: 0xFF007AFF,
        type: FinanceEntryType.expense,
      );
      await controller.addCategory(created);
      expect(controller.categories.length, count + 1);
      expect(controller.categoriesOfType(FinanceEntryType.expense).last.id,
          created.id);
    });
  });

  group('money formatting', () {
    setUp(() {
      FinanceCurrency.symbol = r'$';
      FinanceCurrency.showDecimals = true;
    });

    test('formats minor units with grouping and two decimals', () {
      expect(formatMoney(0), r'$0.00');
      expect(formatMoney(5), r'$0.05');
      expect(formatMoney(123456789), r'$1,234,567.89');
    });

    test('signed amounts carry an explicit direction', () {
      expect(formatMoney(-1250, signed: true), '−\$12.50');
      expect(formatMoney(1250, signed: true), r'+$12.50');
    });

    test('decimals can be suppressed, rounding to whole units', () {
      FinanceCurrency.showDecimals = false;
      expect(formatMoney(1250), r'$13');
      expect(formatMoney(1240), r'$12');
    });

    test('parses the decimal separators and grouping users actually type', () {
      expect(parseAmountToCents('12'), 1200);
      expect(parseAmountToCents('12.5'), 1250);
      expect(parseAmountToCents('12,50'), 1250);
      expect(parseAmountToCents('1 234.56'), 123456);
      expect(parseAmountToCents('1,234.56'), 123456);
      expect(parseAmountToCents(''), isNull);
      expect(parseAmountToCents('abc'), isNull);
    });

    test('negative input is treated as a magnitude — direction lives on the '
        'entry type', () {
      expect(parseAmountToCents('-5'), 500);
    });
  });
}
