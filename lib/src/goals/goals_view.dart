import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show ReorderableListView, ReorderableDelayedDragStartListener;

import '../folders/folder_controller.dart';
import '../home_shell.dart';
import '../localization/strings.dart';
import '../models/goal.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_menu.dart';
import '../tasks/task_controller.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import '../utils/undo_controller.dart';
import 'goal_controller.dart';
import 'goal_detail_view.dart';
import 'goal_editor_view.dart';
import 'goal_icons.dart';
import 'goal_progress_bar.dart';

/// Goals tab root: one card per goal with its progress bar. Long-press to
/// drag-reorder or open the edit/delete menu; tap to open the goal.
class GoalsView extends StatefulWidget {
  const GoalsView({
    super.key,
    required this.controller,
    required this.taskController,
    required this.folderController,
    this.settingsController,
  });

  final GoalController controller;
  final TaskController taskController;
  final FolderController folderController;
  final SettingsController? settingsController;

  @override
  State<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<GoalsView> with DropdownOverlayMixin {
  void _showSettingsMenu(BuildContext context) {
    showDropdown(
      context,
      (dismiss) => SettingsMenuOverlay(
        onDismiss: dismiss,
        onSettings: () {
          dismiss();
          HomeShell.openGlobalSettings(context);
        },
      ),
    );
  }

  void _open(Goal goal) {
    Navigator.of(context).push(
      FastRoute<void>(
        settings: const RouteSettings(name: GoalDetailView.routeName),
        builder: (_) => GoalDetailView(
          goalId: goal.id,
          goalController: widget.controller,
          taskController: widget.taskController,
          folderController: widget.folderController,
          settingsController: widget.settingsController,
        ),
      ),
    );
  }

  Future<void> _edit(Goal goal) async {
    final updated = await showGoalEditor(
      context,
      goalController: widget.controller,
      taskController: widget.taskController,
      folderController: widget.folderController,
      existing: goal,
    );
    if (updated != null) await widget.controller.updateGoal(updated);
  }

  Future<void> _delete(Goal goal) async {
    await widget.controller.deleteGoal(goal.id);
    if (!mounted) return;
    UndoScope.maybeOf(context)?.show(
      label: S.of(context).goalDeleted,
      onUndo: () => widget.controller.restoreGoal(goal),
    );
  }

  Future<void> _goalMenu(Goal goal) async {
    final s = S.of(context);
    final action = await showSelectionMenu<String>(
      context: context,
      title: goal.name,
      options: [
        SelectionMenuOption(value: 'edit', label: s.edit),
        SelectionMenuOption(
            value: 'delete', label: s.delete, isDestructive: true),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _edit(goal);
    } else if (action == 'delete') {
      final ok = await confirmHardDelete(
        context,
        title: s.goalDeleteTitle,
        body: s.goalDeleteBody,
        confirmLabel: s.delete,
      );
      if (ok && mounted) await _delete(goal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sc = widget.settingsController;
    final settingsHidden = sc != null && !sc.isTabVisible(4);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabGoals),
        trailing: settingsHidden
            ? Builder(
                builder: (ctx) => CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => _showSettingsMenu(ctx),
                  child: Semantics(
                    label: s.settings,
                    button: true,
                    child: Icon(
                      CupertinoIcons.ellipsis,
                      size: 22,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: ListenableBuilder(
          // Progress bars are derived from tasks, so follow both controllers.
          listenable:
              Listenable.merge([widget.controller, widget.taskController]),
          builder: (context, _) {
            final goals = widget.controller.goals;
            if (goals.isEmpty) return _EmptyState();
            return ReorderableListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 120),
              buildDefaultDragHandles: false,
              itemCount: goals.length,
              onReorder: widget.controller.reorderGoals,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final progress = widget.controller.progressFor(goal);
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(goal.id),
                  index: index,
                  child: Dismissible(
                    key: ValueKey('dismiss_${goal.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: CupertinoColors.destructiveRed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(CupertinoIcons.trash,
                          color: CupertinoColors.white),
                    ),
                    onDismissed: (_) => _delete(goal),
                    child: _GoalCard(
                      goal: goal,
                      progress: progress,
                      onTap: () => _open(goal),
                      onLongPress: () => _goalMenu(goal),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.onTap,
    required this.onLongPress,
  });

  final Goal goal;
  final GoalProgress progress;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GoalCircleIcon(iconId: goal.iconId, color: goal.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      if ((goal.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          goal.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${progress.percent}%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GoalProgressBar(fraction: progress.fraction),
            const SizedBox(height: 6),
            Text(
              progress.isEmpty
                  ? s.goalNoTasksYet
                  : s.goalProgressCount(progress.completed, progress.total),
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.flag,
              size: 42,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 12),
            Text(
              s.goalNoGoalsYet,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.goalTapPlusToCreate,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
