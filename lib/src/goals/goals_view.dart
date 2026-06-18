import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import '../utils/simple_date_picker.dart';
import 'goal_controller.dart';
import 'goal_detail_view.dart';
import 'goal_editor.dart';
import 'goal_icons.dart';
import 'goal_ring.dart';

/// Tab root for the Goals mode. Lists active goals with progress rings, with a
/// collapsible Completed section below.
class GoalsView extends StatefulWidget {
  const GoalsView({super.key, required this.controller});
  final GoalController controller;

  @override
  State<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<GoalsView> {
  bool _showCompleted = false;

  GoalController get _c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      child: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final active = _c.activeGoals;
          final completed = _c.completedGoals;
          if (_c.goals.where((g) => !g.isArchived).isEmpty) {
            return _empty(context, s);
          }
          return CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(largeTitle: Text(s.tabGoals)),
              if (active.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(s.goalAllDone,
                          style: TextStyle(
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context))),
                    ),
                  ),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) =>
                      _GoalCard(controller: _c, goal: active[i]),
                  childCount: active.length,
                ),
              ),
              if (completed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    onPressed: () =>
                        setState(() => _showCompleted = !_showCompleted),
                    child: Row(
                      children: [
                        Icon(
                          _showCompleted
                              ? CupertinoIcons.chevron_down
                              : CupertinoIcons.chevron_right,
                          size: 16,
                          color:
                              CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                        const SizedBox(width: 8),
                        Text('${s.completed} (${completed.length})',
                            style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context))),
                      ],
                    ),
                  ),
                ),
                if (_showCompleted)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _GoalCard(controller: _c, goal: completed[i]),
                      childCount: completed.length,
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, S s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.flag_circle,
                size: 64, color: CupertinoColors.systemGrey.resolveFrom(context)),
            const SizedBox(height: 16),
            Text(s.goalEmptyTitle,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(s.goalEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context))),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () => showGoalEditor(context, _c),
              child: Text(s.goalNew),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.controller, required this.goal});
  final GoalController controller;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final progress = controller.progress(goal);
    final subtitle = goal.isNumeric
        ? '${goal.currentAmount} / ${goal.targetAmount ?? 0}${goal.unit == null ? '' : ' ${goal.unit}'}'
        : '${controller.milestonesDone(goal.id)} / ${controller.milestonesTotal(goal.id)} ${s.goalMilestones.toLowerCase()}';
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onPressed: () => showGoalDetail(context, controller, goal.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            GoalProgressRing(
              fraction: progress,
              color: Color(goal.colorValue),
              size: 52,
              stroke: 6,
              center: GoalCircleIcon(
                  iconId: goal.iconId,
                  colorValue: goal.colorValue,
                  size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context))),
                  if (goal.targetDate != null && !goal.isCompleted) ...[
                    const SizedBox(height: 2),
                    Text(s.goalTargetBy(formatShortDate(goal.targetDate!)),
                        style: TextStyle(
                            fontSize: 12,
                            color: goal.targetDate!.isBefore(DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day))
                                ? const Color(0xFFFF3B30)
                                : CupertinoColors.tertiaryLabel
                                    .resolveFrom(context))),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (goal.isCompleted)
              Icon(CupertinoIcons.checkmark_seal_fill,
                  color: AppColors.systemGreen, size: 22)
            else
              Text('${(progress * 100).round()}%',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(goal.colorValue))),
          ],
        ),
      ),
    );
  }
}
