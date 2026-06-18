import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/finance_transaction.dart';
import '../theme/app_theme.dart';
import '../utils/editor_widgets.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import '../utils/simple_date_picker.dart';
import '../utils/undo_controller.dart';
import 'account_editor.dart';
import 'finance_controller.dart';
import 'finance_icons.dart';
import 'money.dart';

/// Pushes the transaction create / edit page. Optionally pre-selects an
/// [initialAccountId] and the [initialType] ('expense' | 'income' | 'transfer').
Future<void> showTransactionEditor(
  BuildContext context,
  FinanceController controller, {
  FinanceTransaction? existing,
  String? initialAccountId,
  String initialType = FinanceTransaction.typeExpense,
}) {
  // Pushed on the nearest navigator (the active tab's) so the editor stays
  // beneath the shell's UndoScope — delete shows an Undo banner.
  return Navigator.of(context).push(
    FastRoute<void>(
      builder: (_) => TransactionEditor(
        controller: controller,
        existing: existing,
        initialAccountId: initialAccountId,
        initialType: initialType,
      ),
    ),
  );
}

class TransactionEditor extends StatefulWidget {
  const TransactionEditor({
    super.key,
    required this.controller,
    this.existing,
    this.initialAccountId,
    this.initialType = FinanceTransaction.typeExpense,
  });

