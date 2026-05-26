import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import 'selectable_task_list_shell.dart';
import 'task_controller.dart';

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
    return SelectableTaskListShell(
      title: s.upcoming,
      taskController: controller,
      folderController: folderController,
      tasks: () => controller.upcomingTasks,
      emptyText: s.noUpcomingTasks,
    );
  }
}
