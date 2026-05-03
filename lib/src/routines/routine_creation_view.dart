import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../models/routine.dart';
import '../utils/fast_route.dart';
import 'routine_controller.dart';
import 'routine_icons.dart';

const _kUnits = [
  'ml',
  'L',
  'oz',
  'count',
  'minute',
  'hour',
  'km',
  'mi',
  'page',
  'cup',
  'lap',
  'step',
];

const _kWeekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

void showRoutineCreationView(
  BuildContext context,
  RoutineController controller,
) {
  Navigator.of(context).push(FastRoute(
    settings: const RouteSettings(name: 'routine_creation'),
    builder: (_) => RoutineCreationView(controller: controller),
  ));
}

class RoutineCreationView extends StatefulWidget {
  const RoutineCreationView({
    super.key,
    required this.controller,
    this.existing,
  });

  final RoutineController controller;
  final Routine? existing;

  @override
  State<RoutineCreationView> createState() => _RoutineCreationViewState();
}

class _RoutineCreationViewState extends State<RoutineCreationView> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _customUnitCtrl;
  late final TextEditingController _daysAfterCtrl;
  late final TextEditingController _goalAmountCtrl;
  late final TextEditingController _recordAmountCtrl;

  late String _iconId;
  late int _iconColor;
  late String _goalType; // 'achieve_all' | 'certain_amount'
  late String _goalUnit;
  late bool _useCustomUnit;
  late String _frequencyType; // 'daily' | 'days_after_complete'
  late List<int> _weekdays; // 0=Mon … 6=Sun
  late String _autoReset; // 'everyday' | 'none'

  bool _nameEmpty = true;
  bool _showIconPicker = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _iconId = r?.iconId ?? kRoutineIconPresets[0].$1;
    _iconColor = r?.iconColor ?? kRoutineIconPresets[0].$2;
    _goalType = r?.goalType ?? 'achieve_all';
    final unit = r?.goalUnit ?? 'ml';
    _useCustomUnit = !_kUnits.contains(unit);
    _goalUnit = _useCustomUnit ? 'count' : unit;
    _frequencyType = r?.frequencyType ?? 'daily';
    _weekdays = r?.weekdays ?? [0, 1, 2, 3, 4, 5, 6];
    _autoReset = r?.autoReset ?? 'everyday';

    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _customUnitCtrl =
        TextEditingController(text: _useCustomUnit ? unit : '');
    _daysAfterCtrl = TextEditingController(
        text: r?.daysAfterComplete?.toString() ?? '1');
    _goalAmountCtrl =
        TextEditingController(text: r?.goalAmount?.toString() ?? '');
    _recordAmountCtrl =
        TextEditingController(text: r?.recordAmount?.toString() ?? '');

    _nameEmpty = _nameCtrl.text.trim().isEmpty;
    _nameCtrl.addListener(() {
      final empty = _nameCtrl.text.trim().isEmpty;
      if (empty != _nameEmpty) setState(() => _nameEmpty = empty);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customUnitCtrl.dispose();
    _daysAfterCtrl.dispose();
    _goalAmountCtrl.dispose();
    _recordAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final goalAmount = int.tryParse(_goalAmountCtrl.text.trim());
    final recordAmount = int.tryParse(_recordAmountCtrl.text.trim());
    final daysAfter = int.tryParse(_daysAfterCtrl.text.trim()) ?? 1;
    final unit = _useCustomUnit
        ? _customUnitCtrl.text.trim().isEmpty
            ? 'count'
            : _customUnitCtrl.text.trim()
        : _goalUnit;

    final routine = Routine(
      id: widget.existing?.id,
      creationDate: widget.existing?.creationDate,
      iconId: _iconId,
      name: name,
      iconColor: _iconColor,
      goalType: _goalType,
      goalAmount: _goalType == 'certain_amount' ? goalAmount : null,
      goalUnit: _goalType == 'certain_amount' ? unit : null,
      recordAmount: _goalType == 'certain_amount' ? recordAmount : null,
      frequencyType: _frequencyType,
      weekdays: _frequencyType == 'daily' ? _weekdays : null,
      daysAfterComplete:
          _frequencyType == 'days_after_complete' ? daysAfter : null,
      autoReset: _autoReset,
    );

    if (widget.existing != null) {
      await widget.controller.updateRoutine(routine);
    } else {
      await widget.controller.addRoutine(routine);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickUnit() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0x00000000),
      builder: (_) => _UnitPickerSheet(
        selected: _goalUnit,
        isCustom: _useCustomUnit,
        customValue: _customUnitCtrl.text,
        onSelected: (unit, isCustom) {
          setState(() {
            _useCustomUnit = isCustom;
            if (!isCustom) _goalUnit = unit;
          });
        },
      ),
    );
  }

  String get _unitLabel {
    if (_useCustomUnit) {
      final v = _customUnitCtrl.text.trim();
      return v.isEmpty ? 'custom' : v;
    }
    return _goalUnit;
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final accent = const Color(0xFFFF4D00);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: bg,
        middle: Text(widget.existing == null ? 'New Routine' : 'Edit Routine'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _nameEmpty ? null : _save,
          child: Text(
            'Done',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _nameEmpty ? CupertinoColors.inactiveGray : accent,
            ),
          ),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            // ── Name + icon row (icon tap expands picker) ────────────────
            _Section(
              children: [
                _NameRow(
                  nameCtrl: _nameCtrl,
                  iconId: _iconId,
                  iconColor: _iconColor,
                  onIconTap: () =>
                      setState(() => _showIconPicker = !_showIconPicker),
                ),
                if (_showIconPicker) ...[
                  const _Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: _IconPicker(
                      selectedIconId: _iconId,
                      selectedColor: _iconColor,
                      onChanged: (iconId, color) => setState(() {
                        _iconId = iconId;
                        _iconColor = color;
                      }),
                    ),
                  ),
                ],
              ],
            ),

            // ── Frequency ────────────────────────────────────────────────
            _SectionHeader('FREQUENCY'),
            _Section(children: [
              _SegmentedRow(
                options: const ['Daily', 'X days after completion'],
                selected: _frequencyType == 'daily' ? 0 : 1,
                onChanged: (i) => setState(() =>
                    _frequencyType = i == 0 ? 'daily' : 'days_after_complete'),
              ),
              if (_frequencyType == 'daily') ...[
                const _Divider(),
                _WeekdayPicker(
                  selected: _weekdays,
                  onChanged: (days) => setState(() => _weekdays = days),
                ),
              ] else ...[
                const _Divider(),
                _DaysAfterRow(controller: _daysAfterCtrl),
              ],
              const _Divider(),
              _SwitchRow(
                label: 'Auto Reset',
                sublabel: _autoReset == 'everyday' ? 'Every day' : 'Do not reset',
                onTap: () => _showAutoResetPicker(),
              ),
            ]),

            // ── Goal ─────────────────────────────────────────────────────
            _SectionHeader('GOAL'),
            _Section(children: [
              _SegmentedRow(
                options: const ['Achieve it all', 'Reach certain amount'],
                selected: _goalType == 'achieve_all' ? 0 : 1,
                onChanged: (i) => setState(() =>
                    _goalType = i == 0 ? 'achieve_all' : 'certain_amount'),
              ),
              if (_goalType == 'certain_amount') ...[
                const _Divider(),
                _AmountRow(
                  label: 'Daily goal',
                  controller: _goalAmountCtrl,
                  trailingWidget: GestureDetector(
                    onTap: _pickUnit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _unitLabel,
                          style: TextStyle(
                            fontSize: 15,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 13,
                          color: CupertinoColors.tertiaryLabel
                              .resolveFrom(context),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_useCustomUnit) ...[
                  const _Divider(),
                  _TextRow(
                    label: 'Unit name',
                    controller: _customUnitCtrl,
                    placeholder: 'e.g. glass',
                  ),
                ],
                const _Divider(),
                _AmountRow(
                  label: 'Record per tap',
                  controller: _recordAmountCtrl,
                  trailingWidget: Text(
                    _unitLabel,
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ]),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _showAutoResetPicker() async {
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AutoResetPopup(
        current: _autoReset,
        onChanged: (v) {
          setState(() => _autoReset = v);
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 16),
      color: CupertinoColors.separator.resolveFrom(context),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.nameCtrl,
    required this.iconId,
    required this.iconColor,
    required this.onIconTap,
  });

  final TextEditingController nameCtrl;
  final String iconId;
  final int iconColor;
  final VoidCallback onIconTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onIconTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(iconColor),
                shape: BoxShape.circle,
              ),
              child: Icon(
                routineIconData(iconId),
                color: CupertinoColors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoTextField(
              controller: nameCtrl,
              placeholder: 'Routine name',
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              decoration: const BoxDecoration(),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.selectedIconId,
    required this.selectedColor,
    required this.onChanged,
  });

  final String selectedIconId;
  final int selectedColor;
  final void Function(String iconId, int color) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kRoutineIconPresets.map((preset) {
        final (iconId, color) = preset;
        final isSelected =
            iconId == selectedIconId && color == selectedColor;
        return GestureDetector(
          onTap: () => onChanged(iconId, color),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(color),
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: CupertinoColors.label.resolveFrom(context),
                      width: 3,
                    )
                  : null,
            ),
            child: Icon(
              routineIconData(iconId),
              color: CupertinoColors.white,
              size: 22,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: selected,
        children: {
          for (int i = 0; i < options.length; i++)
            i: Text(
              options[i],
              style: const TextStyle(fontSize: 13),
            ),
        },
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final List<int> selected;
  final void Function(List<int>) onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFFF4D00);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final isOn = selected.contains(i);
          return GestureDetector(
            onTap: () {
              final next = List<int>.from(selected);
              if (isOn) {
                if (next.length > 1) next.remove(i);
              } else {
                next.add(i);
              }
              onChanged(next);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isOn ? accent : CupertinoColors.tertiarySystemFill.resolveFrom(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _kWeekdayLabels[i][0],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOn
                        ? CupertinoColors.white
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DaysAfterRow extends StatelessWidget {
  const _DaysAfterRow({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'days after completion',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 15)),
            const Spacer(),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 13,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.controller,
    required this.trailingWidget,
  });

  final String label;
  final TextEditingController controller;
  final Widget trailingWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const Spacer(),
          trailingWidget,
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15),
              decoration: const BoxDecoration(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Auto-reset popup ─────────────────────────────────────────────────────────

class _AutoResetPopup extends StatelessWidget {
  const _AutoResetPopup({required this.current, required this.onChanged});

  final String current;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final sep = CupertinoColors.separator.resolveFrom(context);

    return Center(
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                'Auto Reset',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Container(height: 0.5, color: sep),
            _Option(label: 'Every day', value: 'everyday', current: current, onChanged: onChanged),
            Container(height: 0.5, color: sep),
            _Option(label: 'Do not reset', value: 'none', current: current, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.value,
    required this.current,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String current;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            if (selected)
              const Icon(CupertinoIcons.checkmark,
                  size: 16, color: Color(0xFFFF4D00)),
          ],
        ),
      ),
    );
  }
}

// ── Unit picker sheet ────────────────────────────────────────────────────────

class _UnitPickerSheet extends StatefulWidget {
  const _UnitPickerSheet({
    required this.selected,
    required this.isCustom,
    required this.customValue,
    required this.onSelected,
  });

  final String selected;
  final bool isCustom;
  final String customValue;
  final void Function(String unit, bool isCustom) onSelected;

  @override
  State<_UnitPickerSheet> createState() => _UnitPickerSheetState();
}

class _UnitPickerSheetState extends State<_UnitPickerSheet> {
  late bool _showCustom;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _showCustom = widget.isCustom;
    _ctrl = TextEditingController(text: widget.customValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose unit',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView(
              children: [
                ..._kUnits.map((u) {
                  final selected = !_showCustom && widget.selected == u;
                  return GestureDetector(
                    onTap: () {
                      widget.onSelected(u, false);
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Text(u, style: const TextStyle(fontSize: 16)),
                          const Spacer(),
                          if (selected)
                            const Icon(CupertinoIcons.checkmark,
                                size: 16, color: Color(0xFFFF4D00)),
                        ],
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => setState(() => _showCustom = true),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        const Text('Custom…',
                            style: TextStyle(fontSize: 16)),
                        const Spacer(),
                        if (_showCustom)
                          const Icon(CupertinoIcons.checkmark,
                              size: 16, color: Color(0xFFFF4D00)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showCustom) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CupertinoTextField(
                controller: _ctrl,
                autofocus: true,
                placeholder: 'Unit name',
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    widget.onSelected(_ctrl.text.trim(), true);
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
