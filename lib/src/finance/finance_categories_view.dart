import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show ReorderableListView, ReorderableDelayedDragStartListener;

import '../localization/strings.dart';
import '../models/finance_category.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/fast_route.dart';
import 'finance_controller.dart';
import 'finance_icons.dart';

/// Manages the space's finance categories: one segment per side of the ledger
/// (expenses / income), long-press to drag-reorder, tap to edit, swipe to
/// delete.
class FinanceCategoriesView extends StatefulWidget {
  const FinanceCategoriesView({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<FinanceCategoriesView> createState() => _FinanceCategoriesViewState();
}

class _FinanceCategoriesViewState extends State<FinanceCategoriesView> {
  FinanceEntryType _type = FinanceEntryType.expense;

  Future<void> _add() async {
    final created = await showCategoryEditor(context, type: _type);
    if (created != null) await widget.controller.addCategory(created);
  }

  Future<void> _edit(FinanceCategory category) async {
    final updated = await showCategoryEditor(
      context,
      type: category.type,
      existing: category,
    );
    if (updated != null) await widget.controller.updateCategory(updated);
  }

  Future<void> _delete(FinanceCategory category) async {
    final s = S.of(context);
    final ok = await confirmHardDelete(
      context,
      title: s.deleteCategoryTitle,
      body: s.deleteCategoryBody,
      confirmLabel: s.delete,
    );
    if (ok) await widget.controller.deleteCategory(category.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.categories),
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
            final categories = widget.controller.categoriesOfType(_type);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<FinanceEntryType>(
                      groupValue: _type,
                      children: {
                        FinanceEntryType.expense: Text(
                          s.expenses,
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        FinanceEntryType.income: Text(
                          s.income,
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                      },
                      onValueChanged: (v) {
                        if (v != null) setState(() => _type = v);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: categories.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              s.noCategoriesYet,
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
                          padding: const EdgeInsets.only(bottom: 24),
                          buildDefaultDragHandles: false,
                          itemCount: categories.length,
                          onReorder: (oldIndex, newIndex) => widget.controller
                              .reorderCategories(_type, oldIndex, newIndex),
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(category.id),
                              index: index,
                              child: Dismissible(
                                key: ValueKey('dismiss_${category.id}'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  await _delete(category);
                                  // Deleting rebuilds the list from the
                                  // controller, so never let Dismissible
                                  // remove the row itself.
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: CupertinoColors.destructiveRed,
                                  child: const Icon(CupertinoIcons.trash,
                                      color: CupertinoColors.white),
                                ),
                                child: _CategoryRow(
                                  category: category,
                                  onTap: () => _edit(category),
                                ),
                              ),
                            );
                          },
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onTap});

  final FinanceCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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

/// Full-screen editor for a category (name + icon + colour). Returns the new /
/// updated category, or null when cancelled.
Future<FinanceCategory?> showCategoryEditor(
  BuildContext context, {
  required FinanceEntryType type,
  FinanceCategory? existing,
}) {
  return Navigator.of(context).push<FinanceCategory>(
    FastRoute<FinanceCategory>(
      fullscreenDialog: true,
      builder: (_) => _CategoryEditor(type: type, existing: existing),
    ),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.type, this.existing});

  final FinanceEntryType type;
  final FinanceCategory? existing;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _nameCtrl;
  late String _iconId;
  late int _color;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _iconId = widget.existing?.iconId ?? kFinanceCategoryIcons.first;
    _color = widget.existing?.color ?? kFinanceCategoryColors.first;
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final existing = widget.existing;
    final result = existing == null
        ? FinanceCategory(
            name: name,
            iconId: _iconId,
            color: _color,
            type: widget.type,
          )
        : existing.copyWith(name: name, iconId: _iconId, color: _color);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final canSave = _nameCtrl.text.trim().isNotEmpty;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(widget.existing == null ? s.newCategory : s.editCategory),
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
                    placeholder: s.categoryName,
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
            const SizedBox(height: 22),
            Text(
              s.colorLabel,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
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
                                color: CupertinoColors.label
                                    .resolveFrom(context),
                                width: 2)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              s.iconLabel,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final icon in kFinanceCategoryIcons)
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
