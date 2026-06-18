import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/goal.dart';
import '../models/goal_milestone.dart';
import '../theme/app_theme.dart';
import '../utils/editor_widgets.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import '../utils/simple_date_picker.dart';
import '../utils/undo_controller.dart';
import 'goal_controller.dart';
import 'goal_editor.dart';
import 'goal_icons.dart';
import 'goal_ring.dart';

class GoalDetailView extends StatefulWidget {
  const GoalDetailView(
      {super.key, required this.controller, required this.goalId});
  final GoalController controller;
  final String goalId;

  static const routeName = 'goal_detail';

  @override
  State<GoalDetailView> createState() => _GoalDetailViewState();
}

class _GoalDetailViewState extends State<GoalDetailView> {
  final _milestoneCtrl = TextEditingController();

  GoalController get _c => widget.controller;

  @override
  void dispose() {
    _milestoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _menu(Goal goal) async {
    final s = S.of(context);
    final choice = await showSelectionMenu<String>(
      context: context,
      anchor: SelectionMenuAnchor.topRight,
      options: [
        SelectionMenuOption(
            value: 'edit', label: s.edit, icon: CupertinoIcons.pencil),
        SelectionMenuOption(
            value: goal.isArchived ? 'unarchive' : 'archive',
            label: goal.isArchived ? s.goalUnarchive : s.goalArchive,
            icon: CupertinoIcons.archivebox),
        SelectionMenuOption(
            value: 'delete',
            label: s.delete,
            icon: CupertinoIcons.delete,
            isDestructive: true),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'edit':
        showGoalEditor(context, _c, existing: goal);
      case 'archive':
        _c.setArchived(goal, true);
      case 'unarchive':
        _c.setArchived(goal, false);
      case 'delete':
        _delete(goal);
    }
  }

  void _delete(Goal goal) {
    final undo = UndoScope.of(context);
    final milestones = _c.milestonesFor(goal.id);
    _c.deleteGoal(goal.id);
    undo.show(
      label: S.of(context).goalDeleted,
      onUndo: () => _c.restoreGoal(goal, milestones),
    );
    Navigator.of(context).pop();
  }

  void _addMilestone(Goal goal) {
    final text = _milestoneCtrl.text.trim();
    if (text.isEmpty) return;
    _c.addMilestone(goal.id, text);
    _milestoneCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      child: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final goal = _c.goalById(widget.goalId);
          if (goal == null) return const SizedBox.shrink();
          final progress = _c.progress(goal);
          final milestones = _c.milestonesFor(goal.id);
          return CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(goal.title),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => _menu(goal),
                  child: const Icon(CupertinoIcons.ellipsis_circle),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      // Hero ring.
                      GoalProgressRing(
                        fraction: progress,
                        color: Color(goal.colorValue),
                        size: 140,
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GoalCircleIcon(
                                iconId: goal.iconId,
                                colorValue: goal.colorValue,
                                size: 44),
                            const SizedBox(height: 6),
                            Text('${(progress * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (goal.isCompleted)
                        _Pill(
                            text: s.goalCompletedBadge,
                            color: AppColors.systemGreen),
                      if (goal.targetDate != null && !goal.isCompleted)
                        _Pill(
                          text: s.goalTargetBy(formatShortDate(goal.targetDate!)),
                          color: _dueColor(context, goal.targetDate!),
                        ),
                      if (goal.note != null && goal.note!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(goal.note!,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context))),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (goal.isNumeric)
                SliverToBoxAdapter(child: _numericControls(context, goal, s))
              else
                _milestoneList(context, goal, milestones, s),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  Color _dueColor(BuildContext context, DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (due.isBefore(today)) return const Color(0xFFFF3B30);
    return CupertinoColors.secondaryLabel.resolveFrom(context);
  }

  Widget _numericControls(BuildContext context, Goal goal, S s) {
    final target = goal.targetAmount ?? 0;
    final unit = goal.unit == null ? '' : ' ${goal.unit}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          EditorField(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(s.goalProgress,
                      style: TextStyle(
                          color:
                              CupertinoColors.label.resolveFrom(context))),
                  const Spacer(),
                  Text('${goal.currentAmount} / $target$unit',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: CupertinoColors.secondarySystemBackground
                      .resolveFrom(context),
                  onPressed: goal.currentAmount > 0
                      ? () => _c.addProgress(goal, -1)
                      : null,
                  child: const Icon(CupertinoIcons.minus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CupertinoButton(
                  color: Color(goal.colorValue),
                  onPressed: () => _promptAmount(goal),
                  child: Text(s.goalSetAmount,
                      style: const TextStyle(color: CupertinoColors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  color: Color(goal.colorValue),
                  onPressed: () => _c.addProgress(goal, 1),
                  child: const Icon(CupertinoIcons.plus,
                      color: CupertinoColors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _promptAmount(Goal goal) async {
    final ctrl = TextEditingController(text: goal.currentAmount.toString());
    final s = S.of(context);
    final result = await showCupertinoDialog<int>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.goalSetAmount),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(s.cancel),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(s.done),
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
          ),
        ],
      ),
    );
    if (result != null) _c.setProgress(goal, result);
  }

  Widget _milestoneList(
      BuildContext context, Goal goal, List<GoalMilestone> milestones, S s) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
            child: Text(
                '${s.goalMilestones} · ${_c.milestonesDone(goal.id)}/${milestones.length}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context))),
          ),
          for (final m in milestones)
            _MilestoneRow(
              milestone: m,
              color: Color(goal.colorValue),
              onToggle: () => _c.toggleMilestone(m),
              onDelete: () => _c.deleteMilestone(m.id),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: EditorField(
                    child: CupertinoTextField.borderless(
                      controller: _milestoneCtrl,
                      placeholder: s.goalAddMilestone,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      onSubmitted: (_) => _addMilestone(goal),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: _milestoneCtrl.text.trim().isEmpty
                      ? null
                      : () => _addMilestone(goal),
                  child: Icon(CupertinoIcons.add_circled_solid,
                      size: 32,
                      color: _milestoneCtrl.text.trim().isEmpty
                          ? CupertinoColors.systemGrey3.resolveFrom(context)
                          : Color(goal.colorValue)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow(
      {required this.milestone,
      required this.color,
      required this.onToggle,
      required this.onDelete});
  final GoalMilestone milestone;
  final Color color;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(milestone.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onPressed: onToggle,
        child: Row(
          children: [
            Icon(
              milestone.isCompleted
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: milestone.isCompleted
                  ? color
                  : CupertinoColors.systemGrey3.resolveFrom(context),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                milestone.title,
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.label.resolveFrom(context),
                  decoration: milestone.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor:
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      );
}

/// Pushes a goal detail page.
Future<void> showGoalDetail(
    BuildContext context, GoalController controller, String goalId) {
  return Navigator.of(context).push(
    FastRoute<void>(
      settings: const RouteSettings(name: GoalDetailView.routeName),
      builder: (_) => GoalDetailView(controller: controller, goalId: goalId),
    ),
  );
}
