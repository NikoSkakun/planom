import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/finance/finance_controller.dart';
import 'package:planom/src/finance/finance_format.dart';
import 'package:planom/src/finance/finance_view.dart';
import 'package:planom/src/localization/app_localizations.dart';
import 'package:planom/src/models/finance_category.dart';
import 'package:planom/src/models/finance_transaction.dart';
import 'package:planom/src/utils/undo_controller.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late FinanceController controller;

  setUp(() async {
    db = freshDb();
    controller = FinanceController(db);
    await controller.load();
    FinanceCurrency.symbol = r'$';
    FinanceCurrency.showDecimals = true;
  });

  // Lets the real (ffi) DB futures settle — the fake test clock never advances
  // them on its own.
  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      await tester.pump();
    }
  }

  Widget host(FinanceController controller) => CupertinoApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: UndoScope(
          controller: UndoController(),
          child: FinanceView(controller: controller),
        ),
      );

  testWidgets('an empty month renders the empty state', (tester) async {
    await tester.pumpWidget(host(controller));
    await drain(tester);

    expect(find.text('Nothing recorded this month'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
  });

  testWidgets('entries in the current month feed the summary and the list',
      (tester) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final category = controller.categories
        .firstWhere((c) => c.type == FinanceEntryType.expense);

    await tester.runAsync(() async {
      await controller.addTransaction(FinanceTransaction(
        title: 'Coffee',
        amount: 450,
        categoryId: category.id,
        date: day,
      ));
      await controller.addTransaction(FinanceTransaction(
        title: 'Paycheck',
        amount: 250000,
        type: FinanceEntryType.income,
        date: day,
      ));
    });

    await tester.pumpWidget(host(controller));
    await drain(tester);

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Paycheck'), findsOneWidget);
    // Summary card: spent / income / balance.
    expect(find.text(r'$4.50'), findsWidgets);
    expect(find.text(r'$2,500.00'), findsWidgets);
    // Balance in the summary card; the day header repeats it because both
    // entries land on the same day.
    expect(find.text(r'+$2,495.50'), findsWidgets);
    // Signed row amounts.
    expect(find.text(r'−$4.50'), findsOneWidget);
    // Breakdown section lists the category the expense was filed under.
    expect(find.text(category.name), findsWidgets);
  });

  testWidgets('the month navigator moves off the current month', (tester) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 15);

    await tester.runAsync(() async {
      await controller.addTransaction(FinanceTransaction(
        title: 'Old rent',
        amount: 100000,
        date: lastMonth,
      ));
    });

    await tester.pumpWidget(host(controller));
    await drain(tester);
    // Last month's entry isn't in the current month's list.
    expect(find.text('Old rent'), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
    await drain(tester);
    expect(find.text('Old rent'), findsOneWidget);
  });
}
