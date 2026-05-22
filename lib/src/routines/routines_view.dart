import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/routine.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_view.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'routine_controller.dart';
import 'routine_creation_view.dart';
import 'routine_icons.dart';

class RoutinesView extends StatefulWidget {
  const RoutinesView({
    super.key,
    required this.controller,
    this.settingsController,
    this.backupService,
  });

  final RoutineController controller;
  final SettingsController? settingsController;
  final BackupService? backupService;

  @override
  State<RoutinesView> createState() => _RoutinesViewState();
}

class _RoutinesViewState extends State<RoutinesView> {
  int _tab = 0;

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
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _openSettings(context),
                child: const Icon(CupertinoIcons.ellipsis, size: 26),
              )
            : null,
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => _tab == 0
              ? _TodayContent(controller: widget.controller)
              : _AllContent(controller: widget.controller),
        ),
      ),
    );
  }
}

// ── Today tab ────────────────────────────────────────────────────────────────

class _TodayContent extends StatelessWidget {
  const _TodayContent({required this.controller});
  final RoutineController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final routines = controller.todayRoutines;
    if (routines.isEmpty) {
      return _EmptyState(
        message: s.noRoutinesToday,
        hint: s.tapPlusFirstAdd,
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              s.routinesTodaySection,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _TodayRoutineRow(
              routine: routines[index],
              controller: controller,
            ),
            childCount: routines.length,
          ),
        ),
      ],
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
    return ListView.builder(
      itemCount: routines.length,
      itemBuilder: (context, index) => _AllRoutineRow(
        routine: routines[index],
        controller: controller,
      ),
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

// ── Today routine row ─────────────────────────────────────────────────────────

class _TodayRoutineRow extends StatelessWidget {
  const _TodayRoutineRow({required this.routine, required this.controller});

  final Routine routine;
  final RoutineController controller;

  @override
  Widget build(BuildContext context) {
    final isCompleted = controller.isTodayCompleted(routine);
    final progress = controller.todayProgress(routine.id);

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
        onTap: () => controller.recordProgress(routine),
        onLongPress: () => _showOptions(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
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
              _RoutineIcon(routine: routine, isCompleted: isCompleted),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  routine.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isCompleted
                        ? CupertinoColors.secondaryLabel.resolveFrom(context)
                        : CupertinoColors.label.resolveFrom(context),
                    decoration: isCompleted && routine.goalType == 'achieve_all'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (routine.goalType == 'certain_amount') ...[
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
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              _RoutineIcon(routine: routine, isCompleted: false),
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
                      _frequencyLabel(context, routine),
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

  String _frequencyLabel(BuildContext context, Routine r) {
    final s = S.of(context);
    if (r.frequencyType == 'days_after_complete') {
      return s.daysAfterCount(r.daysAfterComplete ?? 1);
    }
    final days = r.weekdays;
    if (days == null || days.length == 7) return s.everyDayLabel;
    final labels = weekdaysShort(context);
    return days.map((d) => labels[d]).join(', ');
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

class _RoutineIcon extends StatelessWidget {
  const _RoutineIcon({required this.routine, required this.isCompleted});

  final Routine routine;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isCompleted
            ? Color(routine.iconColor).withOpacity(0.5)
            : Color(routine.iconColor),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isCompleted && routine.goalType == 'achieve_all'
            ? CupertinoIcons.checkmark
            : routineIconData(routine.iconId),
        color: CupertinoColors.white,
        size: 20,
      ),
    );
  }
}

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
