import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../localization/strings.dart';
import '../models/recurrence.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';

/// Sentinel result wrapping the user's choice. `null` outer = dismissed,
/// `value: null` inner = "No Repeat".
class RecurrenceResult {
  const RecurrenceResult(this.value);
  final Recurrence? value;
}

/// Opens a small picker with the four most common repeats. Returns the
/// chosen [Recurrence] (or `null` value for "No Repeat"), or `null` if the
/// menu was dismissed.
Future<RecurrenceResult?> showRecurrencePicker(
  BuildContext context,
  Recurrence? current,
) async {
  final s = S.of(context);
  final result = await showSelectionMenu<String>(
    context: context,
    title: s.repeat,
    current: _currentKey(current),
    options: [
      SelectionMenuOption(value: 'none', label: s.repeatNone),
      SelectionMenuOption(value: 'daily', label: s.repeatDaily),
      SelectionMenuOption(value: 'weekly', label: s.repeatWeekly),
      SelectionMenuOption(value: 'monthly', label: s.repeatMonthly),
      SelectionMenuOption(value: 'yearly', label: s.repeatYearly),
    ],
  );
  if (result == null) return null;
  Recurrence? base;
  switch (result) {
    case 'none':
      return const RecurrenceResult(null);
    case 'daily':
      base = const Recurrence(type: RecurrenceType.daily);
      break;
    case 'weekly':
      base = const Recurrence(type: RecurrenceType.weekly);
      break;
    case 'monthly':
      base = const Recurrence(type: RecurrenceType.monthly);
      break;
    case 'yearly':
      base = const Recurrence(type: RecurrenceType.yearly);
      break;
    default:
      return null;
  }
  // Preserve the user's existing end date when only the cadence changes —
  // someone editing "Daily, ends Dec 31" → "Weekly" usually wants the same
  // end date carried over. They can clear it from the end-date sheet.
  if (current?.endDate != null) {
    base = base.copyWith(endDate: current!.endDate);
  }
  return RecurrenceResult(base);
}

/// Opens the recurrence end-date sheet. Returns `(value: newRecurrence)` on
/// commit (with the end date set or cleared) or null if dismissed.
///
/// Caller is expected to already have a non-null Recurrence; if they don't,
/// the end-date concept doesn't apply (no repeat).
Future<RecurrenceResult?> showRecurrenceEndDateSheet(
  BuildContext context,
  Recurrence current,
) async {
  return showModalBottomSheet<RecurrenceResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _RecurrenceEndDateSheet(current: current),
  );
}

String _currentKey(Recurrence? r) {
  if (r == null) return 'none';
  return r.type.name;
}

String formatRecurrence(BuildContext context, Recurrence? r) {
  final s = S.of(context);
  if (r == null) return s.repeatNone;
  final cadence = switch (r.type) {
    RecurrenceType.daily => s.repeatDaily,
    RecurrenceType.weekly => s.repeatWeekly,
    RecurrenceType.monthly => s.repeatMonthly,
    RecurrenceType.yearly => s.repeatYearly,
  };
  if (r.endDate != null) {
    return s.repeatUntil(cadence, _formatShortDate(r.endDate!));
  }
  return cadence;
}

String _formatShortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class _RecurrenceEndDateSheet extends StatefulWidget {
  const _RecurrenceEndDateSheet({required this.current});

  final Recurrence current;

  @override
  State<_RecurrenceEndDateSheet> createState() =>
      _RecurrenceEndDateSheetState();
}

class _RecurrenceEndDateSheetState extends State<_RecurrenceEndDateSheet> {
  late DateTime _selected;
  late bool _forever;

  @override
  void initState() {
    super.initState();
    _forever = widget.current.endDate == null;
    final now = DateTime.now();
    _selected = widget.current.endDate ??
        DateTime(now.year, now.month + 2, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final separator = CupertinoColors.separator.resolveFrom(context);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.cancel),
                ),
                Expanded(
                  child: Text(
                    s.repeatEnds,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final next = _forever
                        ? widget.current.copyWith(clearEndDate: true)
                        : widget.current.copyWith(endDate: _selected);
                    Navigator.of(context).pop(RecurrenceResult(next));
                  },
                  child: Text(s.done),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: separator),
          // Forever / Until rows
          _OptionRow(
            label: s.repeatForever,
            selected: _forever,
            onTap: () => setState(() => _forever = true),
          ),
          Container(height: 0.5, color: separator),
          _OptionRow(
            label: s.repeatUntilLabel,
            selected: !_forever,
            onTap: () => setState(() => _forever = false),
            trailing: !_forever
                ? Text(
                    _formatShortDate(_selected),
                    style: TextStyle(color: AppColors.accent, fontSize: 15),
                  )
                : null,
          ),
          if (!_forever) ...[
            Container(height: 0.5, color: separator),
            SizedBox(
              height: 220,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selected,
                minimumDate: DateTime.now()
                    .subtract(const Duration(days: 365 * 10)),
                maximumDate: DateTime.now()
                    .add(const Duration(days: 365 * 50)),
                onDateTimeChanged: (d) =>
                    setState(() => _selected = DateTime(d.year, d.month, d.day)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 16)),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            if (selected)
              Icon(CupertinoIcons.checkmark, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
