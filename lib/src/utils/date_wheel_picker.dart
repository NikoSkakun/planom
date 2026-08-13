import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';

/// Modal wheel date picker with a Cancel / Today / Done header.
///
/// Returns the picked day (normalized to midnight), or null when cancelled.
///
/// The "Today" shortcut snaps the wheels back to the current day. A picker
/// opened on a date months away is otherwise a long scroll from today, and the
/// wheels give no other way back. It only shows while the wheels are parked on
/// some other day, and only when today is inside [minimumDate] … [maximumDate].
Future<DateTime?> showDateWheelPicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) {
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (_) => _DateWheelSheet(
      initial: initial,
      minimumDate: minimumDate,
      maximumDate: maximumDate,
    ),
  );
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

class _DateWheelSheet extends StatefulWidget {
  const _DateWheelSheet({
    required this.initial,
    this.minimumDate,
    this.maximumDate,
  });

  final DateTime initial;
  final DateTime? minimumDate;
  final DateTime? maximumDate;

  @override
  State<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<_DateWheelSheet> {
  // The date the wheel is (re)built with. Bumping [_generation] alongside it
  // re-keys the picker, which is what actually moves the wheels — a
  // CupertinoDatePicker only reads initialDateTime when it is first built.
  late DateTime _wheelInitial;
  int _generation = 0;
  // Live wheel value, kept in a notifier so scrolling repaints only the Today
  // button instead of rebuilding (and so resetting) the picker itself.
  late final ValueNotifier<DateTime> _value;

  @override
  void initState() {
    super.initState();
    _wheelInitial = widget.initial;
    _value = ValueNotifier<DateTime>(widget.initial);
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  bool get _todayInRange {
    final today = _dayOf(DateTime.now());
    final min = widget.minimumDate;
    final max = widget.maximumDate;
    if (min != null && today.isBefore(_dayOf(min))) return false;
    if (max != null && today.isAfter(_dayOf(max))) return false;
    return true;
  }

  void _jumpToToday() {
    final today = _dayOf(DateTime.now());
    _value.value = today;
    setState(() {
      _wheelInitial = today;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(s.cancel),
                  ),
                  if (_todayInRange)
                    ValueListenableBuilder<DateTime>(
                      valueListenable: _value,
                      builder: (context, value, _) {
                        final onToday =
                            _dayOf(value) == _dayOf(DateTime.now());
                        if (onToday) return const SizedBox.shrink();
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minSize: 32,
                          onPressed: _jumpToToday,
                          child: Text(
                            s.todayShort,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.accent,
                            ),
                          ),
                        );
                      },
                    ),
                  CupertinoButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_dayOf(_value.value)),
                    child: Text(
                      s.done,
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                key: ValueKey(_generation),
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _wheelInitial,
                minimumDate: widget.minimumDate,
                maximumDate: widget.maximumDate,
                onDateTimeChanged: (d) => _value.value = d,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
