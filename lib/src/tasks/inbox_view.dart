import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../utils/fast_route.dart';
import '../utils/undo_controller.dart';
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
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(border: null,
        middle: Text(s.inbox),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final tasks = controller.inboxTasks;
            final canReorder =
                controller.sortOrder == TaskSortOrder.defaultOrder;

            if (tasks.isEmpty) {
              return Center(
                child: Text(
                  s.noTasks,
                  style: const TextStyle(color: CupertinoColors.secondaryLabel),
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
                        onDismissed: (_) {
                          final savedListId = task.listId;
                          controller.deleteTask(task.id);
                          UndoScope.maybeOf(context)?.show(
                            label: s.taskTrashedToast,
                            onUndo: () =>
                                controller.restoreTask(task.id, savedListId),
                          );
                        },
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
