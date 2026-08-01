import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../localization/strings.dart';
import '../models/finance_category.dart';
import '../models/finance_transaction.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';
import 'finance_controller.dart';
import 'finance_format.dart';
import 'finance_icons.dart';

/// Modal sheet used to both add and edit a transaction. Pass [existing] to
/// edit; omit it to create a new entry (optionally seeded with [initialDate]
/// / [initialType]).
Future<void> showTransactionSheet(
  BuildContext context,
  FinanceController controller, {
  FinanceTransaction? existing,
  DateTime? initialDate,
  FinanceEntryType? initialType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _TransactionSheet(
      controller: controller,
      existing: existing,
      initialDate: initialDate,
      initialType: initialType,
    ),
  );
}

class _TransactionSheet extends StatefulWidget {
  const _TransactionSheet({
    required this.controller,
    this.existing,
    this.initialDate,
    this.initialType,
  });

  final FinanceController controller;
  final FinanceTransaction? existing;
  final DateTime? initialDate;
  final FinanceEntryType? initialType;

  @override
  State<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<_TransactionSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late FinanceEntryType _type;
  late DateTime _date;
  String? _categoryId;
  int? _amountCents;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.initialType ?? FinanceEntryType.expense;
    final now = DateTime.now();
    final seedDate = existing?.date ?? widget.initialDate ?? now;
    _date = DateTime(seedDate.year, seedDate.month, seedDate.day);
    _categoryId = existing?.categoryId ?? _defaultCategoryId();
    _amountCents = existing?.amount;
    _amountCtrl = TextEditingController(
      text: existing == null ? '' : _plainAmount(existing.amount),
    );
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _noteCtrl = TextEditingController(text: existing?.note ?? '');
    _amountCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Amount rendered for editing — no symbol or grouping, so the text can be
  /// parsed straight back by [parseAmountToCents].
  static String _plainAmount(int cents) {
    final whole = cents ~/ 100;
    final frac = cents % 100;
    return frac == 0
        ? '$whole'
        : '$whole.${frac.toString().padLeft(2, '0')}';
  }

  /// First category of the current type, so a quick entry doesn't have to
  /// touch the picker at all.
  String? _defaultCategoryId() {
    final ofType = widget.controller.categoriesOfType(_type);
    return ofType.isEmpty ? null : ofType.first.id;
  }

  void _onAmountChanged() {
    final parsed = parseAmountToCents(_amountCtrl.text);
    if (parsed != _amountCents) setState(() => _amountCents = parsed);
  }

  void _setType(FinanceEntryType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      // The old category belongs to the other side of the ledger — reset to
      // that type's first category rather than keeping a mismatched one.
      final stillValid = widget.controller
          .categoriesOfType(type)
          .any((c) => c.id == _categoryId);
      if (!stillValid) _categoryId = _defaultCategoryId();
    });
  }

  Future<void> _pickCategory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final s = S.of(context);
    final options = widget.controller.categoriesOfType(_type);
    final picked = await showSelectionMenu<String>(
      context: context,
      title: s.category,
      current: _categoryId ?? '',
      options: [
        SelectionMenuOption(value: '', label: s.uncategorized),
        for (final c in options)
          SelectionMenuOption(value: c.id, label: c.name),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _categoryId = picked.isEmpty ? null : picked);
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    var temp = _date;
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(S.of(ctx).cancel),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(temp),
                      child: Text(S.of(ctx).done),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _date,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _submit() async {
    final cents = _amountCents;
    if (cents == null || cents <= 0) return;
    final s = S.of(context);
    final typed = _titleCtrl.text.trim();
    // An untitled entry is fine — fall back to the category name so the row
    // still reads as something.
    final fallback =
        widget.controller.categoryById(_categoryId)?.name ?? s.uncategorized;
    final note = _noteCtrl.text.trim();

    final existing = widget.existing;
    if (existing != null) {
      await widget.controller.updateTransaction(existing.copyWith(
        title: typed.isEmpty ? fallback : typed,
        amount: cents,
        type: _type,
        categoryId: _categoryId,
        clearCategoryId: _categoryId == null,
        date: _date,
        note: note.isEmpty ? null : note,
        clearNote: note.isEmpty,
      ));
    } else {
      await widget.controller.addTransaction(FinanceTransaction(
        title: typed.isEmpty ? fallback : typed,
        amount: cents,
        type: _type,
        categoryId: _categoryId,
        date: _date,
        note: note.isEmpty ? null : note,
      ));
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final fieldBg = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final category = widget.controller.categoryById(_categoryId);
    final canSubmit = (_amountCents ?? 0) > 0;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.separator.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _isEditing ? s.editTransaction : s.newTransaction,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            CupertinoSlidingSegmentedControl<FinanceEntryType>(
              groupValue: _type,
              children: {
                FinanceEntryType.expense: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    s.expense,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                FinanceEntryType.income: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    s.income,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              },
              onValueChanged: (v) {
                if (v != null) _setType(v);
              },
            ),
            const SizedBox(height: 14),
            // Amount — the one required field, so it takes the focus and the
            // largest type on the sheet.
            Row(
              children: [
                Text(
                  FinanceCurrency.symbol,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoTextField(
                    controller: _amountCtrl,
                    autofocus: !_isEditing,
                    placeholder: '0',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: false),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: _type == FinanceEntryType.expense
                          ? CupertinoColors.label.resolveFrom(context)
                          : AppColors.systemGreen,
                    ),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _titleCtrl,
              placeholder: s.transactionTitle,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 17),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            const SizedBox(height: 8),
            _SheetRow(
              onTap: _pickCategory,
              leading: category == null
                  ? Icon(
                      CupertinoIcons.tag,
                      size: 20,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    )
                  : FinanceCategoryIcon(
                      iconId: category.iconId,
                      color: category.color,
                      size: 26,
                    ),
              label: s.category,
              value: category?.name ?? s.uncategorized,
            ),
            const SizedBox(height: 8),
            _SheetRow(
              onTap: _pickDate,
              leading: Icon(
                CupertinoIcons.calendar,
                size: 20,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              label: s.dateLabel,
              value: formatTransactionDay(context, _date, DateTime.now()),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _noteCtrl,
              placeholder: s.note,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              color: canSubmit ? AppColors.accent : fieldBg,
              borderRadius: BorderRadius.circular(12),
              onPressed: canSubmit ? _submit : null,
              child: Text(
                _isEditing ? s.save : s.add,
                style: TextStyle(
                  color: canSubmit
                      ? CupertinoColors.white
                      : CupertinoColors.tertiaryLabel.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable label/value row used for the category and date pickers.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.onTap,
    required this.leading,
    required this.label,
    required this.value,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(width: 28, height: 28, child: Center(child: leading)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 17))),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}
