import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/budget.dart';
import '../models/finance_account.dart';
import '../models/finance_transaction.dart';
import '../settings/settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import '../utils/simple_date_picker.dart';
import 'account_editor.dart';
import 'budget_editor.dart';
import 'category_manager.dart';
import 'finance_controller.dart';
import 'finance_icons.dart';
import 'money.dart';
import 'transaction_editor.dart';

/// Tab root for the Finance mode. Three segments — Overview, Transactions and
/// Budgets — backed by [FinanceController].
class FinanceView extends StatefulWidget {
  const FinanceView({
    super.key,
    required this.controller,
    required this.settingsController,
  });

  final FinanceController controller;
  final SettingsController settingsController;

  @override
  State<FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<FinanceView> {
  int _segment = 0;

  FinanceController get _c => widget.controller;

  Future<void> _openMenu() async {
    final s = S.of(context);
    final choice = await showSelectionMenu<String>(
      context: context,
      anchor: SelectionMenuAnchor.topRight,
      options: [
        SelectionMenuOption(
            value: 'account',
            label: s.financeAddAccount,
            icon: CupertinoIcons.creditcard),
        SelectionMenuOption(
            value: 'budget',
            label: s.financeAddBudget,
            icon: CupertinoIcons.chart_pie),
        SelectionMenuOption(
            value: 'categories',
            label: s.financeManageCategories,
            icon: CupertinoIcons.tag),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'account':
        showAccountEditor(context, _c,
            defaultCurrency: _localeCurrency());
      case 'budget':
        showBudgetEditor(context, _c);
      case 'categories':
        showCategoryManager(context, _c);
    }
  }

  String _localeCurrency() {
    final code = widget.settingsController.locale.languageCode;
    return _c.defaultCurrency == 'USD'
        ? Currencies.defaultForLanguage(code)
        : _c.defaultCurrency;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(s.tabFinance),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: _openMenu,
          child: const Icon(CupertinoIcons.ellipsis_circle),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            if (_c.accounts.isEmpty) return _emptyState(s);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _segment,
                    onValueChanged: (v) {
                      if (v != null) setState(() => _segment = v);
                    },
                    children: {
                      0: Text(s.financeOverview),
                      1: Text(s.financeTransactions),
                      2: Text(s.financeBudgets),
                    },
                  ),
                ),
                Expanded(
                  child: switch (_segment) {
                    1 => _TransactionsList(controller: _c),
                    2 => _BudgetsList(controller: _c),
                    _ => _Overview(controller: _c, localeCurrency: _localeCurrency()),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState(S s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.money_dollar_circle,
                size: 64, color: CupertinoColors.systemGrey.resolveFrom(context)),
            const SizedBox(height: 16),
            Text(s.financeEmptyTitle,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(s.financeEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context))),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () => showAccountEditor(context, _c,
                  defaultCurrency: _localeCurrency()),
              child: Text(s.financeAddAccount),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overview ─────────────────────────────────────────────────────────────────

class _Overview extends StatelessWidget {
  const _Overview({required this.controller, required this.localeCurrency});
  final FinanceController controller;
  final String localeCurrency;

  String _money(int minor, String code, {bool showSign = false}) =>
      Currencies.byCode(code).format(minor, showSign: showSign);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final netWorth = controller.netWorthByCurrency();
    final primary = controller.currenciesInUse.first;
    final income = controller.periodIncome(primary, Budget.periodMonthly);
    final expense = controller.periodExpense(primary, Budget.periodMonthly);
    final spending = controller.categorySpending(
        primary, Budget.periodMonthly, DateTime.now());
    final topCats = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = topCats.isEmpty ? 1 : topCats.first.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        // Net worth card.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accent, AppColors.accent.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.financeNetWorth,
                  style: const TextStyle(
                      color: CupertinoColors.white, fontSize: 14)),
              const SizedBox(height: 8),
              for (final entry in netWorth.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(_money(entry.value, entry.key),
                      style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // This month income / expense.
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: s.financeThisMonthIncome,
                value: _money(income, primary),
                color: const Color(0xFF34C759),
                icon: CupertinoIcons.arrow_down_left,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: s.financeThisMonthExpense,
                value: _money(expense, primary),
                color: const Color(0xFFFF3B30),
                icon: CupertinoIcons.arrow_up_right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: s.financeAccounts,
          action: s.financeAddAccount,
          onAction: () => showAccountEditor(context, controller,
              defaultCurrency: localeCurrency),
        ),
        for (final acc in controller.activeAccounts)
          _AccountRow(controller: controller, account: acc),
        if (topCats.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeader(title: s.financeTopSpending),
          for (final entry in topCats.take(5))
            _CategoryBar(
              controller: controller,
              categoryId: entry.key,
              amount: entry.value,
              fraction: entry.value / maxCat,
              currency: primary,
            ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.controller, required this.account});
  final FinanceController controller;
  final FinanceAccount account;

  @override
  Widget build(BuildContext context) {
    final balance = controller.balanceOf(account.id);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 6),
      onPressed: () => Navigator.of(context).push(FastRoute<void>(
        builder: (_) =>
            AccountDetailView(controller: controller, accountId: account.id),
      )),
      child: Row(
        children: [
          FinanceCircleIcon(
              iconId: account.iconId, colorValue: account.colorValue, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name,
                    style: TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.label.resolveFrom(context))),
                Text(account.currencyCode,
                    style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context))),
              ],
            ),
          ),
          Text(
            Currencies.byCode(account.currencyCode).format(balance),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: balance < 0
                    ? const Color(0xFFFF3B30)
                    : CupertinoColors.label.resolveFrom(context)),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.controller,
    required this.categoryId,
    required this.amount,
    required this.fraction,
    required this.currency,
  });
  final FinanceController controller;
  final String categoryId;
  final int amount;
  final double fraction;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cat = controller.categoryById(categoryId);
    final color = cat != null
        ? Color(cat.colorValue)
        : CupertinoColors.systemGrey.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          FinanceCircleIcon(
              iconId: cat?.iconId ?? 'tag',
              colorValue: cat?.colorValue ?? 0xFF8E8E93,
              size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(cat?.name ?? s.financeUncategorized,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    Text(Currencies.byCode(currency).format(amount),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressBar(
                      fraction: fraction.clamp(0.0, 1.0), color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin horizontal progress bar.
class LinearProgressBar extends StatelessWidget {
  const LinearProgressBar(
      {super.key, required this.fraction, required this.color, this.height = 6});
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: CupertinoColors.systemGrey5.resolveFrom(context),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.isNaN ? 0 : fraction.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context))),
          ),
          if (action != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: onAction,
              child: Text(action!,
                  style: TextStyle(fontSize: 14, color: AppColors.accent)),
            ),
        ],
      ),
    );
  }
}

