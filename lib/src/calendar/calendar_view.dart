import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../models/task.dart';
import '../tasks/task_controller.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.resetSignal,
  });

  final TaskController controller;
  final FolderController folderController;
  final ValueNotifier<int> resetSignal;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  static const _pastMonths = 600;
  static const _futureMonths = 600;
  static const _avgMonthPx = 481.0;

  late final DateTime _now;
  late final DateTime _currentMonth;
  late final ScrollController _scrollCtrl;
  final _centerKey = GlobalKey();
  late int _visibleYear;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _currentMonth = DateTime(_now.year, _now.month, 1);
    _visibleYear = _now.year;
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScroll);
    widget.resetSignal.addListener(_scrollToCurrentMonth);
  }

  @override
  void dispose() {
    widget.resetSignal.removeListener(_scrollToCurrentMonth);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final monthsFromNow = (_scrollCtrl.offset / _avgMonthPx).round();
    final epochMonths = _now.year * 12 + _now.month - 1 + monthsFromNow;
    final year = epochMonths ~/ 12;
    if (year != _visibleYear) setState(() => _visibleYear = year);
  }

  void _scrollToCurrentMonth() {
    _scrollCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  DateTime _monthBefore(int n) {
    final e = _now.year * 12 + _now.month - 1 - n;
    return DateTime(e ~/ 12, e % 12 + 1, 1);
  }

  DateTime _monthAfter(int n) {
    final e = _now.year * 12 + _now.month - 1 + n;
    return DateTime(e ~/ 12, e % 12 + 1, 1);
  }

  Widget _buildMonth(DateTime month) => ListenableBuilder(
        listenable:
            Listenable.merge([widget.controller, widget.folderController]),
        builder: (context, _) => _MonthSection(
          month: month,
          today: _now,
          controller: widget.controller,
          folderController: widget.folderController,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text('$_visibleYear'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _WeekdayHeader(),
            Expanded(
              child: CustomScrollView(
                center: _centerKey,
                controller: _scrollCtrl,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildMonth(_monthBefore(i + 1)),
                      childCount: _pastMonths,
                    ),
                  ),
                  SliverToBoxAdapter(
                    key: _centerKey,
                    child: _buildMonth(_currentMonth),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildMonth(_monthAfter(i + 1)),
                      childCount: _futureMonths,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Weekday header ───────────────────────────────────────────────────────────

class _WeekdayHeader extends StatelessWidget {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
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
}

// ─── Month section ────────────────────────────────────────────────────────────

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.month,
    required this.today,
    required this.controller,
    required this.folderController,
  });

  final DateTime month;
  final DateTime today;
  final TaskController controller;
  final FolderController folderController;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  List<DateTime?> _buildGrid() {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = DateTime(month.year, month.month, 1).weekday - 1;
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
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        for (var w = 0; w < grid.length; w += 7)
          _WeekRow(
            days: grid.sublist(w, w + 7),
            today: today,
            controller: controller,
            folderController: folderController,
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
    required this.folderController,
  });

  final List<DateTime?> days;
  final DateTime today;
  final TaskController controller;
  final FolderController folderController;

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
                    folderController: folderController,
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
    required this.folderController,
  });

  final DateTime? date;
  final DateTime today;
  final TaskController controller;
  final FolderController folderController;

  bool get _isToday =>
      date != null &&
      date!.year == today.year &&
      date!.month == today.month &&
      date!.day == today.day;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
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
      );
    }

    final allTasks = controller.tasksForDate(date!);
    final uncompleted = allTasks.where((t) => !t.isCompleted).toList();
    final completed = allTasks.where((t) => t.isCompleted).toList();
    final tasks = [...uncompleted, ...completed];

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
          ...tasks.take(3).map((t) {
            final listColor = t.listId != null
                ? folderController.listById(t.listId!)?.color
                : null;
            return _TaskChip(
              task: t,
              completed: t.isCompleted,
              listColor: listColor != null ? Color(listColor) : null,
            );
          }),
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
  const _TaskChip({
    required this.task,
    this.completed = false,
    this.listColor,
  });

  final Task task;
  final bool completed;
  final Color? listColor;

  @override
  Widget build(BuildContext context) {
    final chipColor = completed
        ? CupertinoColors.systemGrey5.resolveFrom(context)
        : (listColor ?? const Color(0xFFFF4D00));

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          color: completed
              ? CupertinoColors.secondaryLabel.resolveFrom(context)
              : CupertinoColors.white,
        ),
      ),
    );
  }
}
