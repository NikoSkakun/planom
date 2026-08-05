import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../models/goal.dart';
import '../settings/settings_controller.dart';
import '../tasks/complete_with_undo.dart';
import '../tasks/task_controller.dart';
import '../tasks/task_detail_view.dart';
import '../tasks/task_row.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import 'goal_controller.dart';
import 'goal_editor_view.dart';
import 'goal_icons.dart';
import 'goal_progress_bar.dart';
import 'goal_source_labels.dart';

/// A goal's contents: its header + progress, the rules that build it, and the
/// live list of tracked tasks (checkable in place, tappable through to the
/// normal task editor).
class GoalDetailView extends StatelessWidget {
  const GoalDetailView({
    super.key,
    required this.goalId,
    required this.goalController,
    required this.taskController,
    required this.folderController,
    this.settingsController,
  });

  static const routeName = 'goal_detail';

  final String goalId;
  final GoalController goalController;
  final TaskController taskController;
  final FolderController folderController;
  final SettingsController? settingsController;

  Future<void> _edit(BuildContext context, Goal goal) async {
    final updated = await showGoalEditor(
      context,
      goalController: goalController,
      taskController: taskController,
      folderController: folderController,
      existing: goal,
    );
    if (updated != null) await goalController.updateGoal(updated);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      // Progress is derived from tasks, so the view has to follow both.
      listenable: Listenable.merge([goalController, taskController]),
      builder: (context, _) {
        final goal = goalController.goalById(goalId);
        if (goal == null) {
          // The goal was deleted while its detail page was open.
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(border: null),
            child: Center(child: Text(s.goalMissing)),
          );
        }
        final tasks = goalController.tasksForGoal(goal);
        final progress = goalController.progressFor(goal);

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            border: null,
            middle: Text(goal.name, overflow: TextOverflow.ellipsis),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () => _edit(context, goal),
              child: Text(
                s.edit,
                style: TextStyle(color: AppColors.accent, fontSize: 16),
              ),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GoalCircleIcon(
                          iconId: goal.iconId, color: goal.color, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.name,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            if ((goal.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                goal.description!,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GoalProgressBar(fraction: progress.fraction, height: 12),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.goalProgressCount(
                                  progress.completed, progress.total),
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ),
                          Text(
                            '${progress.percent}%',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // What the goal is built from — the same summaries the editor
                // shows, so the rules are visible without entering edit mode.
                if (goal.sources.isNotEmpty) ...[
                  _SectionHeader(label: s.goalSources),
                  for (final source in goal.sources)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            source.kind == GoalSourceKind.manual
                                ? CupertinoIcons.hand_point_right
                                : CupertinoIcons.slider_horizontal_3,
                            size: 16,
                            color: CupertinoColors.tertiaryLabel
                                .resolveFrom(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${goalSourceTitle(s, source)}'
                              '${_detailSuffix(context, source)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                _SectionHeader(label: s.goalTrackedTasks),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Text(
                      s.goalNoTasksYet,
                      style: TextStyle(
                        fontSize: 15,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  )
                else
                  for (final task in tasks)
                    TaskRow(
                      key: ValueKey(task.id),
                      task: task,
                      showList: true,
                      listColor: _listColor(task.listId),
                      onToggle: () => toggleTaskCompletedWithUndo(
                          context, taskController, task),
                      onTap: () => Navigator.of(context).push(
                        FastRoute<void>(
                          settings: const RouteSettings(
                              name: TaskDetailView.routeName),
                          builder: (_) => TaskDetailView(
                            task: task,
                            controller: taskController,
                            folderController: folderController,
                          ),
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

  String _detailSuffix(BuildContext context, GoalSource source) {
    final detail = goalSourceDetail(
      context,
      source,
      folderController: folderController,
      taskController: taskController,
    );
    return detail.isEmpty ? '' : ' · $detail';
  }

  Color? _listColor(String? listId) {
    if (listId == null) return null;
    final color = folderController.listById(listId)?.color;
    return color == null ? null : Color(color);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          letterSpacing: -0.08,
        ),
      ),
    );
  }
}
