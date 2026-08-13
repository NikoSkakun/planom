import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/finance/finance_accounts_view.dart';
import 'package:planom/src/finance/finance_controller.dart';
import 'package:planom/src/localization/app_localizations.dart';
import 'package:planom/src/models/finance_account.dart';

import 'support/test_db.dart';

/// Deleting an account from the Accounts screen: swipe the row, confirm, gone.
void main() {
  initTestDatabaseFactory();

  /// Real sqflite work only progresses inside [WidgetTester.runAsync] — the
  /// fake async zone a widget test runs in never completes it otherwise.
  Future<FinanceController> seed(WidgetTester tester) async {
    late FinanceController controller;
    await tester.runAsync(() async {
      controller = FinanceController(freshDb());
      await controller.load();
      // load() seeds a Cash account into an untouched space; clear the slate
      // so the test drives exactly one known account.
      for (final existing in [...controller.accounts]) {
        await controller.deleteAccount(existing.id);
      }
      await controller
          .addAccount(FinanceAccount(name: 'Revolut', currencyCode: 'USD'));
    });
    return controller;
  }

  /// Alternates fake time and real time. Animations only advance under
  /// [WidgetTester.pump], and the database work these screens do only advances
  /// inside [WidgetTester.runAsync] — a dismiss that ends by writing to the
  /// database needs both, in turn.
  Future<void> settle(WidgetTester tester, {int rounds = 16}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  Future<void> tapAndFlush(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  Widget host(FinanceController controller) => CupertinoApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: FinanceAccountsView(controller: controller),
      );

  testWidgets('swiping a row and confirming deletes the account',
      (tester) async {
    final controller = await seed(tester);
    expect(controller.accounts.length, 1);

    await tester.pumpWidget(host(controller));
    await settle(tester);
    expect(find.text('Revolut'), findsOneWidget);

    await tester.drag(find.text('Revolut'), const Offset(-500, 0));
    await settle(tester);
    await tapAndFlush(tester, find.text('Delete').last);
    await settle(tester);

    expect(controller.accounts, isEmpty, reason: 'the account is gone');
    expect(find.text('Revolut'), findsNothing, reason: 'and so is its row');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling leaves the account alone', (tester) async {
    final controller = await seed(tester);

    await tester.pumpWidget(host(controller));
    await settle(tester);

    await tester.drag(find.text('Revolut'), const Offset(-500, 0));
    await settle(tester);
    await tapAndFlush(tester, find.text('Cancel'));
    await settle(tester);

    expect(controller.accounts.length, 1);
    // The row must come back rather than staying swiped off behind the red
    // background, which is what the user sees when the dismiss gets stuck.
    expect(find.text('Revolut'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting through the long-press menu also works',
      (tester) async {
    final controller = await seed(tester);

    await tester.pumpWidget(host(controller));
    await settle(tester);

    await tester.longPress(find.text('Revolut'));
    await settle(tester);
    await tapAndFlush(tester, find.text('Delete').first);
    await tapAndFlush(tester, find.text('Delete').last);

    expect(controller.accounts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a delete that fails puts the row back', (tester) async {
    // The row leaves the tree the moment the swipe completes, so a failing
    // delete would otherwise leave an account that is off the screen but still
    // in the ledger — exactly the state a stuck swipe used to leave behind.
    final controller = await seed(tester);
    late _FailingDeleteController failing;
    await tester.runAsync(() async {
      failing = _FailingDeleteController(controller, freshDb());
    });

    await tester.pumpWidget(host(failing));
    await settle(tester);

    await tester.drag(find.text('Revolut'), const Offset(-500, 0));
    await settle(tester);
    await tapAndFlush(tester, find.text('Delete').last);

    expect(failing.accounts.length, 1, reason: 'nothing was deleted');
    expect(find.text('Revolut'), findsOneWidget,
        reason: 'and the row springs back instead of vanishing');
    expect(tester.takeException(), isNull,
        reason: 'a refused delete is handled, not thrown at the framework');
  });
}

/// Stands in for a controller whose delete cannot complete — a database
/// constraint, a locked file. Everything else is the real controller.
class _FailingDeleteController extends FinanceController {
  _FailingDeleteController(this._inner, super.db);

  final FinanceController _inner;

  @override
  Future<void> deleteAccount(String id) async =>
      throw StateError('delete refused');

  @override
  List<FinanceAccount> get accounts => _inner.accounts;

  @override
  List<FinanceAccount> get activeAccounts => _inner.activeAccounts;

  @override
  Map<String, int> totalsByCurrency() => _inner.totalsByCurrency();

  @override
  int balanceOf(FinanceAccount account) => _inner.balanceOf(account);
}
