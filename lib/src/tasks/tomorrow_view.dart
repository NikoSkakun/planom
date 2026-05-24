import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../utils/fast_route.dart';
import '../utils/undo_controller.dart';
import 'task_controller.dart';
import 'task_detail_view.dart';
import 'task_row.dart';

class TomorrowView extends StatefulWidget {
  const TomorrowView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.activeDueDate,
  });

  final TaskController controller;
  final FolderController folderController;
  final ValueNotifier<DateTime?> activeDueDate;

  @override
  State<TomorrowView> createState() => _TomorrowViewState();
}

class _TomorrowViewState extends State<TomorrowView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final now = DateTime.now();
        widget.activeDueDate.value =
            DateTime(now.year, now.month, now.day)
                .add(const Duration(days: 1));
      }
    });
  }

  @override
  void dispose() {
    widget.activeDueDate.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tomorrow),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(
              [widget.controller, widget.folderController]),
          builder: (context, _) {
            final tasks = widget.controller.tomorrowTasks;

            if (tasks.isEmpty) {
              return Center(
                child: Text(
                  s.noTasks,
                  style:
                      const TextStyle(color: CupertinoColors.secondaryLabel),
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
                        ? widget.folderController.listById(task.listId!)
                        : null;
                    final listColor =
                        list?.color != null ? Color(list!.color!) : null;
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('tomorrow_${task.id}'),
                      index: i,
                      enabled: false,
                      child: Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: const TaskDeleteBackground(),
                        onDismissed: (_) {
                          final savedListId = task.listId;
                          widget.controller.deleteTask(task.id);
                          UndoScope.maybeOf(context)?.show(
                            label: s.taskTrashedToast,
                            onUndo: () => widget.controller
                                .restoreTask(task.id, savedListId),
                          );
                        },
                        child: TaskRow(
                          task: task,
                          showList: task.listId != null,
                          listColor: listColor,
                          onToggle: () =>
                              widget.controller.toggleCompleted(task.id),
                          onTap: () => Navigator.of(context).push(
                            FastRoute<void>(
                              settings: const RouteSettings(
                                  name: TaskDetailView.routeName),
                              builder: (_) => TaskDetailView(
                                task: task,
                                controller: widget.controller,
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
