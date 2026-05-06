import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../utils/fast_route.dart';
import 'task_controller.dart';
import 'task_detail_view.dart';
import 'task_row.dart';

class UpcomingView extends StatelessWidget {
  const UpcomingView({
    super.key,
    required this.controller,
    required this.folderController,
  });

  final TaskController controller;
  final FolderController folderController;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(border: null,
        middle: Text('Upcoming'),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final tasks = controller.upcomingTasks;

            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'No upcoming tasks',
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverReorderableList(
                  itemCount: tasks.length,
                  onReorder: (_, __) {},
                  proxyDecorator: taskProxyDecorator,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    final listName = task.listId != null
                        ? folderController.listById(task.listId!)?.name
                        : null;
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('upcoming_${task.id}'),
                      index: i,
                      enabled: false,
                      child: Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: const TaskDeleteBackground(),
                        onDismissed: (_) => controller.deleteTask(task.id),
                        child: TaskRow(
                          task: task,
                          showList: true,
                          listName: listName,
                          onToggle: () => controller.toggleCompleted(task.id),
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
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
