import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../utils/fast_route.dart';
import 'task_controller.dart';
import 'task_detail_view.dart';
import 'task_row.dart';

class InboxView extends StatelessWidget {
  const InboxView({
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
        middle: Text('Inbox'),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final tasks = controller.inboxTasks;
            final canReorder =
                controller.sortOrder == TaskSortOrder.defaultOrder;

            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'No tasks',
                  style:
                      TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverReorderableList(
                  itemCount: tasks.length,
                  onReorder: canReorder
                      ? (old, neo) => controller.reorderTasks(
                            listId: null,
                            oldIndex: old,
                            newIndex: neo,
                          )
                      : (_, __) {},
                  proxyDecorator: taskProxyDecorator,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('inbox_${task.id}'),
                      index: i,
                      enabled: canReorder,
                      child: Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: const TaskDeleteBackground(),
                        onDismissed: (_) =>
                            controller.deleteTask(task.id),
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
