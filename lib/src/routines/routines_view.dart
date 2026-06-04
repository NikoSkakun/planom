import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show ReorderableListView, ReorderableDelayedDragStartListener;

import '../calendar/event_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../home_shell.dart';
import '../localization/strings.dart';
import '../models/routine.dart';
import '../notes/note_controller.dart';
import '../search/search_pull_scope.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_menu.dart';
import '../tasks/calendar_date_picker.dart' show formatTaskDateRelative;
import '../tasks/task_controller.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'routine_amount_dialog.dart';
import 'routine_controller.dart';
import 'routine_creation_view.dart';
import 'routine_icons.dart';

class RoutinesView extends StatefulWidget {
  const RoutinesView({
    super.key,
    required this.controller,
    this.resetSignal,
    this.settingsController,
    this.backupService,
    this.db,
    this.taskController,
    this.folderController,
    this.noteController,
    this.eventController,
  });

  final RoutineController controller;
  // Bumped when the Routines tab is re-tapped — resets the view to its default
  // state (Day segment, today selected), mirroring the other tabs.
  final ValueNotifier<int>? resetSignal;
  final SettingsController? settingsController;
  final BackupService? backupService;
  final DatabaseService? db;
  final TaskController? taskController;
  final FolderController? folderController;
  final NoteController? noteController;
  final EventController? eventController;

  @override
  State<RoutinesView> createState() => _RoutinesViewState();
}

class _RoutinesViewState extends State<RoutinesView>
    with DropdownOverlayMixin {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.resetSignal?.addListener(_onResetSignal);
  }

  @override
  void didUpdateWidget(covariant RoutinesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) {
      oldWidget.resetSignal?.removeListener(_onResetSignal);
      widget.resetSignal?.addListener(_onResetSignal);
    }
  }

  @override
  void dispose() {
    widget.resetSignal?.removeListener(_onResetSignal);
    super.dispose();
  }

  // Re-tapping the Routines tab returns to the Day segment (the Day content's
  // selected day is reset to today by _DayContent, which listens to the same
  // signal).
  void _onResetSignal() {
    if (!mounted) return;
    if (_tab != 0) setState(() => _tab = 0);
  }

  void _openSettings(BuildContext context) {
    HomeShell.openGlobalSettings(context);
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
    final s = S.of(context);
    final sc = widget.settingsController;
    final settingsHidden = sc != null && !sc.isTabVisible(4);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: CupertinoSlidingSegmentedControl<int>(
          groupValue: _tab,
          children: {
            0: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(s.routinesToday),
            ),
            1: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(s.routinesAll),
            ),
          },
          onValueChanged: (v) {
            if (v != null) setState(() => _tab = v);
          },
        ),
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
        child: _maybeWrapWithSearchPull(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => _tab == 0
                ? _DayContent(
                    controller: widget.controller,
                    resetSignal: widget.resetSignal,
                  )
                : _AllContent(controller: widget.controller),
          ),
        ),
      ),
    );
  }

  Widget _maybeWrapWithSearchPull({required Widget child}) {
    if (widget.db == null ||
        widget.taskController == null ||
        widget.folderController == null ||
        widget.noteController == null ||
        widget.eventController == null) {
      return child;
    }
    return SearchPullScope(
      db: widget.db!,
      taskController: widget.taskController!,
      folderController: widget.folderController!,
      noteController: widget.noteController!,
      eventController: widget.eventController!,
      child: child,
    );
  }
}

// ── Day tab (per-day checklist with history navigation) ──────────────────────

class _DayContent extends StatefulWidget {
  const _DayContent({required this.controller, this.resetSignal});
  final RoutineController controller;
  final ValueNotifier<int>? resetSignal;

  @override
  State<_DayContent> createState() => _DayContentState();
}

