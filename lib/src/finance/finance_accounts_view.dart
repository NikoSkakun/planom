import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show ReorderableListView, ReorderableDelayedDragStartListener;

import '../localization/strings.dart';
import '../models/finance_account.dart';
import '../settings/settings_widgets.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'currency.dart';
import 'finance_controller.dart';
import 'finance_format.dart';
import 'finance_icons.dart';
import 'money_amount_dialog.dart';

/// Accounts and cards: their balances, currencies and order. Long-press to
/// drag-reorder, tap to edit, swipe to delete.
class FinanceAccountsView extends StatefulWidget {
  const FinanceAccountsView({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<FinanceAccountsView> createState() => _FinanceAccountsViewState();
}

class _FinanceAccountsViewState extends State<FinanceAccountsView> {
  bool _showArchived = false;

  Future<void> _add() async {
    final created = await showAccountEditor(context);
    if (created != null) await widget.controller.addAccount(created);
  }

  Future<void> _edit(FinanceAccount account) async {
    final updated = await showAccountEditor(context, existing: account);
    if (updated != null) await widget.controller.updateAccount(updated);
  }

  /// Asks, without doing anything yet. Used as `confirmDismiss` so the swipe
  /// resolves on the answer alone.
  Future<bool> _confirmDelete() async {
    final s = S.of(context);
    return confirmHardDelete(
      context,
      title: s.deleteAccountTitle,
      body: s.deleteAccountBody,
      confirmLabel: s.delete,
    );
  }

  Future<void> _delete(FinanceAccount account) async {
    if (await _confirmDelete()) {
      await widget.controller.deleteAccount(account.id);
    }
  }

  /// Answers the swipe with what actually happened: the row only leaves if the
  /// account is really gone.
  ///
  /// The delete belongs here rather than in `onDismissed` because it can fail —
  /// a database constraint, a locked file — and by the time `onDismissed` runs
  /// the row is already out of the tree, leaving an account that is off the
  /// screen but still in the ledger. Returning false on failure springs the row
  /// back, which is the truth. (The old shape did the opposite: it deleted here
  /// and always returned false, asking the row to bounce back at the same
  /// moment the list was dropping it — and when the delete threw, the row was
  /// stranded off screen with the red background showing and nothing said.)
  Future<bool> _confirmAndDelete(FinanceAccount account) async {
    if (!await _confirmDelete()) return false;
    try {
      await widget.controller.deleteAccount(account.id);
      return true;
    } catch (error) {
      debugPrint('Deleting account ${account.id} failed: $error');
      return false;
    }
  }

  Future<void> _menu(FinanceAccount account) async {
    final s = S.of(context);
    final action = await showSelectionMenu<String>(
      context: context,
      title: account.name,
      options: [
        SelectionMenuOption(value: 'edit', label: s.edit),
        SelectionMenuOption(
          value: 'archive',
          label: account.isArchived ? s.accountUnarchive : s.accountArchive,
        ),
        SelectionMenuOption(
            value: 'delete', label: s.delete, isDestructive: true),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _edit(account);
      case 'archive':
        await widget.controller
            .setAccountArchived(account.id, !account.isArchived);
      case 'delete':
        await _delete(account);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.accounts),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: _add,
          child: Icon(CupertinoIcons.add, size: 22, color: AppColors.accent),
        ),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final accounts = _showArchived
                ? widget.controller.accounts
                : widget.controller.activeAccounts;
            final archivedCount =
                widget.controller.accounts.where((a) => a.isArchived).length;
            final totals = widget.controller.totalsByCurrency();

            return Column(
              children: [
                if (totals.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.tertiarySystemBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.accountsTotal,
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // One line per currency — the app never converts
                          // between them, so they're never added together.
                          for (final entry in totals.entries)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: CupertinoColors.secondaryLabel
                                            .resolveFrom(context),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatMoney(entry.value,
                                        currencyCode: entry.key),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: entry.value < 0
                                          ? CupertinoColors.systemRed
                                              .resolveFrom(context)
                                          : CupertinoColors.label
                                              .resolveFrom(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: accounts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              s.noAccountsYet,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.only(top: 6, bottom: 24),
                          buildDefaultDragHandles: false,
                          itemCount: accounts.length,
                          onReorder: (oldIndex, newIndex) =>
                              widget.controller.reorderAccounts(
                            oldIndex,
                            newIndex,
                            // Archived accounts may be hidden, so the indices
                            // are into this list, not the full one.
                            visible: accounts,
                          ),
                          itemBuilder: (context, index) {
                            final account = accounts[index];
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(account.id),
                              index: index,
                              child: Dismissible(
                                key: ValueKey('dismiss_${account.id}'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) =>
                                    _confirmAndDelete(account),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: CupertinoColors.destructiveRed,
                                  child: const Icon(CupertinoIcons.trash,
                                      color: CupertinoColors.white),
                                ),
                                child: _AccountRow(
                                  account: account,
                                  balance:
                                      widget.controller.balanceOf(account),
                                  onTap: () => _edit(account),
                                  onLongPress: () => _menu(account),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (archivedCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SettingsToggleRow(
                      label: s.showArchivedAccounts,
                      value: _showArchived,
                      onChanged: (v) => setState(() => _showArchived = v),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.balance,
    required this.onTap,
    required this.onLongPress,
  });

  final FinanceAccount account;
  final int balance;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: account.isArchived ? 0.5 : 1,
        child: Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              FinanceCategoryIcon(
                  iconId: account.iconId, color: account.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${accountTypeLabel(s, account.type)} · '
                      '${account.currencyCode}'
                      '${account.isArchived ? ' · ${s.accountArchived}' : ''}',
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
                formatMoney(balance, currencyCode: account.currencyCode),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: balance < 0
                      ? CupertinoColors.systemRed.resolveFrom(context)
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

String accountTypeLabel(S s, FinanceAccountType type) {
  switch (type) {
    case FinanceAccountType.cash:
      return s.accountTypeCash;
    case FinanceAccountType.card:
      return s.accountTypeCard;
    case FinanceAccountType.bank:
      return s.accountTypeBank;
    case FinanceAccountType.savings:
      return s.accountTypeSavings;
    case FinanceAccountType.other:
      return s.accountTypeOther;
  }
}

/// Full-screen editor for an account. Returns the new / updated account, or
/// null when cancelled.
Future<FinanceAccount?> showAccountEditor(
  BuildContext context, {
  FinanceAccount? existing,
}) {
  return Navigator.of(context).push<FinanceAccount>(
    FastRoute<FinanceAccount>(
      fullscreenDialog: true,
      builder: (_) => _AccountEditor(existing: existing),
    ),
  );
}

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({this.existing});

  final FinanceAccount? existing;

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late FinanceAccountType _type =
      widget.existing?.type ?? FinanceAccountType.cash;
  late String _currency =
      widget.existing?.currencyCode ?? FinanceCurrency.code;
  late int _initialBalance = widget.existing?.initialBalance ?? 0;
  late int _color = widget.existing?.color ?? kFinanceCategoryColors.first;
  late String _iconId = widget.existing?.iconId ?? 'creditcard';

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickType() async {
    final s = S.of(context);
    final picked = await showSelectionMenu<FinanceAccountType>(
      context: context,
      title: s.accountType,
      current: _type,
      options: [
        for (final t in FinanceAccountType.values)
          SelectionMenuOption(value: t, label: accountTypeLabel(s, t)),
      ],
    );
    if (picked != null && mounted) setState(() => _type = picked);
  }

  Future<void> _pickCurrency() async {
    final s = S.of(context);
    final picked = await showSelectionMenu<String>(
      context: context,
      title: s.currency,
      current: _currency,
      options: [
        for (final c in kCurrencies)
          SelectionMenuOption(
            value: c.code,
            label: '${c.symbol}  ${c.code} · ${c.name}',
          ),
      ],
    );
    if (picked != null && mounted) setState(() => _currency = picked);
  }

  Future<void> _pickInitialBalance() async {
    final s = S.of(context);
    final amount = await showMoneyAmountDialog(
      context,
      title: s.accountInitialBalance,
      message: s.accountInitialBalanceHint,
      current: _initialBalance.abs(),
      allowClear: _initialBalance != 0,
    );
    if (amount == null || !mounted) return;
    setState(() => _initialBalance = amount);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final existing = widget.existing;
    final result = existing == null
        ? FinanceAccount(
            name: name,
            type: _type,
            currencyCode: _currency,
            initialBalance: _initialBalance,
            color: _color,
            iconId: _iconId,
          )
        : existing.copyWith(
            name: name,
            type: _type,
            currencyCode: _currency,
            initialBalance: _initialBalance,
            color: _color,
            iconId: _iconId,
          );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final canSave = _nameCtrl.text.trim().isNotEmpty;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(widget.existing == null ? s.newAccount : s.editAccount),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel, style: TextStyle(color: AppColors.accent)),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: canSave ? _save : null,
          child: Text(
            s.save,
            style: TextStyle(
              color: canSave
                  ? AppColors.accent
                  : CupertinoColors.tertiaryLabel.resolveFrom(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            Row(
              children: [
                FinanceCategoryIcon(iconId: _iconId, color: _color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoTextField(
                    controller: _nameCtrl,
                    autofocus: widget.existing == null,
                    placeholder: s.accountName,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 17),
                    decoration: BoxDecoration(
                      color: CupertinoColors.tertiarySystemFill
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsNavRow(
              label: s.accountType,
              trailingLabel: accountTypeLabel(s, _type),
              onTap: _pickType,
            ),
            const SizedBox(height: 1),
            SettingsNavRow(
              label: s.currency,
              trailingLabel: '${currencySymbol(_currency)} · $_currency',
              onTap: _pickCurrency,
            ),
            const SizedBox(height: 1),
            SettingsNavRow(
              label: s.accountInitialBalance,
              trailingLabel:
                  formatMoney(_initialBalance, currencyCode: _currency),
              onTap: _pickInitialBalance,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                s.accountInitialBalanceHint,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SettingsSectionHeader(s.colorLabel),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in kFinanceCategoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: _color == color
                            ? Border.all(
                                color:
                                    CupertinoColors.label.resolveFrom(context),
                                width: 2)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSectionHeader(s.iconLabel),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final icon in kFinanceAccountIcons)
                  GestureDetector(
                    onTap: () => setState(() => _iconId = icon),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _iconId == icon
                            ? Color(_color).withOpacity(0.18)
                            : CupertinoColors.tertiarySystemFill
                                .resolveFrom(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        financeCategoryIcon(icon),
                        size: 22,
                        color: _iconId == icon
                            ? Color(_color)
                            : CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