// ── Transactions list ────────────────────────────────────────────────────────

class _TransactionsList extends StatelessWidget {
  const _TransactionsList({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final txns = controller.allTransactionsSorted();
    if (txns.isEmpty) {
      return Center(
        child: Text(s.financeNoTransactions,
            style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context))),
      );
    }
    // Group by day.
    final groups = <String, List<FinanceTransaction>>{};
    for (final t in txns) {
      final key = formatShortDate(DateTime(t.date.year, t.date.month, t.date.day));
      groups.putIfAbsent(key, () => []).add(t);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
            child: Text(entry.key,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context))),
          ),
          for (final t in entry.value)
            TransactionRow(controller: controller, transaction: t),
        ],
      ],
    );
  }
}

/// A single transaction row, reused by the list and account detail views.
class TransactionRow extends StatelessWidget {
  const TransactionRow(
      {super.key, required this.controller, required this.transaction});
  final FinanceController controller;
  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = transaction;
    final account = controller.accountById(t.accountId);
    final currency = account?.currencyCode ?? controller.defaultCurrency;
    final cat = controller.categoryById(t.categoryId);
    final (icon, color, subtitle, sign) = switch (t.type) {
      FinanceTransaction.typeIncome => (
          cat?.iconId ?? 'money',
          cat?.colorValue ?? 0xFF34C759,
          account?.name ?? '',
          1,
        ),
      FinanceTransaction.typeTransfer => (
          'card',
          0xFF007AFF,
          '${account?.name ?? ''} → ${controller.accountById(t.toAccountId)?.name ?? ''}',
          0,
        ),
      _ => (
          cat?.iconId ?? 'tag',
          cat?.colorValue ?? 0xFFFF3B30,
          cat?.name ?? account?.name ?? '',
          -1,
        ),
    };
    final title = t.title.isNotEmpty
        ? t.title
        : (t.isTransfer
            ? s.financeTransfer
            : (cat?.name ?? s.financeUncategorized));
    final amountColor = switch (sign) {
      1 => const Color(0xFF34C759),
      -1 => const Color(0xFFFF3B30),
      _ => CupertinoColors.label.resolveFrom(context),
    };
    final amountText = Currencies.byCode(currency)
        .format(t.amount, showSign: sign == 1);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onPressed: () =>
          showTransactionEditor(context, controller, existing: t),
      child: Row(
        children: [
          FinanceCircleIcon(iconId: icon, colorValue: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.label.resolveFrom(context))),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context))),
              ],
            ),
          ),
          Text(
            sign == -1 ? '-$amountText' : amountText,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: amountColor),
          ),
        ],
      ),
    );
  }
}

