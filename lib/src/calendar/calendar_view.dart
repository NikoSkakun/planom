import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

import '../contacts/contact_controller.dart';
import '../database/database_service.dart';
import '../routines/routine_controller.dart';
import '../folders/folder_controller.dart';
import '../home_shell.dart';
import '../integrations/apple/device_calendar_controller.dart';
import '../integrations/apple/device_event.dart';
import '../integrations/google/google_calendar_controller.dart';
import '../integrations/google/remote_event.dart';
import '../localization/strings.dart';
import '../models/contact.dart';
import '../models/event.dart';
import '../models/task.dart';
import '../notes/note_controller.dart';
import '../search/search_pull_scope.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
import '../tasks/task_controller.dart';
import '../utils/selection_menu.dart';
import '../utils/plus_drag_controller.dart';
import '../utils/plus_drag_payload.dart';
import 'day_view_sheet.dart';
import 'event_controller.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.eventController,
    required this.contactController,
    required this.resetSignal,
    this.settingsController,
    this.backupService,
    this.onDaySelected,
    this.db,
    this.noteController,
    this.routineController,
    this.googleCalendarController,
    this.deviceCalendarController,
  });

  final TaskController controller;
  final FolderController folderController;
  final EventController eventController;
  final ContactController contactController;
  final ValueNotifier<int> resetSignal;
  final SettingsController? settingsController;
  final BackupService? backupService;
  final ValueChanged<DateTime?>? onDaySelected;
  final DatabaseService? db;
  final NoteController? noteController;
  final RoutineController? routineController;
  final GoogleCalendarController? googleCalendarController;
  final DeviceCalendarController? deviceCalendarController;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  static const _pastMonths = 600;
  static const _futureMonths = 600;
  static const _avgMonthPx = 481.0;

  // Continuous (gap-free) view counts weeks instead of months. ~52 years each
  // way. Each week row is ~88px tall (the day-cell min height).
  static const _pastWeeks = 2700;
  static const _futureWeeks = 2700;
  static const _weekPx = 88.0;

  late final DateTime _now;
  late final DateTime _currentMonth;
  late final ScrollController _scrollCtrl;
  final _centerKey = GlobalKey();
  late int _visibleYear;
  int _visibleMonthEpoch = 0;
  Timer? _prefetchDebounce;

  /// The day whose inline preview panel is currently open (null = none). The
  /// calendar above the panel stays interactive: tapping another day re-targets
  /// the panel, tapping the same day again (or the nav-bar title) closes it.
  DateTime? _selectedDate;

  /// Scroll offset captured the moment a day preview is first opened, so that
  /// closing the panel can restore the calendar to exactly where it was before
  /// the tapped day was scrolled to the top. Null while no panel is open.
  double? _scrollOffsetBeforeDay;

  // Mirrored from the settings controller so the sliver structure rebuilds
  // when the user switches view mode or first-day-of-week.
  late CalendarViewMode _viewMode;
  late int _firstDay;

  /// Months on either side of the visible month we eagerly pull from Google.
  /// Sized so a fast scroll has data ready by the time the cells appear.
  static const _prefetchBufferMonths = 3;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _currentMonth = DateTime(_now.year, _now.month, 1);
    _visibleYear = _now.year;
    _visibleMonthEpoch = _now.year * 12 + _now.month - 1;
    _viewMode =
        widget.settingsController?.calendarViewMode ?? CalendarViewMode.months;
    _firstDay = widget.settingsController?.firstDayOfWeek ?? DateTime.monday;
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScroll);
    widget.resetSignal.addListener(_onResetSignal);
    widget.settingsController?.addListener(_onSettingsChanged);
    // Pre-warm Google Calendar around the current month so the user sees
    // events immediately when they open the tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPrefetch(_visibleMonthEpoch);
    });
  }

  @override
  void dispose() {
    widget.resetSignal.removeListener(_onResetSignal);
    widget.settingsController?.removeListener(_onSettingsChanged);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _prefetchDebounce?.cancel();
    super.dispose();
  }

  /// Switching view mode or first-day-of-week changes the whole sliver layout
  /// (month grids vs. continuous weeks), so rebuild and re-anchor to today.
  void _onSettingsChanged() {
    final sc = widget.settingsController;
    if (sc == null) return;
    if (sc.calendarViewMode == _viewMode && sc.firstDayOfWeek == _firstDay) {
      return;
    }
    setState(() {
      _viewMode = sc.calendarViewMode;
      _firstDay = sc.firstDayOfWeek;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0.0);
    });
  }

  /// Start of the week (aligned to [_firstDay]) that contains today. Anchor for
  /// the continuous view's bidirectional scroll.
  DateTime get _anchorWeekStart {
    final col = weekdayColumn(_now, _firstDay);
    return DateTime(_now.year, _now.month, _now.day - col);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final int epochMonths;
    if (_viewMode == CalendarViewMode.continuous) {
      final weeksFromNow = (_scrollCtrl.offset / _weekPx).round();
      final a = _anchorWeekStart;
      // Pick mid-week so the reported month/year matches what's centred.
      final mid = DateTime(a.year, a.month, a.day + weeksFromNow * 7 + 3);
      epochMonths = mid.year * 12 + mid.month - 1;
      if (mid.year != _visibleYear) setState(() => _visibleYear = mid.year);
    } else {
      final monthsFromNow = (_scrollCtrl.offset / _avgMonthPx).round();
      epochMonths = _now.year * 12 + _now.month - 1 + monthsFromNow;
      final year = epochMonths ~/ 12;
      if (year != _visibleYear) setState(() => _visibleYear = year);
    }
    if (epochMonths != _visibleMonthEpoch) {
      _visibleMonthEpoch = epochMonths;
      _requestPrefetch(epochMonths);
    }
  }

  /// Asks the Google Calendar controller to make sure events around
  /// [centerMonthEpoch] are loaded. Debounced so a flick-scroll doesn't fire
  /// dozens of fetches; the trailing call wins.
  void _requestPrefetch(int centerMonthEpoch) {
    final gcal = widget.googleCalendarController;
    final ekcal = widget.deviceCalendarController;
    final wantGoogle = gcal != null && gcal.isConnected;
    final wantDevice = ekcal != null && ekcal.isConnected;
    if (!wantGoogle && !wantDevice) return;
    _prefetchDebounce?.cancel();
    _prefetchDebounce = Timer(const Duration(milliseconds: 250), () {
      final startEpoch = centerMonthEpoch - _prefetchBufferMonths;
      final endEpoch = centerMonthEpoch + _prefetchBufferMonths;
      final from = DateTime(startEpoch ~/ 12, startEpoch % 12 + 1, 1);
      final to = DateTime(endEpoch ~/ 12, endEpoch % 12 + 1 + 1, 1);
      // Fire and forget; the controllers notify listeners after merging.
      if (wantGoogle) unawaited(gcal.ensureRangeLoaded(from, to));
      if (wantDevice) unawaited(ekcal.ensureRangeLoaded(from, to));
    });
  }

  /// Re-tapping the Calendar tab fully resets the view: any open day-preview
  /// panel is closed and the grid scrolls back to the current month — matching
  /// the pop-to-root behaviour of the other tabs.
  void _onResetSignal() {
    // The reset jumps to the current month, so don't also restore the
    // pre-open scroll position — that would fight the scroll-to-today animation.
    _closeDay(restoreScroll: false);
    _scrollToCurrentMonth();
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

  bool _isSameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  /// Tapping a day toggles its inline preview panel: a new day opens (and the
  /// row scrolls into view), the already-open day closes.
  void _openDay(DateTime date) {
    if (_isSameDay(_selectedDate, date)) {
      _closeDay();
      return;
    }
    // Capture the scroll position only when opening from a closed state, so
    // re-targeting from one open day to another keeps the original "before"
    // position to restore on close.
    if (_selectedDate == null && _scrollCtrl.hasClients) {
      _scrollOffsetBeforeDay = _scrollCtrl.offset;
    }
    setState(() => _selectedDate = date);
    widget.onDaySelected?.call(date);
    _scrollToDate(date);
  }

  void _closeDay({bool restoreScroll = true}) {
    if (_selectedDate == null) return;
    setState(() => _selectedDate = null);
    widget.onDaySelected?.call(null);

    final saved = _scrollOffsetBeforeDay;
    _scrollOffsetBeforeDay = null;
    if (!restoreScroll || saved == null) return;
    // Restore after the panel is removed so the scroll viewport has grown back
    // to its full height before we clamp/animate to the saved offset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final clamped = saved.clamp(
        _scrollCtrl.position.minScrollExtent,
        _scrollCtrl.position.maxScrollExtent,
      );
      _scrollCtrl.animateTo(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Scrolls so that the row containing [date] sits near the top of the
  /// visible calendar area.
  void _scrollToDate(DateTime date) {
    final double target;
    if (_viewMode == CalendarViewMode.continuous) {
      final weekStart = DateTime(
          date.year, date.month, date.day - weekdayColumn(date, _firstDay));
      // Round to absorb DST hour drift in the day difference.
      final weeks =
          (weekStart.difference(_anchorWeekStart).inDays / 7).round();
      target = weeks * _weekPx;
    } else {
      final monthsFromNow =
          (date.year - _now.year) * 12 + (date.month - _now.month);
      final firstWeekday =
          weekdayColumn(DateTime(date.year, date.month, 1), _firstDay);
      final weekIndex = (firstWeekday + date.day - 1) ~/ 7;
      // Approximate: month header ~30px, each week row ~88px.
      const headerPx = 30.0;
      target = monthsFromNow * _avgMonthPx + headerPx + weekIndex * _weekPx;
    }

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
  }

  Listenable get _dataListenable => Listenable.merge([
        widget.controller,
        widget.folderController,
        widget.eventController,
        widget.contactController,
        if (widget.googleCalendarController != null)
          widget.googleCalendarController!,
        if (widget.deviceCalendarController != null)
          widget.deviceCalendarController!,
        if (widget.settingsController != null) widget.settingsController!,
      ]);

  Widget _buildMonth(DateTime month) => ListenableBuilder(
        listenable: _dataListenable,
        builder: (context, _) => _MonthSection(
          month: month,
          today: _now,
          selected: _selectedDate,
          firstDayOfWeek: _firstDay,
          controller: widget.controller,
          folderController: widget.folderController,
          eventController: widget.eventController,
          contactController: widget.contactController,
          googleCalendarController: widget.googleCalendarController,
          deviceCalendarController: widget.deviceCalendarController,
          onDayTap: _openDay,
        ),
      );

  /// One continuous-view week row of 7 consecutive days, [weekStart] aligned
  /// to [_firstDay].
  Widget _buildWeek(DateTime weekStart) => ListenableBuilder(
        listenable: _dataListenable,
        builder: (context, _) => _WeekRow(
          days: [
            for (var i = 0; i < 7; i++)
              DateTime(weekStart.year, weekStart.month, weekStart.day + i),
          ],
          today: _now,
          selected: _selectedDate,
          continuous: true,
          firstDayOfWeek: _firstDay,
          controller: widget.controller,
          folderController: widget.folderController,
          eventController: widget.eventController,
          contactController: widget.contactController,
          googleCalendarController: widget.googleCalendarController,
          deviceCalendarController: widget.deviceCalendarController,
          onDayTap: _openDay,
        ),
      );

  DateTime _weekStartBefore(int n) {
    final a = _anchorWeekStart;
    return DateTime(a.year, a.month, a.day - n * 7);
  }

  DateTime _weekStartAfter(int n) {
    final a = _anchorWeekStart;
    return DateTime(a.year, a.month, a.day + n * 7);
  }

  void _openSettings(BuildContext context) {
    HomeShell.openGlobalSettings(context);
  }

  Future<void> _showCalendarMenu(BuildContext context) async {
    final sc = widget.settingsController;
    final settingsHidden = sc != null && !sc.isTabVisible(4);
    final s = S.of(context);
    final action = await showSelectionMenu<String>(
      context: context,
      anchor: SelectionMenuAnchor.topRight,
      options: [
        SelectionMenuOption(
          value: 'view',
          label: s.calendarView,
          icon: CupertinoIcons.calendar,
        ),
        if (settingsHidden)
          SelectionMenuOption(
            value: 'settings',
            label: s.settings,
            icon: CupertinoIcons.gear_alt,
          ),
      ],
    );
    if (!context.mounted) return;
    if (action == 'view') {
      await _showViewModeMenu(context);
    } else if (action == 'settings') {
      _openSettings(context);
    }
  }

  Future<void> _showViewModeMenu(BuildContext context) async {
    final sc = widget.settingsController;
    final s = S.of(context);
    final mode = await showSelectionMenu<CalendarViewMode>(
      context: context,
      anchor: SelectionMenuAnchor.topRight,
      title: s.calendarView,
      current: _viewMode,
      options: [
        SelectionMenuOption(
          value: CalendarViewMode.months,
          label: s.calendarViewMonths,
          icon: CupertinoIcons.calendar,
        ),
        SelectionMenuOption(
          value: CalendarViewMode.continuous,
          label: s.calendarViewContinuous,
          icon: CupertinoIcons.list_bullet,
        ),
      ],
    );
    if (mode == null) return;
    if (sc != null) {
      // Persists + notifies → _onSettingsChanged rebuilds and re-anchors.
      await sc.updateCalendarViewMode(mode);
    } else if (mode != _viewMode) {
      setState(() => _viewMode = mode);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        // Tapping the title closes an open day preview (one of the two ways to
        // dismiss it, alongside re-tapping the selected day).
        middle: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _selectedDate != null ? _closeDay : null,
          child: Text('$_visibleYear'),
        ),
        trailing: Semantics(
          label: S.of(context).calendarView,
          button: true,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showCalendarMenu(context),
            child: const Icon(CupertinoIcons.ellipsis, size: 26),
          ),
        ),
      ),
      child: SafeArea(
        child: _maybeWrapWithSearchPull(
          child: Column(
          children: [
            ListenableBuilder(
              listenable: widget.settingsController ??
                  const _NeverNotifier(),
              builder: (_, __) => _WeekdayHeader(
                firstDayOfWeek: widget.settingsController?.firstDayOfWeek ??
                    DateTime.monday,
              ),
            ),
            Expanded(
              child: CustomScrollView(
                // Re-key per mode so switching layouts rebuilds the scroll
                // structure cleanly (the controller re-attaches and we jump
                // back to the current anchor post-frame).
                key: ValueKey(_viewMode),
                center: _centerKey,
                controller: _scrollCtrl,
                slivers: _viewMode == CalendarViewMode.continuous
                    ? _continuousSlivers()
                    : _monthSlivers(),
              ),
            ),
            if (_selectedDate != null)
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.42)
                    .clamp(280.0, 560.0),
                child: DayViewSheet(
                  key: ValueKey(_selectedDate),
                  date: _selectedDate!,
                  embedded: true,
                  onClose: _closeDay,
                  taskController: widget.controller,
                  eventController: widget.eventController,
                  folderController: widget.folderController,
                  contactController: widget.contactController,
                  settingsController: widget.settingsController,
                  routineController: widget.routineController,
                  googleCalendarController: widget.googleCalendarController,
                  deviceCalendarController: widget.deviceCalendarController,
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  List<Widget> _monthSlivers() => [
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
      ];

  List<Widget> _continuousSlivers() => [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _buildWeek(_weekStartBefore(i + 1)),
            childCount: _pastWeeks,
          ),
        ),
        SliverToBoxAdapter(
          key: _centerKey,
          child: _buildWeek(_anchorWeekStart),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _buildWeek(_weekStartAfter(i + 1)),
            childCount: _futureWeeks,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ];

  Widget _maybeWrapWithSearchPull({required Widget child}) {
    if (widget.db == null || widget.noteController == null) return child;
    return SearchPullScope(
      db: widget.db!,
      taskController: widget.controller,
      folderController: widget.folderController,
      noteController: widget.noteController!,
      eventController: widget.eventController,
      child: child,
    );
  }
}

// ─── Weekday header ───────────────────────────────────────────────────────────

class _NeverNotifier extends Listenable {
  const _NeverNotifier();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.firstDayOfWeek});

  final int firstDayOfWeek;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Row(
        children:
            rotateWeekdays(weekdaysShort(context), firstDayOfWeek)
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
    required this.selected,
    required this.firstDayOfWeek,
    required this.controller,
    required this.folderController,
    required this.eventController,
    required this.contactController,
    required this.googleCalendarController,
    required this.deviceCalendarController,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? selected;
  final int firstDayOfWeek;
  final TaskController controller;
  final FolderController folderController;
  final EventController eventController;
  final ContactController contactController;
  final GoogleCalendarController? googleCalendarController;
  final DeviceCalendarController? deviceCalendarController;
  final ValueChanged<DateTime> onDayTap;

  List<DateTime?> _buildGrid() {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset =
        weekdayColumn(DateTime(month.year, month.month, 1), firstDayOfWeek);
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
            selected: selected,
            controller: controller,
            folderController: folderController,
            eventController: eventController,
            contactController: contactController,
            googleCalendarController: googleCalendarController,
            deviceCalendarController: deviceCalendarController,
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
    required this.selected,
    required this.controller,
    required this.folderController,
    required this.eventController,
    required this.contactController,
    required this.googleCalendarController,
    required this.deviceCalendarController,
    required this.onDayTap,
    this.continuous = false,
    this.firstDayOfWeek = DateTime.monday,
  });

  final List<DateTime?> days;
  final DateTime today;
  final DateTime? selected;
  final TaskController controller;
  final FolderController folderController;
  final EventController eventController;
  final ContactController contactController;
  final GoogleCalendarController? googleCalendarController;
  final DeviceCalendarController? deviceCalendarController;
  final ValueChanged<DateTime> onDayTap;

  /// In the continuous (gap-free) view, day cells mark the 1st of each month
  /// with an inline month label and draw a semi-bold divider where one month
  /// ends and the next begins.
  final bool continuous;
  final int firstDayOfWeek;

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
                    selected: selected,
                    continuous: continuous,
                    firstDayOfWeek: firstDayOfWeek,
                    controller: controller,
                    folderController: folderController,
                    eventController: eventController,
                    contactController: contactController,
                    googleCalendarController: googleCalendarController,
                    deviceCalendarController: deviceCalendarController,
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
    required this.selected,
    required this.controller,
    required this.folderController,
    required this.eventController,
    required this.contactController,
    required this.googleCalendarController,
    required this.deviceCalendarController,
    required this.onTap,
    this.continuous = false,
    this.firstDayOfWeek = DateTime.monday,
  });

  final DateTime? date;
  final DateTime today;
  final DateTime? selected;
  final bool continuous;
  final int firstDayOfWeek;
  final TaskController controller;
  final FolderController folderController;
  final EventController eventController;
  final ContactController contactController;
  final GoogleCalendarController? googleCalendarController;
  final DeviceCalendarController? deviceCalendarController;
  final VoidCallback? onTap;

  /// Fixed height for every day cell so all calendar rows are uniform. Sized to
  /// hold the day label plus four content rows (3 chips + a "+N" indicator).
  static const _cellHeight = 88.0;

  bool get _isToday =>
      date != null &&
      date!.year == today.year &&
      date!.month == today.month &&
      date!.day == today.day;

  bool get _isSelected =>
      date != null &&
      selected != null &&
      date!.year == selected!.year &&
      date!.month == selected!.month &&
      date!.day == selected!.day;

  /// Cell border. In the continuous view a semi-bold line marks the month
  /// boundary: the new month's first-week cells get a heavier top edge (the
  /// cell directly above them, 7 days earlier, belongs to the previous month),
  /// and the 1st itself gets a heavier left edge so the stepped divider stays
  /// connected where the boundary falls mid-row.
  Border _cellBorder(BuildContext context) {
    final faint = BorderSide(
      color: CupertinoColors.separator.resolveFrom(context),
      width: 0.5,
    );
    if (!continuous || date == null) return Border(top: faint);

    final divider = BorderSide(
      color: CupertinoColors.systemGrey2.resolveFrom(context),
      width: 1.5,
    );
    // day <= 7 ⟺ the cell 7 days earlier is in the previous month.
    final isMonthStartRow = date!.day <= 7;
    final needsLeftConnector =
        date!.day == 1 && weekdayColumn(date!, firstDayOfWeek) != 0;
    return Border(
      top: isMonthStartRow ? divider : faint,
      left: needsLeftConnector ? divider : BorderSide.none,
    );
  }

  /// The day number, wrapped in the highlight band when applicable. In the
  /// continuous view, the 1st of each month is prefixed with the month's short
  /// name so month boundaries read clearly without a separating header.
  Widget _buildDayLabel(BuildContext context) {
    // Highlight priority: the selected day gets the strong accent band; an
    // unselected today gets a blue band so it still stands out without
    // competing with the selection.
    final selectedHere = _isSelected;
    final Color? fillColor;
    final Color textColor;
    final FontWeight weight;
    if (selectedHere) {
      fillColor = AppColors.accent;
      textColor = CupertinoColors.white;
      weight = FontWeight.w700;
    } else if (_isToday) {
      fillColor = CupertinoColors.systemBlue.resolveFrom(context);
      textColor = CupertinoColors.white;
      weight = FontWeight.w700;
    } else {
      fillColor = null;
      textColor = CupertinoColors.label.resolveFrom(context);
      weight = FontWeight.normal;
    }

    final numberStyle = TextStyle(
      fontSize: 12,
      fontWeight: weight,
      color: textColor,
    );

    // Continuous view marks the 1st of each month with an inline month label;
    // keep a compact pill there so the month name still fits beside the number.
    if (continuous && date!.day == 1) {
      final numberPill = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: fillColor != null
            ? BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(100),
              )
            : null,
        child: Text('${date!.day}', style: numberStyle),
      );
      return Align(
        alignment: Alignment.topCenter,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                monthsShort(context)[date!.month - 1],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 3),
            numberPill,
          ],
        ),
      );
    }

    // Standard cell: the highlight band stretches to (nearly) the full cell
    // width — keeping a small horizontal gap from neighbouring cells — and is
    // kept short vertically. A very large radius gives full semicircular caps
    // at the left and right ends (stadium shape).
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(vertical: 1),
      alignment: Alignment.center,
      decoration: fillColor != null
          ? BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(100),
            )
          : null,
      child: Text('${date!.day}', style: numberStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Container(
        height: _cellHeight,
        decoration: BoxDecoration(border: _cellBorder(context)),
      );
    }

    final allTasks = controller.tasksForDate(date!);
    final birthdays = contactController.contactsForDate(date!);
    final uncompleted = allTasks.where((t) => !t.isCompleted).toList();
    final completed = allTasks.where((t) => t.isCompleted).toList();
    final events = eventController.eventsForDate(date!);
    final remoteEvents =
        googleCalendarController?.eventsForDate(date!) ?? const <RemoteEvent>[];
    final deviceEvents =
        deviceCalendarController?.eventsForDate(date!) ?? const <DeviceEvent>[];

    // Order: events first (local Planom, then Google, then Apple Calendar),
    // then birthdays, then incomplete tasks, then completed tasks. Remote and
    // device events render with their calendar color so different calendars
    // stay visually distinct.
    final chips = <_ChipData>[
      for (final e in events) _ChipData.event(e),
      for (final e in remoteEvents) _ChipData.remoteEvent(e),
      for (final e in deviceEvents) _ChipData.deviceEvent(e),
      for (final b in birthdays) _ChipData.birthday(b),
      for (final t in uncompleted) _ChipData.task(t, false),
      for (final t in completed) _ChipData.task(t, true),
    ];

    // All cells are a fixed height, so a day holds at most 4 content rows:
    // 3 chips plus a "+N" overflow indicator once there are more than 3 items.
    final visibleCount = chips.length <= 3 ? chips.length : 3;
    final overflowCount = chips.length - visibleCount;

    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) =>
          PlusDragScope.of(context)?.onDropOnDay?.call(date!),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _cellHeight,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: highlighted ? AppColors.accent.withOpacity(0.15) : null,
          border: _cellBorder(context),
        ),
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDayLabel(context),
            const SizedBox(height: 2),
            ...chips.take(visibleCount).map((c) {
              if (c.isEvent) {
                return _EventChip(
                  title: c.event!.title,
                  isPast: _eventIsPast(c.event!),
                );
              }
              if (c.isRemoteEvent) {
                return _RemoteEventChip(
                  title: c.remoteEvent!.title,
                  color: Color(c.remoteEvent!.calendarColor),
                  isPast: _remoteEventIsPast(c.remoteEvent!),
                );
              }
              if (c.isDeviceEvent) {
                return _RemoteEventChip(
                  title: c.deviceEvent!.title,
                  color: Color(c.deviceEvent!.calendarColor),
                  isPast: _deviceEventIsPast(c.deviceEvent!),
                );
              }
              if (c.isBirthday) {
                return _BirthdayChip(title: c.birthday!.name);
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
            if (overflowCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  '+$overflowCount',
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
      },
    );
  }
}

