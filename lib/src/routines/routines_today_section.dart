import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/routine.dart';
import '../theme/app_theme.dart';
import 'routine_amount_dialog.dart';
import 'routine_controller.dart';
import 'routine_icons.dart';

/// A collapsible "Routines" section listing the routines scheduled for [date].
/// Reused by Tasks → Today (between uncompleted and completed tasks) and by the
/// Calendar day view. Tapping a row records progress for [date]; renders
/// nothing when no routines are scheduled that day.
class RoutinesTodaySection extends StatefulWidget {
  const RoutinesTodaySection({
    super.key,
    required this.controller,
    required this.date,
    this.initiallyExpanded = true,
  });

  final RoutineController controller;
  final DateTime date;
  final bool initiallyExpanded;

  @override
  State<RoutinesTodaySection> createState() => _RoutinesTodaySectionState();
}

class _RoutinesTodaySectionState extends State<RoutinesTodaySection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final all = widget.controller.routinesForDate(widget.date);
        if (all.isEmpty) return const SizedBox.shrink();
        // Completed routines sink to the bottom of the section.
        final incomplete = all
            .where((r) => !widget.controller.isCompletedOnDate(r, widget.date))
            .toList();
        final completed = all
            .where((r) => widget.controller.isCompletedOnDate(r, widget.date))
            .toList();
        final ordered = [...incomplete, ...completed];
        final s = S.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              label: s.tabRoutines,
              count: ordered.length,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded)
              for (final r in ordered)
                _Row(controller: widget.controller, routine: r, date: widget.date),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.label,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
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
              label.toUpperCase(),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.controller,
    required this.routine,
    required this.date,
  });

  final RoutineController controller;
  final Routine routine;
  final DateTime date;

  Future<void> _onTap(BuildContext context) async {
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
    controller.recordProgress(routine, date);
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = controller.isCompletedOnDate(routine, date);
    final achieveAll = routine.goalType == 'achieve_all';
    final progress = controller.progressForDate(routine.id, date);
    return GestureDetector(
      onTap: () => _onTap(context),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                RoutineCircleIcon(
                  iconId: routine.iconId,
                  iconColor: routine.iconColor,
                  size: 30,
                  dimmed: isCompleted,
                  showCheck: isCompleted && achieveAll,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    routine.name,
                    style: TextStyle(
                      fontSize: 16,
                      color: isCompleted
                          ? CupertinoColors.secondaryLabel.resolveFrom(context)
                          : CupertinoColors.label.resolveFrom(context),
                    ),
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
