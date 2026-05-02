import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../models/task.dart';
import '../utils/fast_route.dart';
import 'calendar_date_picker.dart';
import 'task_controller.dart';
import 'task_detail_view.dart';

class TodayView extends StatefulWidget {
  const TodayView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.activeDueDate,
  });

  final TaskController controller;
  final FolderController folderController;
  /// Owned by HomeShell; set to today while this view is active so the + button
  /// pre-fills today's date.
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
    final due = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    return due.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Today'),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final tasks = widget.controller.todayTasks;
            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'No tasks for today',
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              );
            }
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, i) {
                final task = tasks[i];
                return Dismissible(
                  key: ValueKey(task.id),
                  direction: DismissDirection.endToStart,
                  background: _DeleteBackground(),
                  onDismissed: (_) =>
                      widget.controller.deleteTask(task.id),
                  child: _TaskRow(
                    task: task,
                    listName: task.listId != null
                        ? widget.folderController.listById(task.listId!)?.name
                        : null,
                    isOverdue: _isOverdue(task),
                    onToggle: () =>
                        widget.controller.toggleCompleted(task.id),
                    onTap: () => Navigator.of(context).push(
                      FastRoute<void>(
                        settings: const RouteSettings(name: TaskDetailView.routeName),
                        builder: (_) => TaskDetailView(
                          task: task,
                          controller: widget.controller,
                          folderController: widget.folderController,
                        ),
                      ),
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

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: CupertinoColors.destructiveRed,
      child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onTap,
    this.listName,
    this.isOverdue = false,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final String? listName;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onToggle,
              child: _RoundedCheckbox(checked: task.isCompleted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      color: task.isCompleted
                          ? CupertinoColors.secondaryLabel.resolveFrom(context)
                          : null,
                    ),
                  ),
                  if (task.note != null && task.note!.isNotEmpty)
                    Text(
                      task.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  if (isOverdue && task.dueDate != null)
                    Text(
                      formatTaskDate(task.dueDate!, doTime: task.doTime),
                      style: const TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
                  if (listName != null)
                    Text(
                      listName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundedCheckbox extends StatelessWidget {
  const _RoundedCheckbox({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: checked ? const Color(0xFFFF4D00) : null,
        border: checked
            ? null
            : Border.all(
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                width: 1.5,
              ),
      ),
      child: checked
          ? const Icon(CupertinoIcons.checkmark,
              size: 13, color: CupertinoColors.white)
          : null,
    );
  }
}