class _ChipData {
  _ChipData.task(Task t, bool c)
      : task = t,
        event = null,
        remoteEvent = null,
        deviceEvent = null,
        birthday = null,
        completed = c;
  _ChipData.event(Event e)
      : task = null,
        event = e,
        remoteEvent = null,
        deviceEvent = null,
        birthday = null,
        completed = false;
  _ChipData.remoteEvent(RemoteEvent e)
      : task = null,
        event = null,
        remoteEvent = e,
        deviceEvent = null,
        birthday = null,
        completed = false;
  _ChipData.deviceEvent(DeviceEvent e)
      : task = null,
        event = null,
        remoteEvent = null,
        deviceEvent = e,
        birthday = null,
        completed = false;
  _ChipData.birthday(Contact b)
      : task = null,
        event = null,
        remoteEvent = null,
        deviceEvent = null,
        birthday = b,
        completed = false;

  final Task? task;
  final Event? event;
  final RemoteEvent? remoteEvent;
  final DeviceEvent? deviceEvent;
  final Contact? birthday;
  final bool completed;

  bool get isEvent => event != null;
  bool get isRemoteEvent => remoteEvent != null;
  bool get isDeviceEvent => deviceEvent != null;
  bool get isBirthday => birthday != null;
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

class _BirthdayChip extends StatelessWidget {
  const _BirthdayChip({required this.title});
  final String title;

