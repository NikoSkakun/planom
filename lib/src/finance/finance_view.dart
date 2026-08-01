import 'package:flutter/cupertino.dart';

import '../home_shell.dart';
import '../localization/strings.dart';
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
  });

  final FinanceController controller;
  final SettingsController? settingsController;

  /// Bumped when the Finance tab is re-tapped — snaps back to the current
  /// month, mirroring the Calendar tab's reset behaviour.
  final ValueNotifier<int>? resetSignal;

  /// Publishes the month being viewed so the shell's + button can date a new
  /// entry inside it instead of always using today.
  final ValueNotifier<DateTime?>? activeMonth;

  @override
  State<FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<FinanceView> with DropdownOverlayMixin {
  late DateTime _month;

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
    final summary = controller.summaryForMonth(_month);
    final transactions = controller.transactionsForMonth(_month);
    final progress = controller.budgetProgress(_month);
    final breakdown = controller.spendByCategoryForMonth(_month);

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _MonthNavigator(
          month: _month,
          onPrevious: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _SummaryCard(summary: summary),
        ),
        if (progress.isNotEmpty) ...[
          _SectionHeader(
            label: s.budgets,
            actionLabel: s.edit,
            onAction: _openBudgets,
          ),
          for (final p in progress)
            _BudgetRow(
              progress: p,
              category: controller.categoryById(p.budget.categoryId),
            ),
        ],
        if (breakdown.isNotEmpty) ...[
          _SectionHeader(label: s.spendingByCategory),
          for (final entry in breakdown)
            _BreakdownRow(
              spend: entry,
              category: controller.categoryById(entry.categoryId),
              total: summary.expenses,
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
        final dayTotal = transactions
            .where((t) =>
                t.date.year == day.year &&
                t.date.month == day.month &&
                t.date.day == day.day)
            .fold<int>(0, (sum, t) => sum + t.signedAmount);
        widgets.add(_DayHeader(
          label: formatTransactionDay(context, day, now),
          total: dayTotal,
        ));
      }
      widgets.add(_TransactionRow(
        transaction: tx,
        category: widget.controller.categoryById(tx.categoryId),
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
  const _SummaryCard({required this.summary});

  final FinanceSummary summary;

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
          Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  label: s.spent,
                  amount: formatMoney(summary.expenses),
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
                  amount: formatMoney(summary.income),
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
                formatMoney(balance, signed: balance != 0),
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
  const _BudgetRow({required this.progress, required this.category});

  final BudgetProgress progress;
  final FinanceCategory? category;

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
                '${formatMoney(progress.spent)} / ${formatMoney(budget.amount)}',
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
                ? s.overBudgetBy(formatMoney(-progress.remaining))
                : s.leftToSpend(formatMoney(progress.remaining)),
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
  });

  final CategorySpend spend;
  final FinanceCategory? category;
  final int total;

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
                formatMoney(spend.amount),
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
  const _DayHeader({required this.label, required this.total});

  final String label;
  final int total;

  @override
  Widget build(BuildContext context) {
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
          Text(
            formatMoney(total, signed: total != 0),
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
    required this.onTap,
    required this.onLongPress,
    required this.onDismissed,
  });

  final FinanceTransaction transaction;
  final FinanceCategory? category;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == FinanceEntryType.income;
    final subtitle = category?.name ?? S.of(context).uncategorized;
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
                iconId: category?.iconId,
                color: category?.color ?? 0xFF8E8E93,
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
                formatMoney(transaction.signedAmount, signed: true),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isIncome
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
