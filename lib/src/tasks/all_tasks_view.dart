import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import 'selectable_task_list_shell.dart';
import 'task_controller.dart';

class AllTasksView extends StatelessWidget {
  const AllTasksView({
    super.key,
    required this.controller,
    required this.folderController,
  });

  final TaskController controller;
  final FolderController folderController;

  @override
  Widget build(BuildContext context) {
    return SelectableTaskListShell(
      title: S.of(context).allTasks,
      taskController: controller,
      folderController: folderController,
      tasks: () => controller.allTasks,
    );
  }
}
