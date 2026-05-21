import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
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
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.upcoming),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable:
              Listenable.merge([controller, folderController]),
          builder: (context, _) {
            final tasks = controller.upcomingTasks;

            if (tasks.isEmpty) {
              return Center(
                child: Text(
                  s.noUpcomingTasks,
                  style: const TextStyle(color: CupertinoColors.secondaryLabel),
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
                    final list = task.listId != null
                        ? folderController.listById(task.listId!)
                        : null;
                    final listColor =
                        list?.color != null ? Color(list!.color!) : null;
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
                          showList: task.listId != null,
                          listColor: listColor,
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