  final FinanceController controller;
  final FinanceTransaction? existing;
  final String? initialAccountId;
  final String initialType;

  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<TransactionEditor> {
  late String _type;
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _note;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  late DateTime _date;

  bool get _isEditing => widget.existing != null;
  FinanceController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType;
    _accountId = e?.accountId ??
        widget.initialAccountId ??
        (_c.activeAccounts.isNotEmpty ? _c.activeAccounts.first.id : null);
    _toAccountId = e?.toAccountId;
    _categoryId = e?.categoryId;
    _date = e?.date ?? DateTime.now();
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    final cur = _currency;
    _amount = TextEditingController(
        text: e == null ? '' : cur.formatPlain(e.amount, grouped: false));
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Currency get _currency {
    final acc = _c.accountById(_accountId);
    return Currencies.byCode(acc?.currencyCode ?? _c.defaultCurrency);
  }

  Color get _typeColor => switch (_type) {
        FinanceTransaction.typeIncome => const Color(0xFF34C759),
        FinanceTransaction.typeTransfer => const Color(0xFF007AFF),
        _ => const Color(0xFFFF3B30),
      };

  bool get _canSave {
    final amount = _currency.parse(_amount.text);
    if (amount == null || amount <= 0) return false;
    if (_accountId == null) return false;
    if (_type == FinanceTransaction.typeTransfer) {
      if (_toAccountId == null || _toAccountId == _accountId) return false;
    }
    return true;
  }

  void _save() {
    if (!_canSave) return;
    final amount = _currency.parse(_amount.text)!;
    final e = widget.existing;
    final txn = (e ??
            FinanceTransaction(
                type: _type, amount: amount, accountId: _accountId!, date: _date))
        .copyWith(
      type: _type,
      amount: amount,
      accountId: _accountId,
      toAccountId: _type == FinanceTransaction.typeTransfer ? _toAccountId : null,
      clearToAccountId: _type != FinanceTransaction.typeTransfer,
      categoryId: _type == FinanceTransaction.typeTransfer ? null : _categoryId,
      clearCategoryId:
          _type == FinanceTransaction.typeTransfer || _categoryId == null,
      title: _title.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      clearNote: _note.text.trim().isEmpty,
      date: _date,
    );
    if (e == null) {
      _c.addTransaction(txn);
    } else {
      _c.updateTransaction(txn);
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final undo = UndoScope.of(context);
    final label = S.of(context).financeTransactionDeleted;
    await _c.deleteTransaction(e.id);
    undo.show(label: label, onUndo: () => _c.restoreTransaction(e));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickAccount({required bool source}) async {
    final s = S.of(context);
    if (_c.activeAccounts.isEmpty) {
      await showAccountEditor(context, _c);
      setState(() {
        _accountId ??=
            _c.activeAccounts.isNotEmpty ? _c.activeAccounts.first.id : null;
      });
      return;
    }
    final picked = await showSelectionMenu<String>(
      context: context,
      title: source ? s.financeAccount : s.financeToAccount,
      current: source ? _accountId : _toAccountId,
      options: [
        for (final a in _c.activeAccounts)
          SelectionMenuOption(value: a.id, label: a.name),
      ],
    );
    if (picked == null) return;
    setState(() {
      if (source) {
        _accountId = picked;
        // Category currency follows the account; nothing to reconcile, but the
        // amount field's symbol updates via _currency.
      } else {
        _toAccountId = picked;
      }
    });
  }

  Future<void> _pickCategory() async {
    final s = S.of(context);
    final cats = _type == FinanceTransaction.typeIncome
        ? _c.incomeCategories
        : _c.expenseCategories;
    final picked = await showSelectionMenu<String>(
      context: context,
      title: s.financeCategory,
      current: _categoryId ?? '',
      options: [
        SelectionMenuOption(value: '', label: s.financeUncategorized),
        for (final cat in cats)
          SelectionMenuOption(
              value: cat.id, label: cat.name, icon: financeIconData(cat.iconId)),
      ],
    );
    if (picked == null) return;
    setState(() => _categoryId = picked.isEmpty ? null : picked);
  }

  String _accountLabel(String? id, S s) =>
      _c.accountById(id)?.name ?? s.financeSelectAccount;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isTransfer = _type == FinanceTransaction.typeTransfer;
    final cat = _c.categoryById(_categoryId);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? s.financeEditTransaction : s.financeNewTransaction),
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
            // Type segmented control.
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _type,
              onValueChanged: (v) {
                if (v == null) return;
                setState(() {
                  _type = v;
                  if (v == FinanceTransaction.typeTransfer) _categoryId = null;
                });
              },
              children: {
                FinanceTransaction.typeExpense: Text(s.financeExpense),
                FinanceTransaction.typeIncome: Text(s.financeIncome),
                FinanceTransaction.typeTransfer: Text(s.financeTransfer),
              },
            ),
            const SizedBox(height: 20),
            // Big amount field.
            EditorField(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Text(_currency.symbol,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: _typeColor)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: CupertinoTextField.borderless(
                        controller: _amount,
                        placeholder: '0',
                        autofocus: !_isEditing,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: _typeColor),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            EditorRowButton(
              label: isTransfer ? s.financeFromAccount : s.financeAccount,
              value: _accountLabel(_accountId, s),
              onTap: () => _pickAccount(source: true),
            ),
            if (isTransfer) ...[
              const SizedBox(height: 10),
              EditorRowButton(
                label: s.financeToAccount,
                value: _accountLabel(_toAccountId, s),
                onTap: () => _pickAccount(source: false),
              ),
            ] else ...[
              const SizedBox(height: 10),
              EditorRowButton(
                label: s.financeCategory,
                value: cat?.name ?? s.financeUncategorized,
                leading: cat == null
                    ? null
                    : FinanceCircleIcon(
                        iconId: cat.iconId,
                        colorValue: cat.colorValue,
                        size: 24),
                onTap: _pickCategory,
              ),
            ],
            const SizedBox(height: 10),
            EditorRowButton(
              label: s.date,
              value: formatShortDate(_date),
              onTap: () async {
                final picked =
                    await showSimpleDatePicker(context, initial: _date);
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 20),
            EditorField(
              child: CupertinoTextField.borderless(
                controller: _title,
                placeholder: s.financeTitlePlaceholder,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            EditorField(
              child: CupertinoTextField.borderless(
                controller: _note,
                placeholder: s.note,
                maxLines: 3,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 24),
              CupertinoButton(
                color: CupertinoColors.systemRed.withOpacity(0.12),
                onPressed: _delete,
                child: Text(s.delete,
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
