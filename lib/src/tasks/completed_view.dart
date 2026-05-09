import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../utils/fast_route.dart';
import 'task_controller.dart';
import 'task_detail_view.dart';
import 'task_row.dart';

class CompletedView extends StatelessWidget {
  const CompletedView({
    super.key,
    required this.controller,
    required this.folderController,
  });

  final TaskController controller;
  final FolderController folderController;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        border: null,
        middle: Text('Completed'),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final tasks = controller.allCompletedTasks;

            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'No completed tasks',
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final task = tasks[i];
                      return Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: const TaskDeleteBackground(),
                        onDismissed: (_) => controller.deleteTask(task.id),
                        child: TaskRow(
                          task: task,
                          onToggle: () =>
                              controller.toggleCompleted(task.id),
                          onTap: () => Navigator.of(context).push(
                            FastRoute<void>(
                              settings: const RouteSettings(
                                  name: TaskDetailView.routeName),
                              builder: (_) => TaskDetailView(
                                task: task,
                                controller: controller,
                                folderController: folderController,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: tasks.length,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
