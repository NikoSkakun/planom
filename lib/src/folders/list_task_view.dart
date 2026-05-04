import 'package:flutter/cupertino.dart';

import '../models/app_list.dart';
import '../tasks/task_controller.dart';
import '../tasks/task_detail_view.dart';
import '../tasks/task_row.dart';
import '../utils/fast_route.dart';
import 'folder_controller.dart';

class ListTaskView extends StatefulWidget {
  const ListTaskView({
    super.key,
    required this.list,
    required this.taskController,
    required this.folderController,
    required this.activeListId,
  });

  final AppList list;
  final TaskController taskController;
  final FolderController folderController;
  final ValueNotifier<String?> activeListId;

  @override
  State<ListTaskView> createState() => _ListTaskViewState();
}

class _ListTaskViewState extends State<ListTaskView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.activeListId.value = widget.list.id;
    });
  }

  @override
  void dispose() {
    widget.activeListId.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(border: null,
        middle: Text(widget.list.name),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.taskController,
          builder: (context, _) {
            final tasks =
                widget.taskController.tasksForList(widget.list.id);
            final canReorder = widget.taskController.sortOrder ==
                TaskSortOrder.defaultOrder;

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
                      ? (old, neo) =>
                          widget.taskController.reorderTasks(
                            listId: widget.list.id,
                            oldIndex: old,
                            newIndex: neo,
                          )
                      : (_, __) {},
                  proxyDecorator: taskProxyDecorator,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('list_task_${task.id}'),
                      index: i,
                      enabled: canReorder,
                      child: Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: const TaskDeleteBackground(),
                        onDismissed: (_) =>
                            widget.taskController.deleteTask(task.id),
                        child: TaskRow(
                          task: task,
                          onToggle: () => widget.taskController
                              .toggleCompleted(task.id),
                          onTap: () => Navigator.of(context).push(
                            FastRoute<void>(
                              settings: const RouteSettings(
                                  name: TaskDetailView.routeName),
                              builder: (_) => TaskDetailView(
                                task: task,
                                controller: widget.taskController,
                                folderController: widget.folderController,
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
