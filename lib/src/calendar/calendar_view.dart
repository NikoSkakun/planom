import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../models/event.dart';
import '../models/task.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_menu.dart';
import '../settings/settings_view.dart';
import '../tasks/task_controller.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import 'day_view_sheet.dart';
import 'event_controller.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.eventController,
    required this.resetSignal,
    this.settingsController,
    this.backupService,
    this.onDaySelected,
  });

  final TaskController controller;
  final FolderController folderController;
  final EventController eventController;
  final ValueNotifier<int> resetSignal;
  final SettingsController? settingsController;
  final BackupService? backupService;
  final ValueChanged<DateTime?>? onDaySelected;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView>
    with DropdownOverlayMixin {
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

  /// Scrolls so that the row containing [date] sits near the top of the
  /// visible calendar area, then opens the day sheet.
  Future<void> _openDay(DateTime date) async {
    final monthsFromNow =
        (date.year - _now.year) * 12 + (date.month - _now.month);
    final firstWeekday =
        DateTime(date.year, date.month, 1).weekday - 1; // 0..6
    final weekIndex = (firstWeekday + date.day - 1) ~/ 7;

    // Approximate: month header ~30px, each week row ~88px.
    const headerPx = 30.0;
    const weekPx = 88.0;
    final target = monthsFromNow * _avgMonthPx + headerPx + weekIndex * weekPx;

    if (_scrollCtrl.hasClients) {
      final maxExtent = _scrollCtrl.position.maxScrollExtent;
      final minExtent = _scrollCtrl.position.minScrollExtent;
      final clamped = target.clamp(minExtent, maxExtent);
      _scrollCtrl.animateTo(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return;

    widget.onDaySelected?.call(date);

    await showDayViewSheet(
      context,
      date: date,
      taskController: widget.controller,
      eventController: widget.eventController,
      folderController: widget.folderController,
    );
    if (!mounted) return;
    widget.onDaySelected?.call(null);
  }

  Widget _buildMonth(DateTime month) => ListenableBuilder(
        listenable: Listenable.merge([
          widget.controller,
          widget.folderController,
          widget.eventController,
        ]),
        builder: (context, _) => _MonthSection(
          month: month,
          today: _now,
          controller: widget.controller,
          folderController: widget.folderController,
          eventController: widget.eventController,
          onDayTap: _openDay,
        ),
      );

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => SettingsView(
          controller: widget.settingsController!,
          backupService: widget.backupService,
        ),
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    showDropdown(
      context,
      (dismiss) => SettingsMenuOverlay(
        onDismiss: dismiss,
        onSettings: () {
          dismiss();
          _openSettings(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.settingsController;
    final settingsHidden = sc != null && !sc.isTabVisible(4);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text('$_visibleYear'),
        trailing: settingsHidden
            ? Semantics(
                label: S.of(context).settings,
                button: true,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showSettingsMenu(context),
                  child: const Icon(CupertinoIcons.ellipsis, size: 26),
                ),
              )
            : null,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Row(
        children: weekdaysShort(context)
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
    required this.eventController,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime today;
  final TaskController controller;
  final FolderController folderController;
  final EventController eventController;
  final ValueChanged<DateTime> onDayTap;

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
            '${monthsLong(context)[month.month - 1]} ${month.year}',
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
            eventController: eventController,
            onDayTap: onDayTap,
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
    required this.eventController,
    required this.onDayTap,
  });

  final List<DateTime?> days;
  final DateTime today;
  final TaskController controller;
  final FolderController folderController;
  final EventController eventController;
  final ValueChanged<DateTime> onDayTap;

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
                    eventController: eventController,
                    onTap: day == null ? null : () => onDayTap(day),
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
    required this.eventController,
    required this.onTap,
  });

  final DateTime? date;
  final DateTime today;
  final TaskController controller;
  final FolderController folderController;
  final EventController eventController;
  final VoidCallback? onTap;

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
    final events = eventController.eventsForDate(date!);

    // Order: events first, then incomplete tasks, then completed tasks.
    final chips = <_ChipData>[
      for (final e in events) _ChipData.event(e),
      for (final t in uncompleted) _ChipData.task(t, false),
      for (final t in completed) _ChipData.task(t, true),
    ];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: _isToday
                    ? BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
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
            const SizedBox(height: 2),
            ...chips.take(3).map((c) {
              if (c.isEvent) {
                return _EventChip(
                  title: c.event!.title,
                  isPast: _eventIsPast(c.event!),
                );
              }
              final listColor = c.task!.listId != null
                  ? folderController.listById(c.task!.listId!)?.color
                  : null;
              return _TaskChip(
                task: c.task!,
                completed: c.completed,
                listColor: listColor != null ? Color(listColor) : null,
              );
            }),
            if (chips.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  '+${chips.length - 3}',
                  style: TextStyle(
                    fontSize: 9,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChipData {
  _ChipData.task(Task t, bool c)
      : task = t,
        event = null,
        completed = c;
  _ChipData.event(Event e)
      : task = null,
        event = e,
        completed = false;

  final Task? task;
  final Event? event;
  final bool completed;

  bool get isEvent => event != null;
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
        : (listColor ?? AppColors.accent);

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

class _EventChip extends StatelessWidget {
  const _EventChip({required this.title, this.isPast = false});
  final String title;
  final bool isPast;

  static const _color = Color(0xFF0A84FF);
  static const _pastColor = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: isPast ? _pastColor : _color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9, color: CupertinoColors.white),
      ),
    );
  }
}

bool _eventIsPast(Event event) {
  final now = DateTime.now();
  if (event.doTime != null) {
    final endMinutes = event.doTime! + (event.duration ?? 0);
    return event.date.add(Duration(minutes: endMinutes)).isBefore(now);
  }
  final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
  final today = DateTime(now.year, now.month, now.day);
  return eventDay.isBefore(today);
}