  static const _color = Color(0xFFFF2D55); // birthday pink

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.gift_fill,
              size: 8, color: CupertinoColors.white),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9, color: CupertinoColors.white),
            ),
          ),
        ],
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

bool _remoteEventIsPast(RemoteEvent event) {
  final now = DateTime.now();
  if (event.doTime != null) {
    final endMinutes = event.doTime! + (event.duration ?? 0);
    return event.date.add(Duration(minutes: endMinutes)).isBefore(now);
  }
  final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
  final today = DateTime(now.year, now.month, now.day);
  return eventDay.isBefore(today);
}

bool _deviceEventIsPast(DeviceEvent event) {
  final now = DateTime.now();
  if (event.doTime != null) {
    final endMinutes = event.doTime! + (event.duration ?? 0);
    return event.date.add(Duration(minutes: endMinutes)).isBefore(now);
  }
  final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
  final today = DateTime(now.year, now.month, now.day);
  return eventDay.isBefore(today);
}

/// Chip for a Google Calendar event. Uses the calendar's color so different
/// connected calendars stay visually distinct.
class _RemoteEventChip extends StatelessWidget {
  const _RemoteEventChip({
    required this.title,
    required this.color,
    this.isPast = false,
  });

  final String title;
  final Color color;
  final bool isPast;

  static const _pastColor = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: isPast ? _pastColor : color,
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
