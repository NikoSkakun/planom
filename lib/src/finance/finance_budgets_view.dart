import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/finance_budget.dart';
import '../models/finance_category.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';
import 'finance_controller.dart';
import 'finance_format.dart';
import 'finance_icons.dart';
import 'money_amount_dialog.dart';

/// Sets spending allowances: one overall budget for the period plus an
/// optional per-category budget. Progress against them is shown on the
/// Finance tab.
class FinanceBudgetsView extends StatelessWidget {
  const FinanceBudgetsView({super.key, required this.controller});

  final FinanceController controller;

  Future<void> _editOverall(BuildContext context) async {
    final s = S.of(context);
    final existing = controller.budgetFor(null);
    final amount = await showMoneyAmountDialog(
      context,
      title: s.overallBudget,
      message: s.budgetAmountHint,
      current: existing?.amount,
    );
    if (amount == null) return;
    await controller.setBudget(
      null,
      amount,
      period: existing?.period ?? BudgetPeriod.monthly,
    );
  }

  Future<void> _editCategory(
      BuildContext context, FinanceCategory category) async {
    final s = S.of(context);
    final existing = controller.budgetFor(category.id);
    final amount = await showMoneyAmountDialog(
      context,
      title: category.name,
      message: s.budgetAmountHint,
      current: existing?.amount,
    );
    if (amount == null) return;
    await controller.setBudget(
      category.id,
      amount,
      period: existing?.period ?? BudgetPeriod.monthly,
    );
  }

  Future<void> _editPeriod(BuildContext context) async {
    final s = S.of(context);
    final existing = controller.budgetFor(null);
    final picked = await showSelectionMenu<BudgetPeriod>(
      context: context,
      title: s.budgetPeriod,
      current: existing?.period ?? BudgetPeriod.monthly,
      options: [
        SelectionMenuOption(value: BudgetPeriod.monthly, label: s.monthly),
        SelectionMenuOption(value: BudgetPeriod.weekly, label: s.weekly),
      ],
    );
    if (picked == null) return;
    // The period applies to every budget at once — one cadence for the whole
    // feature keeps the Finance tab's progress bars comparable.
    for (final budget in controller.budgets) {
      await controller.setBudget(budget.categoryId, budget.amount,
          period: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.budgets),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final overall = controller.budgetFor(null);
            final period = overall?.period ??
                (controller.budgets.isEmpty
                    ? BudgetPeriod.monthly
                    : controller.budgets.first.period);
            final categories =
                controller.categoriesOfType(FinanceEntryType.expense);
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    // Budgets are denominated in the space's default currency;
                    // entries on accounts in other currencies aren't counted,
                    // because the app applies no exchange rates.
                    '${s.budgetsHint}\n${s.budgetsCurrencyHint(FinanceCurrency.code)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
                _BudgetSettingRow(
                  label: s.budgetPeriod,
                  value: period == BudgetPeriod.weekly ? s.weekly : s.monthly,
                  onTap: () => _editPeriod(context),
                ),
                _BudgetSettingRow(
                  label: s.overallBudget,
                  value: overall == null
                      ? s.noBudget
                      : formatMoney(overall.amount),
                  onTap: () => _editOverall(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                  child: Text(
                    s.categories,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
                if (categories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(
                      s.noCategoriesYet,
                      style: TextStyle(
                        fontSize: 15,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                for (final category in categories)
                  _CategoryBudgetRow(
                    category: category,
                    budget: controller.budgetFor(category.id),
                    onTap: () => _editCategory(context, category),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BudgetSettingRow extends StatelessWidget {
  const _BudgetSettingRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 17))),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    required this.category,
    required this.budget,
    required this.onTap,
  });

  final FinanceCategory category;
  final FinanceBudget? budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            FinanceCategoryIcon(
              iconId: category.iconId,
              color: category.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Text(
              budget == null ? s.noBudget : formatMoney(budget!.amount),
              style: TextStyle(
                fontSize: 15,
                color: budget == null
                    ? CupertinoColors.tertiaryLabel.resolveFrom(context)
                    : AppColors.accent,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}
