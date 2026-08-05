import 'package:flutter/cupertino.dart';

import '../home_shell.dart';
import '../localization/strings.dart';
import '../models/finance_account.dart';
import '../models/finance_budget.dart';
import '../models/finance_category.dart';
import '../models/finance_transaction.dart';
import '../settings/settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/dropdown_row.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import '../utils/undo_controller.dart';
import 'finance_accounts_view.dart';
import 'finance_budgets_view.dart';
import 'finance_categories_view.dart';
import 'finance_controller.dart';
import 'finance_format.dart';
import 'finance_icons.dart';
import 'transaction_sheet.dart';

/// Finance tab root: a month at a time, with the period's totals, budget
/// progress, a per-category breakdown and the month's transactions grouped by
/// day. The floating + button (handled by [HomeShell]) opens the transaction
/// sheet seeded with the month being viewed.
class FinanceView extends StatefulWidget {
  const FinanceView({
    super.key,
    required this.controller,
    this.settingsController,
    this.resetSignal,
    this.activeMonth,
    this.activeAccount,
  });

  final FinanceController controller;
  final SettingsController? settingsController;

  /// Bumped when the Finance tab is re-tapped — snaps back to the current
  /// month, mirroring the Calendar tab's reset behaviour.
  final ValueNotifier<int>? resetSignal;

  /// Publishes the month being viewed so the shell's + button can date a new
  /// entry inside it instead of always using today.
  final ValueNotifier<DateTime?>? activeMonth;

  /// Publishes the account the tab is filtered to (null = all), so a new
  /// entry starts on the account the user is looking at.

  final ValueNotifier<String?>? activeAccount;

  @override
  State<FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<FinanceView> with DropdownOverlayMixin {
  late DateTime _month;

  /// null = every account. Narrowing to one account also scopes the summary,
  /// breakdown and budgets to that account's currency.
  String? _accountId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    widget.resetSignal?.addListener(_onResetSignal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishMonth());
  }

