import 'package:flutter/cupertino.dart';

import '../finance/finance_accounts_view.dart';
import '../finance/finance_budgets_view.dart';
import '../finance/finance_categories_view.dart';
import '../finance/currency.dart';
import '../localization/strings.dart';
import '../spaces/space_manager.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'plus_button_settings_view.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// Settings → Modules → Finance: currency display, + button placement, and
/// shortcuts into the active space's categories / budgets.
class FinanceSettingsView extends StatelessWidget {
  const FinanceSettingsView({super.key, required this.controller});

  final SettingsController controller;

  /// Picks the space's default currency — the one used by entries with no
  /// account, and the default for a newly created account.
  Future<void> _pickCurrency(BuildContext context) async {
    final s = S.of(context);
    // Sentinel: opens a free-text prompt for a symbol not in the catalogue.
    const custom = '__custom__';
    final picked = await showSelectionMenu<String>(
      context: context,
      title: s.currency,
      current: controller.financeCurrencyCode,
      options: [
        for (final currency in kCurrencies)
          SelectionMenuOption(
            value: currency.code,
            label: '${currency.symbol}  ${currency.code} · ${currency.name}',
          ),
        SelectionMenuOption(value: custom, label: s.customCurrency),
      ],
    );
    if (picked == null || !context.mounted) return;
    if (picked != custom) {
      await controller.updateFinanceCurrency(picked);
      return;
    }
    final typed = await _promptCustomSymbol(context);
    if (typed != null && typed.trim().isNotEmpty) {
      await controller.updateFinanceCurrencySymbol(typed);
    }
  }

  Future<String?> _promptCustomSymbol(BuildContext context) {
    final s = S.of(context);
    final ctrl =
        TextEditingController(text: controller.financeCurrencySymbol);
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.currency),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            placeholder: r'$',
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: Text(
              s.done,
              style: TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final financeController =
        SpaceManagerProvider.maybeOf(context)?.financeController;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabFinance),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                SettingsSectionHeader(s.sectionCurrency),
                SettingsNavRow(
                  label: s.currency,
                  trailingLabel:
                      '${controller.financeCurrencySymbol} · ${controller.financeCurrencyCode}',
                  onTap: () => _pickCurrency(context),
                ),
                const SizedBox(height: 1),
                SettingsToggleRow(
                  label: s.showDecimals,
                  value: controller.financeShowDecimals,
                  onChanged: controller.updateFinanceShowDecimals,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.showDecimalsHint,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
                if (financeController != null) ...[
                  const SizedBox(height: 18),
                  SettingsSectionHeader(s.tabFinance),
                  SettingsNavRow(
                    label: s.accounts,
                    onTap: () => Navigator.of(context).push(
                      FastRoute<void>(
                        builder: (_) => FinanceAccountsView(
                          controller: financeController,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  SettingsNavRow(
                    label: s.categories,
                    onTap: () => Navigator.of(context).push(
                      FastRoute<void>(
                        builder: (_) => FinanceCategoriesView(
                          controller: financeController,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  SettingsNavRow(
                    label: s.budgets,
                    onTap: () => Navigator.of(context).push(
                      FastRoute<void>(
                        builder: (_) => FinanceBudgetsView(
                          controller: financeController,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SettingsSectionHeader(s.plusButton),
                PlusButtonOverrideRow(controller: controller, tab: 5),
              ],
            );
          },
        ),
      ),
    );
  }
}
