import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

// Formats a task date (and optional time) for display.
String formatTaskDate(DateTime d, {int? doTime}) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final datePart = '${months[d.month - 1]} ${d.day}';
  if (doTime == null) return datePart;
  return '$datePart ${formatDoTime(doTime)}';
}

// Formats minutes-since-midnight as "9:00 AM".
String formatDoTime(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final ampm = h < 12 ? 'AM' : 'PM';
  final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$displayH:${m.toString().padLeft(2, '0')} $ampm';
}

/// Returns null when the user dismissed via barrier (no change intended).
/// Returns (null, null) when "No Date" was tapped.
/// Returns (DateTime, int?) when a date (and optionally time) was chosen.
Future<(DateTime?, int?)?> showCalendarDatePicker(
  BuildContext context, {
  DateTime? initial,
  int? initialDoTime,
}) {
  return showCupertinoDialog<(DateTime?, int?)>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CalendarPickerDialog(
      initial: initial ?? DateTime.now(),
      initialDoTime: initialDoTime,
    ),
  );
}

// Monday-first: Mon=0 … Sun=6
int _mondayOffset(DateTime firstOfMonth) => (firstOfMonth.weekday - 1) % 7;

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

class _CalendarPickerDialog extends StatefulWidget {
  const _CalendarPickerDialog({
    required this.initial,
    required this.initialDoTime,
  });
  final DateTime initial;
  final int? initialDoTime;

  @override
  State<_CalendarPickerDialog> createState() => _CalendarPickerDialogState();
}

class _CalendarPickerDialogState extends State<_CalendarPickerDialog> {
  late DateTime _selected;
  late PageController _pageCtrl;
  int? _doTime;
  bool _showTimePicker = false;

  static final _base = DateTime(DateTime.now().year - 5, 1, 1);
  static const _totalMonths = 120; // 10-year range

  static int _pageOf(DateTime d) =>
      (d.year - _base.year) * 12 + (d.month - _base.month);

  DateTime _monthForPage(int page) =>
      DateTime(_base.year + page ~/ 12, _base.month + page % 12, 1);

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _doTime = widget.initialDoTime;
    _showTimePicker = widget.initialDoTime != null;
    final page = _pageOf(_selected).clamp(0, _totalMonths - 1);
    _pageCtrl = PageController(initialPage: page);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _toggleTime() {
    setState(() {
      _showTimePicker = !_showTimePicker;
      if (_showTimePicker) {
        _doTime ??= 9 * 60; // default 9:00 AM
      } else {
        _doTime = null;
      }
    });
  }

  DateTime _timeAsDateTime() {
    final now = DateTime.now();
    final t = _doTime ?? (9 * 60);
    return DateTime(now.year, now.month, now.day, t ~/ 60, t % 60);
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    const accent = AppColors.accent;
    const pageHeight = 320.0;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Calendar month grid
            SizedBox(
              height: pageHeight,
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _totalMonths,
                itemBuilder: (context, page) {
                  final month = _monthForPage(page);
                  return _MonthGrid(
                    month: month,
                    selected: _selected,
                    accent: accent,
                    onPrev: () => _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                    ),
                    onNext: () => _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                    ),
                    onSelect: (d) => setState(() => _selected = d),
                  );
                },
              ),
            ),
            // Time toggle row
            Container(
              height: 0.5,
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            GestureDetector(
              onTap: _toggleTime,
              child: Container(
                color: bg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 16,
                      color: _showTimePicker
                          ? accent
                          : CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showTimePicker ? formatDoTime(_doTime!) : 'Set time',
                      style: TextStyle(
                        fontSize: 14,
                        color: _showTimePicker
                            ? accent
                            : CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showTimePicker
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      size: 12,
                      color:
                          CupertinoColors.tertiaryLabel.resolveFrom(context),
                    ),
                  ],
                ),
              ),
            ),
            // Inline time picker (animated)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _showTimePicker
                  ? SizedBox(
                      height: 150,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: _timeAsDateTime(),
                        use24hFormat: false,
                        onDateTimeChanged: (dt) => setState(
                          () => _doTime = dt.hour * 60 + dt.minute,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Container(
              height: 0.5,
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: () => Navigator.of(context).pop((null, null)),
                    child: Text(
                      'No Date',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 44,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                Expanded(
                  child: CupertinoButton(
                    onPressed: () =>
                        Navigator.of(context).pop((_selected, _doTime)),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
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

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.accent,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final Color accent;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _rowHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final offset = _mondayOffset(DateTime(month.year, month.month, 1));
    final days = _daysInMonth(month.year, month.month);

    final cells = List<int?>.filled(42, null);
    for (var d = 1; d <= days; d++) {
      cells[offset + d - 1] = d;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  onPressed: onPrev,
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    size: 18,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  onPressed: onNext,
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            child: Row(
              children: _weekdays
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < 6; row++)
            SizedBox(
              height: _rowHeight,
              child: Row(
                children: List.generate(7, (col) {
                  final day = cells[row * 7 + col];
                  if (day == null) {
                    return const Expanded(child: SizedBox.shrink());
                  }
                  final date = DateTime(month.year, month.month, day);
                  final isSel = date.year == selected.year &&
                      date.month == selected.month &&
                      date.day == selected.day;
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onSelect(date),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? accent : null,
                            border: isToday && !isSel
                                ? Border.all(color: accent, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSel || isToday
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSel
                                    ? CupertinoColors.white
                                    : isToday
                                        ? accent
                                        : CupertinoColors.label
                                            .resolveFrom(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
