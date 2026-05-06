import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../models/task.dart';
import '../utils/fast_route.dart';
import 'task_controller.dart';
import 'task_detail_view.dart';
import 'task_row.dart';

class TodayView extends StatefulWidget {
  const TodayView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.activeDueDate,
  });

  final TaskController controller;
  final FolderController folderController;
  final ValueNotifier<DateTime?> activeDueDate;

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final now = DateTime.now();
        widget.activeDueDate.value =
            DateTime(now.year, now.month, now.day);
      }
    });
  }

  @override
  void dispose() {
    widget.activeDueDate.value = null;
    super.dispose();
  }

  bool _isOverdue(Task task) {
    if (task.dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
        task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    return due.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        border: null,
        middle: Text('Today'),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(
              [widget.controller, widget.folderController]),
          builder: (context, _) {
            final tasks = widget.controller.todayTasks;

            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'No tasks for today',
                  style:
                      TextStyle(color: CupertinoColors.secondaryLabel),
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
                      key: ValueKey('today_${task.id}'),
                      index: i,
                      enabled: false,
                      child: Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: const TaskDeleteBackground(),
                        onDismissed: (_) =>
                            widget.controller.deleteTask(task.id),
                        child: TaskRow(
                          task: task,
                          isOverdue: _isOverdue(task),
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
