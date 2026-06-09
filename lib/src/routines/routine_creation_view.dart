import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart' show showModalBottomSheet;

import '../folders/folder_icon_picker.dart'
    show pickCustomIcon, isCustomIconId;
import '../localization/strings.dart';
import '../models/routine.dart';
import '../models/routine_reminder.dart';
import '../tasks/calendar_date_picker.dart'
    show formatDoTime, formatTaskDateRelative;
import '../theme/app_theme.dart';
import '../utils/day_boundary.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
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
  late final TextEditingController _goalAmountCtrl;
  late final TextEditingController _recordAmountCtrl;

  late String _iconId;
  late int _iconColor;
  late String _goalType; // 'achieve_all' | 'certain_amount'
  late String _goalUnit;
  late bool _useCustomUnit;
  late String _frequencyType; // 'daily' | 'specific_days' | 'interval'
  late List<int> _weekdays; // 0=Mon … 6=Sun
  late DateTime _startDate;
  late int _intervalDays;
  late bool _waitForCompletion;
  late List<RoutineReminder> _reminders;
  late bool _manualEntry;

  bool _nameEmpty = true;
  bool _showIconPicker = false;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _iconId = r?.iconId ?? kRoutineIconPresets[0].$1;
    _iconColor = r?.iconColor ?? kRoutineIconPresets[0].$2;
    _goalType = r?.goalType ?? 'achieve_all';
    // Default measurement unit is "count" for new routines.
    final unit = r?.goalUnit ?? 'count';
    _useCustomUnit = !_kUnits.contains(unit);
    _goalUnit = _useCustomUnit ? 'count' : unit;
    _frequencyType = r?.frequencyType ?? 'daily';
    // Default to all days selected so switching to "specific days" starts from
    // a sensible base the user can pare down.
    _weekdays = (r?.weekdays != null && r!.weekdays!.isNotEmpty)
        ? List<int>.from(r.weekdays!)
        : [0, 1, 2, 3, 4, 5, 6];
    final now = DateTime.now();
    _startDate = RoutineController.normalizeDate(
        r?.startDate ?? r?.creationDate ?? now);
    _intervalDays = (r?.intervalDays != null && r!.intervalDays! >= 1)
        ? r.intervalDays!
        : 3;
    _waitForCompletion = r?.waitForCompletion ?? false;
    _reminders = List<RoutineReminder>.from(r?.reminders ?? const []);
    _manualEntry = r?.manualEntry ?? false;

    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _customUnitCtrl =
        TextEditingController(text: _useCustomUnit ? unit : '');
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
    _goalAmountCtrl.dispose();
    _recordAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final goalAmount = int.tryParse(_goalAmountCtrl.text.trim());
    final recordAmount = int.tryParse(_recordAmountCtrl.text.trim());
    final unit = _useCustomUnit
        ? _customUnitCtrl.text.trim().isEmpty
            ? 'count'
            : _customUnitCtrl.text.trim()
        : _goalUnit;

    final specificDays = _frequencyType == 'specific_days';
    final isInterval = _frequencyType == 'interval';
    final isAmount = _goalType == 'certain_amount';
    // Manual entry only applies to amount goals; it replaces per-tap recording.
    final manual = isAmount && _manualEntry;
    final routine = Routine(
      id: widget.existing?.id,
      creationDate: widget.existing?.creationDate,
      iconId: _iconId,
      name: name,
      iconColor: _iconColor,
      goalType: _goalType,
      goalAmount: isAmount ? goalAmount : null,
      goalUnit: isAmount ? unit : null,
      recordAmount: (isAmount && !manual) ? recordAmount : null,
      frequencyType: _frequencyType,
      weekdays: specificDays ? (List<int>.from(_weekdays)..sort()) : null,
      startDate: _startDate,
      intervalDays: isInterval ? _intervalDays : null,
      waitForCompletion: isInterval && _waitForCompletion,
      reminders: _reminders,
      manualEntry: manual,
      // Preserve the manual sort position when editing.
      sortOrder: widget.existing?.sortOrder ?? 0,
    );

    if (widget.existing != null) {
      await widget.controller.updateRoutine(routine);
    } else {
      await widget.controller.addRoutine(routine);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final path = await pickCustomIcon();
      if (!mounted) return;
      if (path != null) setState(() => _iconId = path);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
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

  String _unitLabel(BuildContext context) {
    if (_useCustomUnit) {
      final v = _customUnitCtrl.text.trim();
      return v.isEmpty ? S.of(context).customDots.replaceAll('…', '') : v;
    }
    return _goalUnit;
  }

  Future<void> _pickStartDate() async {
    final picked = await _showDatePicker(context, _startDate);
    if (picked != null && mounted) setState(() => _startDate = picked);
  }

  String _reminderSummary(BuildContext context, RoutineReminder r) {
    final s = S.of(context);
    switch (r.type) {
      case RoutineReminder.typeSpread:
        return '${formatDoTime(r.value)} · ${s.reminderEveryLabel} '
            '${_formatMinutes(r.interval ?? 60)}';
      case RoutineReminder.typeAfterEach:
        return '${_formatMinutes(r.value)} · ${s.reminderAfterEachLabel}';
      case RoutineReminder.typeTime:
      default:
        return formatDoTime(r.value);
    }
  }

  Future<void> _addReminder() async {
    final s = S.of(context);
    final amountGoal = _goalType == 'certain_amount';
    final choice = await showSelectionMenu<String>(
      context: context,
      title: s.addReminder,
      options: [
        SelectionMenuOption(
          value: RoutineReminder.typeTime,
          label: s.reminderTypeTime,
          icon: CupertinoIcons.clock,
        ),
        if (amountGoal)
          SelectionMenuOption(
            value: RoutineReminder.typeSpread,
            label: s.reminderTypeSpread,
            icon: CupertinoIcons.arrow_right_arrow_left,
          ),
        if (amountGoal)
          SelectionMenuOption(
            value: RoutineReminder.typeAfterEach,
            label: s.reminderTypeAfterEach,
            icon: CupertinoIcons.arrow_2_circlepath,
          ),
      ],
    );
    if (choice == null || !mounted) return;

    if (choice == RoutineReminder.typeTime) {
      final minute = await _showTimeOfDayPicker(context, 9 * 60);
      if (minute != null && mounted) {
        _addUniqueReminder(RoutineReminder.time(minute));
      }
    } else if (choice == RoutineReminder.typeSpread) {
      final start = await _showTimeOfDayPicker(context, 9 * 60);
      if (start == null || !mounted) return;
      final every = await _showDurationPicker(context, 120);
      if (every != null && mounted) {
        _addUniqueReminder(
            RoutineReminder.spread(startMinute: start, every: every));
      }
    } else if (choice == RoutineReminder.typeAfterEach) {
      final delay = await _showDurationPicker(context, 120);
      if (delay != null && mounted) {
        _addUniqueReminder(RoutineReminder.afterEach(delay));
      }
    }
  }

  void _addUniqueReminder(RoutineReminder r) {
    if (_reminders.contains(r)) return;
    setState(() => _reminders.add(r));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final accent = AppColors.accent;

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(border: null,
        backgroundColor: bg,
        middle: Text(widget.existing == null ? s.newRoutine : s.editRoutine),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _nameEmpty ? null : _save,
          child: Text(
            s.done,
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
                      picking: _pickingPhoto,
                      onChanged: (iconId, color) => setState(() {
                        _iconId = iconId;
                        _iconColor = color;
                      }),
                      onPickPhoto: _pickPhoto,
                    ),
                  ),
                ],
              ],
            ),

            // ── Frequency ────────────────────────────────────────────────
            _SectionHeader(s.sectionFrequency),
            _Section(children: [
              _SegmentedRow(
                options: [s.freqDaily, s.freqSpecificDays, s.freqInterval],
                selected: _frequencyType == 'daily'
                    ? 0
                    : _frequencyType == 'specific_days'
                        ? 1
                        : 2,
                onChanged: (i) => setState(() => _frequencyType = i == 0
                    ? 'daily'
                    : i == 1
                        ? 'specific_days'
                        : 'interval'),
              ),
              if (_frequencyType == 'specific_days') ...[
                const _Divider(),
                _WeekdayPicker(
                  selected: _weekdays,
                  onChanged: (days) => setState(() => _weekdays = days),
                ),
              ],
              if (_frequencyType == 'interval') ...[
                const _Divider(),
                _IntervalRow(
                  days: _intervalDays,
                  onChanged: (v) => setState(() => _intervalDays = v),
                ),
                const _Divider(),
                _SwitchRow(
                  label: s.waitForCompletion,
                  sublabel: s.waitForCompletionInfo,
                  value: _waitForCompletion,
                  onChanged: (v) => setState(() => _waitForCompletion = v),
                ),
              ],
              const _Divider(),
              _ValueRow(
                label: s.startDate,
                value: formatTaskDateRelative(context, _startDate),
                onTap: _pickStartDate,
              ),
            ]),

            // ── Goal ─────────────────────────────────────────────────────
            _SectionHeader(s.sectionGoal),
            _Section(children: [
              _SegmentedRow(
                options: [s.goalAchieveAll, s.goalCertainAmount],
                selected: _goalType == 'achieve_all' ? 0 : 1,
                onChanged: (i) => setState(() =>
                    _goalType = i == 0 ? 'achieve_all' : 'certain_amount'),
              ),
              if (_goalType == 'certain_amount') ...[
                const _Divider(),
                _AmountRow(
                  label: s.dailyGoal,
                  controller: _goalAmountCtrl,
                  trailingWidget: GestureDetector(
                    onTap: _pickUnit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _unitLabel(context),
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
                    label: s.unitName,
                    controller: _customUnitCtrl,
                    placeholder: s.unitEgGlass,
                  ),
                ],
                const _Divider(),
                _SwitchRow(
                  label: s.recordManual,
                  sublabel: s.recordManualInfo,
                  value: _manualEntry,
                  onChanged: (v) => setState(() => _manualEntry = v),
                ),
                if (!_manualEntry) ...[
                  const _Divider(),
                  _AmountRow(
                    label: s.recordPerTap,
                    controller: _recordAmountCtrl,
                    trailingWidget: Text(
                      _unitLabel(context),
                      style: TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ],
            ]),

            // ── Reminders ─────────────────────────────────────────────────
            _SectionHeader(s.reminders),
            _Section(children: [
              for (int i = 0; i < _reminders.length; i++) ...[
                if (i > 0) const _Divider(),
                _ReminderRow(
                  label: _reminderSummary(context, _reminders[i]),
                  onDelete: () => setState(() => _reminders.removeAt(i)),
                ),
              ],
              if (_reminders.isNotEmpty) const _Divider(),
              _AddRow(label: s.addReminder, onTap: _addReminder),
            ]),
          ],
        ),
        ),
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
            child: RoutineCircleIcon(
              iconId: iconId,
              iconColor: iconColor,
              size: 36,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoTextField(
              controller: nameCtrl,
              placeholder: S.of(context).routineName,
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
    required this.picking,
    required this.onChanged,
    required this.onPickPhoto,
  });

  final String selectedIconId;
  final int selectedColor;
  final bool picking;
  final void Function(String iconId, int color) onChanged;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final customSelected = isCustomIconId(selectedIconId);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...kRoutineIconPresets.map((preset) {
          final (iconId, color) = preset;
          final isSelected =
              !customSelected && iconId == selectedIconId && color == selectedColor;
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
        }),
        // Custom-photo tile: shows the chosen photo when selected, otherwise a
        // dashed "add photo" affordance.
        GestureDetector(
          onTap: picking ? null : onPickPhoto,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              border: customSelected
                  ? Border.all(
                      color: CupertinoColors.label.resolveFrom(context),
                      width: 3,
                    )
                  : Border.all(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 1,
                    ),
            ),
            child: customSelected
                ? RoutineCircleIcon(
                    iconId: selectedIconId,
                    iconColor: selectedColor,
                    size: 44,
                  )
                : Icon(
                    picking ? CupertinoIcons.hourglass : CupertinoIcons.photo,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    size: 20,
                  ),
          ),
        ),
      ],
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
              // Explicit dynamic color: the control inherits the ambient
              // DefaultTextStyle, which in the page body falls back to black
              // and is invisible in dark mode.
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
        },
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// Mon-first weekday toggle row. The currently-selected day can't be the only
// one removed — at least one day must stay selected.
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final List<int> selected;
  final void Function(List<int>) onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent;
    final labels = weekdaysShort(context);
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
                // Never let the user deselect the last remaining day.
                if (next.length > 1) next.remove(i);
              } else {
                next.add(i);
              }
              onChanged(next);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isOn
                    ? accent
                    : CupertinoColors.tertiarySystemFill.resolveFrom(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  labels[i].substring(0, 1),
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

// Stepper row for the interval length ("Every N days").
class _IntervalRow extends StatelessWidget {
  const _IntervalRow({required this.days, required this.onChanged});

  final int days;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Text(s.routineIntervalEvery, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          _StepButton(
            icon: CupertinoIcons.minus,
            onTap: days > 1 ? () => onChanged(days - 1) : null,
          ),
          SizedBox(
            width: 64,
            child: Text(
              s.routineIntervalDays(days),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          _StepButton(
            icon: CupertinoIcons.plus,
            onTap: days < 365 ? () => onChanged(days + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? AppColors.accent
              : CupertinoColors.tertiaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sublabel;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            activeColor: AppColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
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
            Text(label, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            Text(
              value,
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

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.label, required this.onDelete});

  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(CupertinoIcons.bell,
              size: 17, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Icon(CupertinoIcons.minus_circle_fill,
                size: 20, color: CupertinoColors.systemRed.resolveFrom(context)),
          ),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
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
            Icon(CupertinoIcons.add_circled, size: 19, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontSize: 15, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

// ── Pickers / formatting ─────────────────────────────────────────────────────

String _formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

Future<DateTime?> _showDatePicker(BuildContext context, DateTime initial) {
  DateTime selected = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) => _PickerScaffold(
      onCancel: () => Navigator.of(ctx).pop(),
      onDone: () => Navigator.of(ctx).pop(
          RoutineController.normalizeDate(selected)),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: initial,
        onDateTimeChanged: (d) => selected = d,
      ),
    ),
  );
}

Future<int?> _showTimeOfDayPicker(BuildContext context, int initialMinute) {
  final base = DateTime(2026, 1, 1, initialMinute ~/ 60, initialMinute % 60);
  DateTime selected = base;
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (ctx) => _PickerScaffold(
      onCancel: () => Navigator.of(ctx).pop(),
      onDone: () =>
          Navigator.of(ctx).pop(selected.hour * 60 + selected.minute),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: base,
        use24hFormat: TimeFormatPref.use24h,
        onDateTimeChanged: (d) => selected = d,
      ),
    ),
  );
}

Future<int?> _showDurationPicker(BuildContext context, int initialMinutes) {
  Duration selected = Duration(minutes: initialMinutes);
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (ctx) => _PickerScaffold(
      onCancel: () => Navigator.of(ctx).pop(),
      onDone: () => Navigator.of(ctx)
          .pop(selected.inMinutes > 0 ? selected.inMinutes : 1),
      child: CupertinoTimerPicker(
        mode: CupertinoTimerPickerMode.hm,
        initialTimerDuration: selected,
        onTimerDurationChanged: (d) => selected = d,
      ),
    ),
  );
}

class _PickerScaffold extends StatelessWidget {
  const _PickerScaffold({
    required this.child,
    required this.onCancel,
    required this.onDone,
  });

  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final sep = CupertinoColors.separator.resolveFrom(context);
    return Container(
      height: 300,
      color: bg,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: sep, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: onCancel,
                    child: Text(S.of(context).cancel),
                  ),
                  CupertinoButton(
                    onPressed: onDone,
                    child: Text(
                      S.of(context).done,
                      style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                S.of(context).chooseUnit,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
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
                            Icon(CupertinoIcons.checkmark,
                                size: 16, color: AppColors.accent),
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
                        Text(S.of(context).customDots,
                            style: const TextStyle(fontSize: 16)),
                        const Spacer(),
                        if (_showCustom)
                          Icon(CupertinoIcons.checkmark,
                              size: 16, color: AppColors.accent),
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
                placeholder: S.of(context).unitName,
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
                  child: Text(S.of(context).confirm),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
