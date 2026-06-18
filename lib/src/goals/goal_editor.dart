import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import '../utils/editor_widgets.dart';
import '../utils/fast_route.dart';
import '../utils/simple_date_picker.dart';
import 'goal_controller.dart';
import 'goal_icons.dart';

Future<void> showGoalEditor(
  BuildContext context,
  GoalController controller, {
  Goal? existing,
}) {
  return Navigator.of(context).push(
    FastRoute<void>(
      builder: (_) => GoalEditor(controller: controller, existing: existing),
    ),
  );
}

class GoalEditor extends StatefulWidget {
  const GoalEditor({super.key, required this.controller, this.existing});
  final GoalController controller;
  final Goal? existing;

  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _target;
  late final TextEditingController _unit;
  late String _type;
  late String _iconId;
  late int _color;
  DateTime? _targetDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _target =
        TextEditingController(text: e?.targetAmount?.toString() ?? '');
    _unit = TextEditingController(text: e?.unit ?? '');
    _type = e?.type ?? Goal.typeMilestone;
    _iconId = e?.iconId ?? 'flag';
    _color = e?.colorValue ?? 0xFFFF9500;
    _targetDate = e?.targetDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_title.text.trim().isEmpty) return false;
    if (_type == Goal.typeNumeric) {
      final t = int.tryParse(_target.text.trim());
      if (t == null || t <= 0) return false;
    }
    return true;
  }

  void _save() {
    if (!_canSave) return;
    final title = _title.text.trim();
    final note = _note.text.trim();
    final target = int.tryParse(_target.text.trim());
    final unit = _unit.text.trim();
    final e = widget.existing;
    if (e == null) {
      widget.controller.addGoal(Goal(
        title: title,
        note: note.isEmpty ? null : note,
        type: _type,
        targetAmount: _type == Goal.typeNumeric ? target : null,
        unit: _type == Goal.typeNumeric && unit.isNotEmpty ? unit : null,
        iconId: _iconId,
        colorValue: _color,
        targetDate: _targetDate,
      ));
    } else {
      widget.controller.updateGoal(e.copyWith(
        title: title,
        note: note.isEmpty ? null : note,
        clearNote: note.isEmpty,
        type: _type,
        targetAmount: _type == Goal.typeNumeric ? target : null,
        clearTargetAmount: _type != Goal.typeNumeric,
        unit: _type == Goal.typeNumeric && unit.isNotEmpty ? unit : null,
        clearUnit: _type != Goal.typeNumeric || unit.isEmpty,
        iconId: _iconId,
        colorValue: _color,
        targetDate: _targetDate,
        clearTargetDate: _targetDate == null,
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? s.goalEdit : s.goalNew),
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
            Center(
              child:
                  GoalCircleIcon(iconId: _iconId, colorValue: _color, size: 64),
            ),
            const SizedBox(height: 16),
            EditorField(
              child: CupertinoTextField.borderless(
                controller: _title,
                placeholder: s.goalTitle,
                autofocus: !_isEditing,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _type,
              onValueChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
              children: {
                Goal.typeMilestone: Text(s.goalTypeMilestone),
                Goal.typeNumeric: Text(s.goalTypeNumeric),
              },
            ),
            if (_type == Goal.typeNumeric) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: EditorField(
                      child: CupertinoTextField.borderless(
                        controller: _target,
                        placeholder: s.goalTarget,
                        keyboardType: TextInputType.number,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: EditorField(
                      child: CupertinoTextField.borderless(
                        controller: _unit,
                        placeholder: s.goalUnit,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            EditorRowButton(
              label: s.goalTargetDate,
              value: _targetDate == null
                  ? s.goalNoDate
                  : formatShortDate(_targetDate!),
              onTap: () async {
                final picked = await showSimpleDatePicker(context,
                    initial: _targetDate ?? DateTime.now());
                if (picked != null) setState(() => _targetDate = picked);
              },
            ),
            if (_targetDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  minSize: 0,
                  onPressed: () => setState(() => _targetDate = null),
                  child: Text(s.goalClearDate,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            const SizedBox(height: 16),
            EditorField(
              child: CupertinoTextField.borderless(
                controller: _note,
                placeholder: s.note,
                maxLines: 3,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            EditorLabel(s.icon),
            EditorIconGrid(
              presets: kGoalIconPresets,
              selected: _iconId,
              tint: _color,
              glyph: goalIconData,
              onPick: (icon, color) => setState(() {
                _iconId = icon;
                _color = color;
              }),
            ),
            const SizedBox(height: 16),
            EditorLabel(s.financeColor),
            EditorColorRow(
                selected: _color, onPick: (c) => setState(() => _color = c)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
