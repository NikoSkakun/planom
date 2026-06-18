import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/finance_account.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/editor_widgets.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'finance_controller.dart';
import 'finance_icons.dart';
import 'finance_pickers.dart';
import 'money.dart';

/// Pushes the account create / edit page. When [existing] is null a new account
/// is created (defaulting to [defaultCurrency]).
Future<void> showAccountEditor(
  BuildContext context,
  FinanceController controller, {
  FinanceAccount? existing,
  String? defaultCurrency,
}) {
  return Navigator.of(context).push(
    FastRoute<void>(
      builder: (_) => AccountEditor(
        controller: controller,
        existing: existing,
        defaultCurrency: defaultCurrency ?? controller.defaultCurrency,
      ),
    ),
  );
}

class AccountEditor extends StatefulWidget {
  const AccountEditor({
    super.key,
    required this.controller,
    this.existing,
    required this.defaultCurrency,
  });

  final FinanceController controller;
  final FinanceAccount? existing;
  final String defaultCurrency;

  @override
  State<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<AccountEditor> {
  late final TextEditingController _name;
  late final TextEditingController _opening;
  late String _iconId;
  late int _color;
  late String _type;
  late String _currency;
  late bool _archived;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _iconId = e?.iconId ?? 'wallet';
    _color = e?.colorValue ?? 0xFF34C759;
    _type = e?.type ?? 'cash';
    _currency = e?.currencyCode ?? widget.defaultCurrency;
    _archived = e?.isArchived ?? false;
    final cur = Currencies.byCode(_currency);
    _opening = TextEditingController(
        text: e == null ? '' : cur.formatPlain(e.openingBalance, grouped: false));
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final cur = Currencies.byCode(_currency);
    final opening = cur.parse(_opening.text) ?? 0;
    final e = widget.existing;
    if (e == null) {
      widget.controller.addAccount(FinanceAccount(
        name: name,
        iconId: _iconId,
        colorValue: _color,
        type: _type,
        openingBalance: opening,
        currencyCode: _currency,
      ));
    } else {
      widget.controller.updateAccount(e.copyWith(
        name: name,
        iconId: _iconId,
        colorValue: _color,
        type: _type,
        openingBalance: opening,
        currencyCode: _currency,
        isArchived: _archived,
      ));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await confirmHardDelete(
      context,
      title: S.of(context).financeDeleteAccount,
      body: S.of(context).financeDeleteAccountBody,
    );
    if (!ok || !mounted) return;
    await widget.controller.deleteAccount(e.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickType() async {
    final s = S.of(context);
    final picked = await showSelectionMenu<String>(
      context: context,
      title: s.financeAccountType,
      current: _type,
      options: [
        SelectionMenuOption(value: 'cash', label: s.financeTypeCash),
        SelectionMenuOption(value: 'bank', label: s.financeTypeBank),
        SelectionMenuOption(value: 'card', label: s.financeTypeCard),
        SelectionMenuOption(value: 'savings', label: s.financeTypeSavings),
        SelectionMenuOption(
            value: 'investment', label: s.financeTypeInvestment),
        SelectionMenuOption(value: 'other', label: s.financeTypeOther),
      ],
    );
    if (picked != null) setState(() => _type = picked);
  }

  String _typeLabel(S s) => switch (_type) {
        'bank' => s.financeTypeBank,
        'card' => s.financeTypeCard,
        'savings' => s.financeTypeSavings,
        'investment' => s.financeTypeInvestment,
        'other' => s.financeTypeOther,
        _ => s.financeTypeCash,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final canSave = _name.text.trim().isNotEmpty;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? s.financeEditAccount : s.financeNewAccount),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: canSave ? _save : null,
          child: Text(s.save,
              style: TextStyle(
                  color: canSave
                      ? AppColors.accent
                      : CupertinoColors.tertiaryLabel.resolveFrom(context))),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: FinanceCircleIcon(
                  iconId: _iconId, colorValue: _color, size: 64),
            ),
            const SizedBox(height: 16),
            EditorField(
              child: CupertinoTextField.borderless(
                controller: _name,
                placeholder: s.financeAccountName,
                onChanged: (_) => setState(() {}),
                autofocus: !_isEditing,
              ),
            ),
            const SizedBox(height: 20),
            EditorLabel(s.icon),
            EditorIconGrid(
              presets: kFinanceIconPresets,
              selected: _iconId,
              tint: _color,
              glyph: financeIconData,
              onPick: (icon, color) => setState(() {
                _iconId = icon;
                _color = color;
              }),
            ),
            const SizedBox(height: 16),
            EditorLabel(s.financeColor),
            EditorColorRow(
                selected: _color, onPick: (c) => setState(() => _color = c)),
            const SizedBox(height: 20),
            EditorRowButton(
                label: s.financeAccountType,
                value: _typeLabel(s),
                onTap: _pickType),
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
            const SizedBox(height: 20),
            EditorLabel(s.financeOpeningBalance),
            EditorField(
              child: CupertinoTextField.borderless(
                controller: _opening,
                placeholder: '0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(Currencies.byCode(_currency).symbol,
                      style: TextStyle(
                          color:
                              CupertinoColors.secondaryLabel.resolveFrom(context))),
                ),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 20),
              EditorField(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(s.financeArchiveAccount)),
                      CupertinoSwitch(
                        value: _archived,
                        onChanged: (v) => setState(() => _archived = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton(
                color: CupertinoColors.systemRed.withOpacity(0.12),
                onPressed: _delete,
                child: Text(s.financeDeleteAccount,
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

