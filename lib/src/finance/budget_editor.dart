import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/editor_widgets.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'finance_controller.dart';
import 'finance_pickers.dart';
import 'money.dart';

Future<void> showBudgetEditor(
  BuildContext context,
  FinanceController controller, {
  Budget? existing,
}) {
  return Navigator.of(context).push(
    FastRoute<void>(
      builder: (_) =>
          BudgetEditor(controller: controller, existing: existing),
    ),
  );
}

class BudgetEditor extends StatefulWidget {
  const BudgetEditor({super.key, required this.controller, this.existing});
  final FinanceController controller;
  final Budget? existing;

  @override
  State<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<BudgetEditor> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  String? _categoryId;
  late String _period;
  late String _currency;

  bool get _isEditing => widget.existing != null;
  FinanceController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _categoryId = e?.categoryId;
    _period = e?.period ?? Budget.periodMonthly;
    _currency = e?.currencyCode ?? _c.defaultCurrency;
    _name = TextEditingController(text: e?.name ?? '');
    final cur = Currencies.byCode(_currency);
    _amount = TextEditingController(
        text: e == null ? '' : cur.formatPlain(e.amount, grouped: false));
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _canSave {
    final amount = Currencies.byCode(_currency).parse(_amount.text);
    return _name.text.trim().isNotEmpty && amount != null && amount > 0;
  }

  void _save() {
    if (!_canSave) return;
    final amount = Currencies.byCode(_currency).parse(_amount.text)!;
    final e = widget.existing;
    if (e == null) {
      _c.addBudget(Budget(
        name: _name.text.trim(),
        categoryId: _categoryId,
        amount: amount,
        period: _period,
        currencyCode: _currency,
      ));
    } else {
      _c.updateBudget(e.copyWith(
        name: _name.text.trim(),
        categoryId: _categoryId,
        clearCategoryId: _categoryId == null,
        amount: amount,
        period: _period,
        currencyCode: _currency,
      ));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await confirmHardDelete(
      context,
      title: S.of(context).financeDeleteBudget,
      body: S.of(context).financeDeleteBudgetBody,
    );
    if (!ok || !mounted) return;
    await _c.deleteBudget(e.id);
    if (mounted) Navigator.of(context).pop();
  }

  String _periodLabel(S s) => switch (_period) {
        Budget.periodWeekly => s.financePeriodWeekly,
        Budget.periodYearly => s.financePeriodYearly,
        _ => s.financePeriodMonthly,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cat = _c.categoryById(_categoryId);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? s.financeEditBudget : s.financeNewBudget),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _canSave ? _save : null,
          child: Text(s.save,
              style: TextStyle(
                  color: _canSave
                      ? AppColors.accent
                      : CupertinoColors.tertiaryLabel.resolveFrom(context))),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EditorField(
              child: CupertinoTextField.borderless(
                controller: _name,
                placeholder: s.financeBudgetName,
                autofocus: !_isEditing,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 20),
            EditorLabel(s.financeLimit),
            EditorField(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(Currencies.byCode(_currency).symbol,
                        style: TextStyle(
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: CupertinoTextField.borderless(
                        controller: _amount,
                        placeholder: '0',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            EditorRowButton(
              label: s.financeCategory,
              value: cat?.name ?? s.financeAllExpenses,
              onTap: () async {
                final picked = await showSelectionMenu<String>(
                  context: context,
                  title: s.financeCategory,
                  current: _categoryId ?? '',
                  options: [
                    SelectionMenuOption(value: '', label: s.financeAllExpenses),
                    for (final c in _c.expenseCategories)
                      SelectionMenuOption(value: c.id, label: c.name),
                  ],
                );
                if (picked != null) {
                  setState(() => _categoryId = picked.isEmpty ? null : picked);
                }
              },
            ),
            const SizedBox(height: 10),
            EditorRowButton(
              label: s.financePeriod,
              value: _periodLabel(s),
              onTap: () async {
                final picked = await showSelectionMenu<String>(
                  context: context,
                  title: s.financePeriod,
                  current: _period,
                  options: [
                    SelectionMenuOption(
                        value: Budget.periodWeekly, label: s.financePeriodWeekly),
                    SelectionMenuOption(
                        value: Budget.periodMonthly,
                        label: s.financePeriodMonthly),
                    SelectionMenuOption(
                        value: Budget.periodYearly, label: s.financePeriodYearly),
                  ],
                );
                if (picked != null) setState(() => _period = picked);
              },
            ),
            const SizedBox(height: 10),
            EditorRowButton(
              label: s.financeCurrency,
              value: '${Currencies.byCode(_currency).symbol} $_currency',
              onTap: () async {
                final picked =
                    await showCurrencyPicker(context, current: _currency);
                if (picked != null) setState(() => _currency = picked);
              },
            ),
            if (_isEditing) ...[
              const SizedBox(height: 24),
              CupertinoButton(
                color: CupertinoColors.systemRed.withOpacity(0.12),
                onPressed: _delete,
                child: Text(s.financeDeleteBudget,
                    style:
                        const TextStyle(color: CupertinoColors.destructiveRed)),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