  @override
  void didUpdateWidget(covariant FinanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) {
      oldWidget.resetSignal?.removeListener(_onResetSignal);
      widget.resetSignal?.addListener(_onResetSignal);
    }
  }

  @override
  void dispose() {
    widget.resetSignal?.removeListener(_onResetSignal);
    super.dispose();
  }

  void _onResetSignal() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() => _month = DateTime(now.year, now.month));
    _publishMonth();
  }

  /// Tells the shell which month the + button should create into: the 1st of
  /// the viewed month, or null while viewing the current one (so a new entry
  /// lands on today).
  void _publishMonth() {
    final notifier = widget.activeMonth;
    if (notifier == null) return;
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    notifier.value = isCurrent ? null : _month;
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _publishMonth();
  }

  void _showMenu(BuildContext context) {
    final s = S.of(context);
    final settingsHidden = widget.settingsController != null &&
        !widget.settingsController!.isTabVisible(4);
    showDropdown(
      context,
      (dismiss) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: dismiss,
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 44.0 + 4.0,
            right: 8,
            child: Container(
              width: 220,
              decoration: AppColors.menuDecoration(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownRow(
                    label: s.accounts,
                    icon: CupertinoIcons.creditcard,
                    onTap: () {
                      dismiss();
                      _openAccounts();
                    },
                  ),
                  DropdownRow(
                    label: s.categories,
                    icon: CupertinoIcons.tag,
                    onTap: () {
                      dismiss();
                      _openCategories();
                    },
                  ),
                  DropdownRow(
                    label: s.budgets,
                    icon: CupertinoIcons.chart_pie,
                    onTap: () {
                      dismiss();
                      _openBudgets();
                    },
                  ),
                  if (settingsHidden)
                    DropdownRow(
                      label: s.settings,
                      icon: CupertinoIcons.gear_alt,
                      onTap: () {
                        dismiss();
                        HomeShell.openGlobalSettings(context);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCategories() {
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => FinanceCategoriesView(controller: widget.controller),
      ),
    );
  }

  void _openBudgets() {
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => FinanceBudgetsView(controller: widget.controller),
      ),
    );
  }

  void _openAccounts() {
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => FinanceAccountsView(controller: widget.controller),
      ),
    );
  }

  /// The account currently filtered to, if any. Resolved through the
  /// controller every time, so a filter pointing at an account the user has
  /// since deleted quietly falls back to "all accounts" instead of showing an
  /// empty month with no chip selected.
  FinanceAccount? get _account => widget.controller.accountById(_accountId);

  /// The filter actually in force — null once the selected account is gone.
  String? get _effectiveAccountId => _account?.id;

  /// Currency the month's figures are denominated in: the selected account's,
  /// or the space default when showing every account.
  String get _currency => _account?.currencyCode ?? FinanceCurrency.code;

  Future<void> _deleteTransaction(FinanceTransaction tx) async {
    await widget.controller.deleteTransaction(tx.id);
    if (!mounted) return;
    UndoScope.maybeOf(context)?.show(
      label: S.of(context).transactionDeleted,
      // Re-inserting the same object restores the entry verbatim (same id,
      // amount and date), so the undo is a true revert.
      onUndo: () => widget.controller.addTransaction(tx),
    );
  }

  Future<void> _showTransactionMenu(FinanceTransaction tx) async {
    final s = S.of(context);
    final action = await showSelectionMenu<String>(
      context: context,
      title: tx.title,
      options: [
        SelectionMenuOption(value: 'edit', label: s.edit),
        SelectionMenuOption(
            value: 'delete', label: s.delete, isDestructive: true),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await showTransactionSheet(context, widget.controller, existing: tx);
    } else if (action == 'delete') {
      final ok = await confirmHardDelete(
        context,
        title: s.deleteTransactionTitle,
        body: s.deleteTransactionBody,
        confirmLabel: s.delete,
      );
      if (ok && mounted) await _deleteTransaction(tx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabFinance),
        trailing: Builder(
          builder: (ctx) => CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => _showMenu(ctx),
            child: Semantics(
              label: s.more,
              button: true,
              child: Icon(
                CupertinoIcons.ellipsis,
                size: 22,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final s = S.of(context);
    final controller = widget.controller;
    final transactions =
        controller.transactionsForMonth(_month, accountId: _effectiveAccountId);
    final progress = controller.budgetProgress(_month,
        currency: _currency, accountId: _effectiveAccountId);
    final breakdown = controller.spendByCategoryForMonth(_month,
        accountId: _effectiveAccountId, currency: _currency);
    // With one account selected there's a single currency to report. Showing
    // every account, each currency gets its own card — the app never sums
    // across currencies because it holds no exchange rates.
    final currencies = _effectiveAccountId != null
        ? [_currency]
        : controller.currenciesInUse;
    final accounts = controller.activeAccounts;

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _MonthNavigator(
          month: _month,
          onPrevious: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
        ),
        if (accounts.isNotEmpty)
          _AccountStrip(
            accounts: accounts,
            selectedId: _effectiveAccountId,
            balanceOf: controller.balanceOf,
            onSelect: (id) {
              setState(() => _accountId = id);
              widget.activeAccount?.value = id;
            },
            onManage: _openAccounts,
          ),
        for (final currency in currencies)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _SummaryCard(
              summary: controller.summaryForMonth(_month,
                  accountId: _effectiveAccountId, currency: currency),
              currencyCode: currency,
              showCurrencyLabel: currencies.length > 1,
            ),
          ),
        // Budgets are denominated in the space's default currency, so they
        // are only shown while that's the currency on screen — comparing a
        // EUR month against a USD budget would be a lie, and the app has no
        // exchange rates to convert with.
        if (progress.isNotEmpty && _currency == FinanceCurrency.code) ...[
          _SectionHeader(
            label: s.budgets,
            actionLabel: s.edit,
            onAction: _openBudgets,
          ),
          for (final p in progress)
            _BudgetRow(
              progress: p,
              category: controller.categoryById(p.budget.categoryId),
              currencyCode: _currency,
            ),
        ],
        if (breakdown.isNotEmpty) ...[
          _SectionHeader(label: s.spendingByCategory),
          for (final entry in breakdown)
            _BreakdownRow(
              spend: entry,
              category: controller.categoryById(entry.categoryId),
              total: controller
                  .summaryForMonth(_month,
                      accountId: _effectiveAccountId, currency: _currency)
                  .expenses,
              currencyCode: _currency,
            ),
        ],
        _SectionHeader(label: s.transactions),
        if (transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.money_dollar_circle,
                  size: 40,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
                const SizedBox(height: 10),
                Text(
                  s.noTransactionsThisMonth,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.tapPlusToAddTransaction,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          )
        else
          ..._buildTransactionGroups(context, transactions),
      ],
    );
  }

  /// Day headers (with that day's net total) followed by their entries.
  List<Widget> _buildTransactionGroups(
      BuildContext context, List<FinanceTransaction> transactions) {
    final now = DateTime.now();
    final widgets = <Widget>[];
    DateTime? currentDay;
    var index = 0;

    while (index < transactions.length) {
      final tx = transactions[index];
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (currentDay == null || day != currentDay) {
        currentDay = day;
        final ofDay = transactions.where((t) =>
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day);
        // A day's net total only means something when everything on it is in
        // one currency — the app never converts, so a mixed day shows no
        // total rather than a nonsense sum.
        final dayCurrencies =
            ofDay.map(widget.controller.currencyOf).toSet();
        final dayTotal =
            ofDay.fold<int>(0, (sum, t) => sum + t.signedAmount);
        widgets.add(_DayHeader(
          label: formatTransactionDay(context, day, now),
          total: dayCurrencies.length == 1 ? dayTotal : null,
          currencyCode:
              dayCurrencies.length == 1 ? dayCurrencies.first : null,
        ));
      }
      widgets.add(_TransactionRow(
        transaction: tx,
        category: widget.controller.categoryById(tx.categoryId),
        account: widget.controller.accountById(tx.accountId),
        toAccount: widget.controller.accountById(tx.toAccountId),
        currencyCode: widget.controller.currencyOf(tx),
        onTap: () =>
            showTransactionSheet(context, widget.controller, existing: tx),
        onLongPress: () => _showTransactionMenu(tx),
        onDismissed: () => _deleteTransaction(tx),
      ));
      index++;
    }
    return widgets;
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

/// Horizontal strip of account chips above the month's figures: "All" plus
/// one chip per active account showing its balance in its own currency.
/// Selecting one scopes everything below to that account.
class _AccountStrip extends StatelessWidget {
  const _AccountStrip({
    required this.accounts,
    required this.selectedId,
    required this.balanceOf,
    required this.onSelect,
    required this.onManage,
  });

  final List<FinanceAccount> accounts;
  final String? selectedId;
  final int Function(FinanceAccount) balanceOf;
  final ValueChanged<String?> onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _AccountChip(
            label: s.allAccounts,
            detail: null,
            color: AppColors.accent.value,
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          for (final account in accounts)
            _AccountChip(
              label: account.name,
              detail: formatMoney(balanceOf(account),
                  currencyCode: account.currencyCode),
              color: account.color,
              selected: selectedId == account.id,
              onTap: () => onSelect(account.id),
            ),
          _AccountChip(
            label: s.manage,
            detail: null,
            color: 0xFF8E8E93,
            selected: false,
            onTap: onManage,
          ),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.label,
    required this.detail,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final int color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Color(color);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? tint.withOpacity(0.16)
              : CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: tint, width: 1) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? tint
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
            if (detail != null)
              Text(
                detail!,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minSize: 0,
            onPressed: onPrevious,
            child: Icon(
              CupertinoIcons.chevron_left,
              size: 18,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          Expanded(
            child: Text(
              formatMonthYear(context, month),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minSize: 0,
            onPressed: onNext,
            child: Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.currencyCode,
    this.showCurrencyLabel = false,
  });

  final FinanceSummary summary;
  final String currencyCode;

  /// Shown when several currencies are on screen, so each card says which
  /// money it is reporting.
  final bool showCurrencyLabel;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final balance = summary.balance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          if (showCurrencyLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    currencyCode,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  label: s.spent,
                  amount:
                      formatMoney(summary.expenses, currencyCode: currencyCode),
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              Container(
                width: 0.5,
                height: 34,
                color: CupertinoColors.separator.resolveFrom(context),
              ),
              Expanded(
                child: _SummaryCell(
                  label: s.income,
                  amount:
                      formatMoney(summary.income, currencyCode: currencyCode),
                  color: AppColors.systemGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 0.5,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.balance,
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              Text(
                formatMoney(balance,
                    signed: balance != 0, currencyCode: currencyCode),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: balance < 0
                      ? CupertinoColors.systemRed.resolveFrom(context)
                      : AppColors.systemGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          amount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                letterSpacing: -0.08,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(fontSize: 13, color: AppColors.accent),
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.progress,
    required this.category,
    required this.currencyCode,
  });

  final BudgetProgress progress;
  final FinanceCategory? category;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final budget = progress.budget;
    final name = budget.isOverall
        ? (budget.period == BudgetPeriod.weekly
            ? s.weeklyBudget
            : s.overallBudget)
        : (category?.name ?? s.uncategorized);
    final tint = progress.isOver
        ? CupertinoColors.systemRed.resolveFrom(context)
        : Color(category?.color ?? AppColors.accent.value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              Text(
                '${formatMoney(progress.spent, currencyCode: currencyCode)}'
                ' / ${formatMoney(budget.amount, currencyCode: currencyCode)}',
                style: TextStyle(
                  fontSize: 13,
                  color: progress.isOver
                      ? CupertinoColors.systemRed.resolveFrom(context)
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: [
                  Container(
                    color: CupertinoColors.tertiarySystemFill
                        .resolveFrom(context),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.fraction,
                    child: Container(color: tint),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progress.isOver
                ? s.overBudgetBy(formatMoney(-progress.remaining,
                    currencyCode: currencyCode))
                : s.leftToSpend(formatMoney(progress.remaining,
                    currencyCode: currencyCode)),
            style: TextStyle(
              fontSize: 12,
              color: progress.isOver
                  ? CupertinoColors.systemRed.resolveFrom(context)
                  : CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.spend,
    required this.category,
    required this.total,
    required this.currencyCode,
  });

  final CategorySpend spend;
  final FinanceCategory? category;
  final int total;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final share = total <= 0 ? 0.0 : (spend.amount / total).clamp(0.0, 1.0);
    final tint = Color(category?.color ?? 0xFF8E8E93);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Row(
        children: [
          FinanceCategoryIcon(
            iconId: category?.iconId,
            color: category?.color ?? 0xFF8E8E93,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category?.name ?? s.uncategorized,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(
                          color: CupertinoColors.tertiarySystemFill
                              .resolveFrom(context),
                        ),
                        FractionallySizedBox(
                          widthFactor: share,
                          child: Container(color: tint),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(spend.amount, currencyCode: currencyCode),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              Text(
                '${(share * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.total,
    required this.currencyCode,
  });

  final String label;

  /// null when the day mixes currencies — see the caller.
  final int? total;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final value = total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          if (value != null)
            Text(
              formatMoney(value,
                  signed: value != 0, currencyCode: currencyCode),
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.category,
    required this.account,
    required this.toAccount,
    required this.currencyCode,
    required this.onTap,
    required this.onLongPress,
    required this.onDismissed,
  });

  final FinanceTransaction transaction;
  final FinanceCategory? category;
  final FinanceAccount? account;
  final FinanceAccount? toAccount;
  final String currencyCode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isIncome = transaction.type == FinanceEntryType.income;
    final isTransfer = transaction.isTransfer;
    // Transfers name both ends; everything else names its category, then its
    // account when one is set.
    final subtitle = isTransfer
        ? '${account?.name ?? s.noAccount} → ${toAccount?.name ?? s.noAccount}'
        : [
            category?.name ?? s.uncategorized,
            if (account != null) account!.name,
          ].join(' · ');
    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.destructiveRed,
        child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              FinanceCategoryIcon(
                iconId: isTransfer
                    ? 'creditcard'
                    : (category?.iconId ?? account?.iconId),
                color: isTransfer
                    ? (account?.color ?? 0xFF8E8E93)
                    : (category?.color ?? 0xFF8E8E93),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.note == null || transaction.note!.isEmpty
                          ? subtitle
                          : '$subtitle · ${transaction.note}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isTransfer
                    ? formatMoney(transaction.amount,
                        currencyCode: currencyCode)
                    : formatMoney(transaction.signedAmount,
                        signed: true, currencyCode: currencyCode),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isTransfer
                      ? CupertinoColors.secondaryLabel.resolveFrom(context)
                      : isIncome
                          ? AppColors.systemGreen
                          : CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
