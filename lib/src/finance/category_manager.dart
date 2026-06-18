import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/finance_category.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/editor_widgets.dart';
import '../utils/fast_route.dart';
import 'finance_controller.dart';
import 'finance_icons.dart';

Future<void> showCategoryManager(
    BuildContext context, FinanceController controller) {
  return Navigator.of(context).push(
    FastRoute<void>(
      builder: (_) => CategoryManagerView(controller: controller),
    ),
  );
}

class CategoryManagerView extends StatelessWidget {
  const CategoryManagerView({super.key, required this.controller});
  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(s.financeCategories)),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _section(context, s.financeIncome, controller.incomeCategories,
                    'income'),
                _section(context, s.financeExpense,
                    controller.expenseCategories, 'expense'),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title,
      List<FinanceCategory> cats, String kind) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context))),
        ),
        for (final cat in cats)
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onPressed: () =>
                showCategoryEditor(context, controller, existing: cat),
            child: Row(
              children: [
                FinanceCircleIcon(
                    iconId: cat.iconId, colorValue: cat.colorValue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(cat.name,
                      style: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.label.resolveFrom(context))),
                ),
                Icon(CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
              ],
            ),
          ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onPressed: () =>
              showCategoryEditor(context, controller, kind: kind),
          child: Row(
            children: [
              Icon(CupertinoIcons.add_circled, color: AppColors.accent),
              const SizedBox(width: 12),
              Text(s.financeAddCategory,
                  style: TextStyle(color: AppColors.accent)),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showCategoryEditor(
  BuildContext context,
  FinanceController controller, {
  FinanceCategory? existing,
  String kind = 'expense',
}) {
  return Navigator.of(context).push(
    FastRoute<void>(
      builder: (_) => CategoryEditor(
          controller: controller, existing: existing, kind: kind),
    ),
  );
}

class CategoryEditor extends StatefulWidget {
  const CategoryEditor({
    super.key,
    required this.controller,
    this.existing,
    this.kind = 'expense',
  });
  final FinanceController controller;
  final FinanceCategory? existing;
  final String kind;

  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  late final TextEditingController _name;
  late String _iconId;
  late int _color;
  late String _kind;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _iconId = e?.iconId ?? 'tag';
    _color = e?.colorValue ?? 0xFF007AFF;
    _kind = e?.kind ?? widget.kind;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final e = widget.existing;
    if (e == null) {
      widget.controller.addCategory(FinanceCategory(
          name: name, kind: _kind, iconId: _iconId, colorValue: _color));
    } else {
      widget.controller.updateCategory(
          e.copyWith(name: name, iconId: _iconId, colorValue: _color));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await confirmHardDelete(
      context,
      title: S.of(context).financeDeleteCategory,
      body: S.of(context).financeDeleteCategoryBody,
    );
    if (!ok || !mounted) return;
    await widget.controller.deleteCategory(e.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final canSave = _name.text.trim().isNotEmpty;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? s.financeEditCategory : s.financeNewCategory),
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
                placeholder: s.financeCategoryName,
                autofocus: !_isEditing,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: _kind,
                onValueChanged: (v) {
                  if (v != null) setState(() => _kind = v);
                },
                children: {
                  'expense': Text(s.financeExpense),
                  'income': Text(s.financeIncome),
                },
              ),
            ],
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
            if (_isEditing) ...[
              const SizedBox(height: 24),
              CupertinoButton(
                color: CupertinoColors.systemRed.withOpacity(0.12),
                onPressed: _delete,
                child: Text(s.financeDeleteCategory,
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