class _DayContentState extends State<_DayContent> {
  DateTime _selected = RoutineController.normalizeDate(DateTime.now());
  bool _completedExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.resetSignal?.addListener(_onResetSignal);
  }

  @override
  void didUpdateWidget(covariant _DayContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) {
      oldWidget.resetSignal?.removeListener(_onResetSignal);
      widget.resetSignal?.addListener(_onResetSignal);
    }
  }

  @override
  void dispose() {
    widget.resetSignal?.removeListener(_onResetSignal);
    super.dispose();
  }

  void _onResetSignal() {
    if (!mounted) return;
    final today = RoutineController.normalizeDate(DateTime.now());
    if (_selected != today) setState(() => _selected = today);
    // The selector handles scrolling itself via the same signal.
  }

  void _onDaySelected(DateTime day) {
    final normalized = RoutineController.normalizeDate(day);
    if (normalized != _selected) setState(() => _selected = normalized);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final all = widget.controller.routinesForDate(_selected);
    // Completed routines sink below the still-to-do ones (each group keeps its
    // manual order).
    final incomplete = all
        .where((r) => !widget.controller.isCompletedOnDate(r, _selected))
        .toList();
    final completed = all
        .where((r) => widget.controller.isCompletedOnDate(r, _selected))
        .toList();

    final today = RoutineController.normalizeDate(DateTime.now());
    // Left bound of the selector: the first day with any recorded progress,
    // but always at least the last 7 days (today + 6 past days).
    final weekFloor = DateTime(today.year, today.month, today.day - 6);
    final earliest = widget.controller.earliestEntryDate;
    final firstDate = (earliest != null && earliest.isBefore(weekFloor))
        ? earliest
        : weekFloor;

    return Column(
      children: [
        _DaySelector(
          firstDate: firstDate,
          today: today,
          selected: _selected,
          onSelected: _onDaySelected,
          resetSignal: widget.resetSignal,
        ),
        Expanded(
          child: (incomplete.isEmpty && completed.isEmpty)
              ? _EmptyState(
                  message: s.noRoutinesToday,
                  hint: s.tapPlusFirstAdd,
                )
              : ListView(
                  children: [
                    for (final r in incomplete)
                      _DayRoutineRow(
                        routine: r,
                        controller: widget.controller,
                        date: _selected,
                      ),
                    // Completed routines live under a collapsible section so the
                    // still-to-do list stays the focus.
                    if (completed.isNotEmpty)
                      _CompletedHeader(
                        count: completed.length,
                        expanded: _completedExpanded,
                        onToggle: () => setState(
                            () => _completedExpanded = !_completedExpanded),
                      ),
                    if (_completedExpanded)
                      for (final r in completed)
                        _DayRoutineRow(
                          routine: r,
                          controller: widget.controller,
                          date: _selected,
                        ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Collapsible header that separates completed routines from the to-do ones in
/// the Day view.
class _CompletedHeader extends StatelessWidget {
  const _CompletedHeader({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Icon(
              expanded
                  ? CupertinoIcons.chevron_down
                  : CupertinoIcons.chevron_right,
              size: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 6),
            Text(
              S.of(context).completed.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally scrollable day picker for the Day view. Shows 7 days at a time
/// — today at the right edge with the six previous days to its left — and can
/// be scrolled back to the day of the very first recorded routine progress.
///
/// While the user scrolls, the active day follows the right-most fully visible
/// cell; when the fling settles the row snaps to whole-day boundaries so a
/// clean set of 7 days is always shown.
class _DaySelector extends StatefulWidget {
  const _DaySelector({
    required this.firstDate,
    required this.today,
    required this.selected,
    required this.onSelected,
    this.resetSignal,
  });

  final DateTime firstDate; // normalized; left bound (oldest day)
  final DateTime today; // normalized; right bound (newest day)
  final DateTime selected; // normalized
  final ValueChanged<DateTime> onSelected;
  final ValueNotifier<int>? resetSignal;

  @override
  State<_DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<_DaySelector> {
  static const int _visibleCount = 7;
  final ScrollController _controller = ScrollController();
  late List<DateTime> _days;
  double _cellWidth = 0;
  bool _pendingScrollToEnd = true;

  @override
  void initState() {
    super.initState();
    _rebuildDays();
    widget.resetSignal?.addListener(_scrollToEndAnimated);
  }

  @override
  void didUpdateWidget(covariant _DaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) {
      oldWidget.resetSignal?.removeListener(_scrollToEndAnimated);
      widget.resetSignal?.addListener(_scrollToEndAnimated);
    }
    if (oldWidget.firstDate != widget.firstDate ||
        oldWidget.today != widget.today) {
      _rebuildDays();
      // Date range changed — re-anchor today at the right edge.
      _pendingScrollToEnd = true;
    }
  }

  @override
  void dispose() {
    widget.resetSignal?.removeListener(_scrollToEndAnimated);
    _controller.dispose();
    super.dispose();
  }

  void _rebuildDays() {
    _days = [];
    var d = widget.firstDate;
    while (!d.isAfter(widget.today)) {
      _days.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
  }

  void _scrollToEndAnimated() {
    if (!_controller.hasClients) {
      _pendingScrollToEnd = true;
      return;
    }
    _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Right-most fully visible day index for the current scroll offset.
  int _rightmostIndex() {
    if (_cellWidth <= 0) return _days.length - 1;
    final leftIndex = (_controller.offset / _cellWidth).round();
    return (leftIndex + _visibleCount - 1).clamp(0, _days.length - 1);
  }

  void _updateSelectionFromScroll() {
    if (_cellWidth <= 0 || !_controller.hasClients) return;
    final day = _days[_rightmostIndex()];
    if (day != widget.selected) widget.onSelected(day);
  }

  // After a fling settles, snap so only whole day cells are visible.
  void _snap() {
    if (_cellWidth <= 0 || !_controller.hasClients) return;
    final target = (_controller.offset / _cellWidth).round() * _cellWidth;
    final clamped =
        target.clamp(0.0, _controller.position.maxScrollExtent);
    if ((clamped - _controller.offset).abs() > 0.5) {
      _controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _cellWidth = constraints.maxWidth / _visibleCount;
          // Anchor today at the right edge once the list has laid out (or after
          // the date range changed).
          if (_pendingScrollToEnd) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_controller.hasClients) return;
              _controller.jumpTo(_controller.position.maxScrollExtent);
              _pendingScrollToEnd = false;
            });
          }
          return SizedBox(
            height: 64,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollUpdateNotification) {
                  _updateSelectionFromScroll();
                } else if (n is ScrollEndNotification) {
                  _snap();
                }
                return false;
              },
              child: ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemExtent: _cellWidth,
                itemCount: _days.length,
                itemBuilder: (context, i) {
                  final day = _days[i];
                  return _DayCell(
                    day: day,
                    selected: day == widget.selected,
                    isToday: day == widget.today,
                    onTap: () => widget.onSelected(day),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // weekdaysShort is Monday-first (0=Mon … 6=Sun); DateTime.weekday is 1=Mon.
    final weekday = weekdaysShort(context)[day.weekday - 1];
    final accent = AppColors.accent;
    final Color numberColor;
    if (selected) {
      numberColor = CupertinoColors.white;
    } else if (isToday) {
      numberColor = accent;
    } else {
      numberColor = CupertinoColors.label.resolveFrom(context);
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            weekday,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected
                  ? accent
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? accent : null,
              border: (!selected && isToday)
                  ? Border.all(color: accent, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: numberColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── All tab ──────────────────────────────────────────────────────────────────

class _AllContent extends StatelessWidget {
  const _AllContent({required this.controller});
  final RoutineController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final routines = controller.routines;
    if (routines.isEmpty) {
      return _EmptyState(
        message: s.noRoutinesYet,
        hint: s.tapPlusFirstCreate,
      );
    }
    // Long-press a row to drag it into a new position; the order is shared by
    // the Day view and persisted.
    return ReorderableListView.builder(
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      onReorder: controller.reorderRoutines,
      proxyDecorator: (child, index, animation) => _DragProxy(child: child),
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final r = routines[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(r.id),
          index: index,
          child: _AllRoutineRow(routine: r, controller: controller),
        );
      },
    );
  }
}

/// Cupertino-style lift visual for a dragged routine row (avoids the default
/// Material elevation/decorator).
class _DragProxy extends StatelessWidget {
  const _DragProxy({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

// ── Shared empty state ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.arrow_2_circlepath,
            size: 56,
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day routine row ───────────────────────────────────────────────────────────

class _DayRoutineRow extends StatelessWidget {
  const _DayRoutineRow({
    required this.routine,
    required this.controller,
    required this.date,
  });

  final Routine routine;
  final RoutineController controller;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final isCompleted = controller.isCompletedOnDate(routine, date);
    final progress = controller.progressForDate(routine.id, date);
    final achieveAll = routine.goalType == 'achieve_all';
    final overdue = !isCompleted && controller.isOverdueOn(routine, date);
    final originalDate = overdue ? controller.openOccurrenceDate(routine) : null;

    return Dismissible(
      key: ValueKey(routine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.destructiveRed,
        child: const Icon(CupertinoIcons.delete,
            color: CupertinoColors.white, size: 22),
      ),
      confirmDismiss: (_) async => await _confirmDelete(context),
      onDismissed: (_) => controller.deleteRoutine(routine.id),
      child: GestureDetector(
        onTap: () => _handleTap(context),
        onLongPress: () => _showOptions(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Amount goals: an animated background fill that lingers so a
              // partially-completed routine reads at a glance.
              if (!achieveAll)
                Positioned.fill(
                  child: RoutineProgressFill(
                    fraction: (routine.goalAmount ?? 1) <= 0
                        ? 0
                        : progress / (routine.goalAmount ?? 1),
                    color: Color(routine.iconColor),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    RoutineCircleIcon(
                      iconId: routine.iconId,
                      iconColor: routine.iconColor,
                      dimmed: isCompleted,
                      showCheck: isCompleted && achieveAll,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isCompleted
                                  ? CupertinoColors.secondaryLabel
                                      .resolveFrom(context)
                                  : CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          if (overdue && originalDate != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${S.of(context).overdueLabel} · '
                              '${formatTaskDateRelative(context, originalDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: CupertinoColors.systemRed
                                    .resolveFrom(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!achieveAll) ...[
                      const SizedBox(width: 8),
                      _ProgressBadge(
                        progress: progress,
                        goal: routine.goalAmount ?? 1,
                        unit: routine.goalUnit ?? '',
                        isCompleted: isCompleted,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    // Manual amount entry: prompt for the completed amount instead of stepping.
    if (routine.manualEntry && routine.goalType == 'certain_amount') {
      final amount = await showRoutineAmountDialog(
        context,
        name: routine.name,
        current: controller.progressForDate(routine.id, date),
        unit: routine.goalUnit,
      );
      if (amount != null) controller.setProgress(routine, date, amount);
      return;
    }
    // For an overdue wait-for-completion occurrence, ask whether to record the
    // completion on the occurrence's original day or on the viewed day (which
    // shifts all future occurrences). Only for single-tap (achieve_all) goals —
    // amount goals would otherwise prompt on every partial increment.
    final overdue = routine.goalType == 'achieve_all' &&
        !controller.isCompletedOnDate(routine, date) &&
        controller.isOverdueOn(routine, date);
    final original = controller.openOccurrenceDate(routine);
    if (overdue && original != null) {
      final s = S.of(context);
      final choice = await showSelectionMenu<String>(
        context: context,
        title: s.overdueRoutineBody,
        options: [
          SelectionMenuOption(
            value: 'original',
            label:
                '${s.recordOnOriginalDate} · ${formatTaskDateRelative(context, original)}',
            icon: CupertinoIcons.calendar,
          ),
          SelectionMenuOption(
            value: 'shift',
            label: s.completeTodayShift,
            icon: CupertinoIcons.checkmark_circle,
          ),
        ],
      );
      if (choice == 'original') {
        controller.recordProgress(routine, original);
      } else if (choice == 'shift') {
        controller.recordProgress(routine, date);
      }
      return;
    }
    controller.recordProgress(routine, date);
  }

  Future<bool> _confirmDelete(BuildContext context) {
    final s = S.of(context);
    return confirmHardDelete(
      context,
      title: s.deleteRoutine,
      body: s.deleteRoutineConfirm(routine.name),
    );
  }

  Future<void> _showOptions(BuildContext context) async {
    final s = S.of(context);
    final choice = await showSelectionMenu<String>(
      context: context,
      options: [
        SelectionMenuOption(
          value: 'edit',
          label: s.edit,
          icon: CupertinoIcons.pencil,
        ),
        SelectionMenuOption(
          value: 'delete',
          label: s.delete,
          icon: CupertinoIcons.trash,
          isDestructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    if (choice == 'edit') {
      Navigator.of(context).push(
        FastRoute(
          builder: (_) => RoutineCreationView(
            controller: controller,
            existing: routine,
          ),
        ),
      );
    } else if (choice == 'delete') {
      final ok = await _confirmDelete(context);
      if (ok) controller.deleteRoutine(routine.id);
    }
  }
}

// ── All-tab routine row ───────────────────────────────────────────────────────

class _AllRoutineRow extends StatelessWidget {
  const _AllRoutineRow({required this.routine, required this.controller});

  final Routine routine;
  final RoutineController controller;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(routine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.destructiveRed,
        child: const Icon(CupertinoIcons.delete,
            color: CupertinoColors.white, size: 22),
      ),
      confirmDismiss: (_) async => await _confirmDelete(context),
      onDismissed: (_) => controller.deleteRoutine(routine.id),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          FastRoute(
            builder: (_) => RoutineCreationView(
              controller: controller,
              existing: routine,
            ),
          ),
        ),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              RoutineCircleIcon(
                iconId: routine.iconId,
                iconColor: routine.iconColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(context, routine),
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(BuildContext context, Routine r) {
    final schedule = _scheduleLabel(context, r);
    if (r.goalType == 'certain_amount') {
      final unit = (r.goalUnit ?? '').isNotEmpty ? ' ${r.goalUnit}' : '';
      return '$schedule · ${r.goalAmount ?? 1}$unit';
    }
    return schedule;
  }

  String _scheduleLabel(BuildContext context, Routine r) {
    final s = S.of(context);
    if (r.frequencyType == 'interval') {
      return '${s.routineIntervalEvery} ${s.routineIntervalDays(r.intervalDays ?? 1)}';
    }
    final days = r.weekdays;
    if (r.frequencyType != 'specific_days' ||
        days == null ||
        days.isEmpty ||
        days.length == 7) {
      return s.everyDayLabel;
    }
    final labels = weekdaysShort(context);
    final sorted = [...days]..sort();
    return sorted.map((d) => labels[d]).join(', ');
  }

  Future<bool> _confirmDelete(BuildContext context) {
    final s = S.of(context);
    return confirmHardDelete(
      context,
      title: s.deleteRoutine,
      body: s.deleteRoutineConfirm(routine.name),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.progress,
    required this.goal,
    required this.unit,
    required this.isCompleted,
  });

  final int progress;
  final int goal;
  final String unit;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.systemGreen.withOpacity(0.15)
            : CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$progress/$goal${unit.isNotEmpty ? ' $unit' : ''}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isCompleted
              ? AppColors.systemGreen
              : CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}