// ── Budgets list ─────────────────────────────────────────────────────────────

class _BudgetsList extends StatelessWidget {
  const _BudgetsList({required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final budgets = controller.budgets;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        if (budgets.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              children: [
                Icon(CupertinoIcons.chart_pie,
                    size: 48,
                    color: CupertinoColors.systemGrey.resolveFrom(context)),
                const SizedBox(height: 12),
                Text(s.financeNoBudgets,
                    style: TextStyle(
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context))),
              ],
            ),
          ),
        for (final b in budgets)
          _BudgetCard(controller: controller, budget: b),
        const SizedBox(height: 12),
        CupertinoButton(
          onPressed: () => showBudgetEditor(context, controller),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.add_circled, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(s.financeAddBudget,
                  style: TextStyle(color: AppColors.accent)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.controller, required this.budget});
  final FinanceController controller;
  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final spent = controller.spentForBudget(budget);
    final fraction = budget.amount <= 0 ? 0.0 : spent / budget.amount;
    final over = spent > budget.amount;
    final cur = Currencies.byCode(budget.currencyCode);
    final cat = controller.categoryById(budget.categoryId);
    final color = over
        ? const Color(0xFFFF3B30)
        : (cat != null ? Color(cat.colorValue) : AppColors.accent);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      onPressed: () => showBudgetEditor(context, controller, existing: budget),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(budget.name,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context))),
                ),
                Text(_periodLabel(s, budget.period),
                    style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context))),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressBar(
                  fraction: fraction.clamp(0.0, 1.0), color: color, height: 8),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${cur.format(spent)} / ${cur.format(budget.amount)}',
                    style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.label.resolveFrom(context))),
                const Spacer(),
                Text(
                  over
                      ? s.financeOverBudget(cur.format(spent - budget.amount))
                      : s.financeRemaining(cur.format(budget.amount - spent)),
                  style: TextStyle(
                      fontSize: 13,
                      color: over
                          ? const Color(0xFFFF3B30)
                          : CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(S s, String period) => switch (period) {
        Budget.periodWeekly => s.financePeriodWeekly,
        Budget.periodYearly => s.financePeriodYearly,
        _ => s.financePeriodMonthly,
      };
}

// ── Account detail ───────────────────────────────────────────────────────────

class AccountDetailView extends StatelessWidget {
  const AccountDetailView(
      {super.key, required this.controller, required this.accountId});
  final FinanceController controller;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final account = controller.accountById(accountId);
          if (account == null) {
            return const SizedBox.shrink();
          }
          final balance = controller.balanceOf(accountId);
          final cur = Currencies.byCode(account.currencyCode);
          final txns = controller.transactionsForAccount(accountId)
            ..sort((a, b) => b.date.compareTo(a.date));
          return CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(account.name),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () =>
                      showAccountEditor(context, controller, existing: account),
                  child: Text(s.edit),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(account.colorValue).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.financeBalance,
                            style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context))),
                        const SizedBox(height: 6),
                        Text(cur.format(balance),
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: balance < 0
                                    ? const Color(0xFFFF3B30)
                                    : CupertinoColors.label
                                        .resolveFrom(context))),
                      ],
                    ),
                  ),
                ),
              ),
              if (txns.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(s.financeNoTransactions,
                          style: TextStyle(
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context))),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => TransactionRow(
                        controller: controller, transaction: txns[i]),
                    childCount: txns.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }
}
