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
    this.settingsController,
    this.backupService,
    this.db,
    this.taskController,
    this.folderController,
    this.noteController,
    this.eventController,
  });

  final RoutineController controller;
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
                ? _DayContent(controller: widget.controller)
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
  const _DayContent({required this.controller});
  final RoutineController controller;

  @override
  State<_DayContent> createState() => _DayContentState();
}

class _DayContentState extends State<_DayContent> {
  DateTime _selected = RoutineController.normalizeDate(DateTime.now());
  bool _completedExpanded = false;

  bool get _isToday =>
      _selected == RoutineController.normalizeDate(DateTime.now());

  void _shiftDay(int delta) {
    final next = DateTime(_selected.year, _selected.month, _selected.day + delta);
    // Don't allow navigating into the future — routines reset daily and
    // future days have no meaning yet.
    if (next.isAfter(RoutineController.normalizeDate(DateTime.now()))) return;
    setState(() => _selected = next);
  }

  void _jumpToToday() {
    setState(() => _selected = RoutineController.normalizeDate(DateTime.now()));
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

    return Column(
      children: [
        _DayNavigator(
          date: _selected,
          isToday: _isToday,
          onPrev: () => _shiftDay(-1),
          onNext: _isToday ? null : () => _shiftDay(1),
          onToday: _isToday ? null : _jumpToToday,
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

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.date,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime date;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final label = formatTaskDateRelative(context, date);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
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
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minSize: 0,
            onPressed: onPrev,
            child: const Icon(CupertinoIcons.chevron_left, size: 20),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minSize: 0,
            onPressed: onNext,
            child: Icon(
              CupertinoIcons.chevron_right,
              size: 20,
              color: onNext == null
                  ? CupertinoColors.quaternaryLabel.resolveFrom(context)
                  : null,
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
