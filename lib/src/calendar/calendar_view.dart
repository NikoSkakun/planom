import 'package:flutter/cupertino.dart';

import '../models/task.dart';
import '../tasks/task_controller.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.controller,
    required this.resetSignal,
  });

  final TaskController controller;
  /// Incremented by HomeShell when the Calendar tab is re-tapped.
  final ValueNotifier<int> resetSignal;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  static const _pastMonths = 600;
  static const _total = _pastMonths + 1 + 600; // 50 yrs back + current + 50 yrs forward

  late final DateTime _now;
  late final ScrollController _scrollCtrl;
  late final List<double> _cumHeights;
  final _currentMonthKey = GlobalKey();
  late int _visibleYear;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _visibleYear = _now.year;
    _initCumHeights();
    _scrollCtrl = ScrollController(
      initialScrollOffset: _cumHeights[_pastMonths],
    );
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentMonthKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: Duration.zero);
    });
    widget.resetSignal.addListener(_scrollToCurrentMonth);
  }

  @override
  void dispose() {
    widget.resetSignal.removeListener(_scrollToCurrentMonth);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _initCumHeights() {
    _cumHeights = [0.0];
    for (var i = 0; i < _total; i++) {
      _cumHeights.add(_cumHeights.last + _estimatedMonthHeight(_monthAt(i)));
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final idx = _monthIndexAtOffset(_scrollCtrl.offset);
    final year = _monthAt(idx).year;
    if (year != _visibleYear) {
      setState(() => _visibleYear = year);
    }
  }

  int _monthIndexAtOffset(double offset) {
    int lo = 0, hi = _total - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_cumHeights[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  void _scrollToCurrentMonth() {
    _scrollCtrl
        .animateTo(
          _cumHeights[_pastMonths],
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        )
        .then((_) {
      final ctx = _currentMonthKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: Duration.zero);
    });
  }

  DateTime _monthAt(int index) {
    final monthsFromEpoch =
        _now.year * 12 + (_now.month - 1) - _pastMonths + index;
    return DateTime(monthsFromEpoch ~/ 12, monthsFromEpoch % 12 + 1, 1);
  }

  static double _estimatedMonthHeight(DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final numWeeks = ((firstWeekday - 1 + daysInMonth) / 7).ceil();
    // label(41) + weeks×88
    return 41.0 + numWeeks * 88.0;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('$_visibleYear'),
            middle: const Text('Calendar'),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _WeekdayHeaderDelegate(),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final month = _monthAt(i);
                final isCurrent =
                    month.year == _now.year && month.month == _now.month;
                return ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) => _MonthSection(
                    key: isCurrent ? _currentMonthKey : null,
                    month: month,
                    today: _now,
                    controller: widget.controller,
                  ),
                );
              },
              childCount: _total,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ─── Weekday header ───────────────────────────────────────────────────────────

class _WeekdayHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _height = 32.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _height,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Row(
        children: _weekdays
            .map((l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
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
    );
  }

  @override
  bool shouldRebuild(_WeekdayHeaderDelegate old) => true;
}

// ─── Month section ────────────────────────────────────────────────────────────

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    super.key,
    required this.month,
    required this.today,
    required this.controller,
  });

  final DateTime month;
  final DateTime today;
  final TaskController controller;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  List<DateTime?> _buildGrid() {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first: Mon=1→0, Tue=2→1, …, Sun=7→6
    final startOffset = first.weekday - 1;
    final cells = <DateTime?>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final grid = _buildGrid();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${_monthNames[month.month - 1]} ${month.year}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        for (var w = 0; w < grid.length; w += 7)
          _WeekRow(
            days: grid.sublist(w, w + 7),
            today: today,
            controller: controller,
          ),
      ],
    );
  }
}

// ─── Week row ─────────────────────────────────────────────────────────────────

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.days,
    required this.today,
    required this.controller,
  });

  final List<DateTime?> days;
  final DateTime today;
  final TaskController controller;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: days
            .map((day) => Expanded(
                  child: _DayCell(
                    date: day,
                    today: today,
                    controller: controller,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Day cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.controller,
  });

  final DateTime? date;
  final DateTime today;
  final TaskController controller;

  bool get _isToday =>
      date != null &&
      date!.year == today.year &&
      date!.month == today.month &&
      date!.day == today.day;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        constraints: const BoxConstraints(minHeight: 88),
      );
    }

    final tasks = controller.tasksForDate(date!).where((t) => !t.isCompleted).toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 26,
              height: 26,
              decoration: _isToday
                  ? const BoxDecoration(
                      color: Color(0xFFFF4D00),
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Center(
                child: Text(
                  '${date!.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        _isToday ? FontWeight.w700 : FontWeight.normal,
                    color: _isToday
                        ? CupertinoColors.white
                        : CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          ...tasks.take(3).map((t) => _TaskChip(task: t)),
          if (tasks.length > 3)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                '+${tasks.length - 3}',
                style: TextStyle(
                  fontSize: 9,
                  color:
                      CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Task chip ────────────────────────────────────────────────────────────────

class _TaskChip extends StatelessWidget {
  const _TaskChip({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D00),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}
