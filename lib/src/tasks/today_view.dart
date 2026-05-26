import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import 'selectable_task_list_shell.dart';
import 'task_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SelectableTaskListShell(
      title: s.today,
      taskController: widget.controller,
      folderController: widget.folderController,
      tasks: () => widget.controller.todayTasks,
      emptyText: s.noTasksForToday,
    );
  }
}
