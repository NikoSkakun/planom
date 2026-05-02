import 'package:flutter/cupertino.dart';

String formatTaskDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

Future<DateTime?> showCalendarDatePicker(
  BuildContext context, {
  DateTime? initial,
}) {
  return showCupertinoDialog<DateTime?>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CalendarPickerDialog(initial: initial ?? DateTime.now()),
  );
}

// Monday-first: Mon=0 … Sun=6
int _mondayOffset(DateTime firstOfMonth) => (firstOfMonth.weekday - 1) % 7;

int _daysInMonth(int year, int month) =>
    DateTime(year, month == 12 ? year + 1 : year, month == 12 ? 1 : month + 1, 0)
        .day;

class _CalendarPickerDialog extends StatefulWidget {
  const _CalendarPickerDialog({required this.initial});
  final DateTime initial;

  @override
  State<_CalendarPickerDialog> createState() => _CalendarPickerDialogState();
}

class _CalendarPickerDialogState extends State<_CalendarPickerDialog> {
  late DateTime _selected;
  late PageController _pageCtrl;

  static final _base = DateTime(DateTime.now().year - 5, 1, 1);
  static const _totalMonths = 120; // 10-year range

  static int _pageOf(DateTime d) =>
      (d.year - _base.year) * 12 + (d.month - _base.month);

  DateTime _monthForPage(int page) {
    final total = page;
    return DateTime(_base.year + total ~/ 12, _base.month + total % 12, 1);
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    final page = _pageOf(_selected).clamp(0, _totalMonths - 1);
    _pageCtrl = PageController(initialPage: page);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    const accent = Color(0xFFFF4D00);

    // 6 rows × 36 + header 44 + weekday-row 24 + gaps 16 + padding 20 = 316
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
            Container(
              height: 0.5,
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(null),
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
                    onPressed: () => Navigator.of(context).pop(_selected),
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

  // Monday-first
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

    // Build 42-cell grid (always 6 rows) so height is stable across months
    final cells = List<int?>.filled(42, null);
    for (var d = 1; d <= days; d++) {
      cells[offset + d - 1] = d;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navigation header
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
          // Weekday labels
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
          // Day rows — 6 explicit rows so height never clips
          for (var row = 0; row < 6; row++)
            SizedBox(
              height: _rowHeight,
              child: Row(
                children: List.generate(7, (col) {
                  final day = cells[row * 7 + col];
                  if (day == null) return const Expanded(child: SizedBox.shrink());
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
