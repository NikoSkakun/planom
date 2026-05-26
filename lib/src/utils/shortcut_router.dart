import 'package:flutter/cupertino.dart';

import '../contacts/contact_controller.dart';
import '../folders/folder_controller.dart';
import '../folders/folder_view.dart';
import '../folders/list_task_view.dart';
import '../notes/note_controller.dart';
import '../notes/note_folder_view.dart';
import '../settings/tab_bar_config.dart';
import '../tasks/all_tasks_view.dart';
import '../tasks/completed_view.dart';
import '../tasks/inbox_view.dart';
import '../tasks/task_controller.dart';
import '../tasks/today_view.dart';
import '../tasks/tomorrow_view.dart';
import '../tasks/trash_view.dart';
import '../tasks/upcoming_view.dart';
import 'fast_route.dart';

/// Pushes the view targeted by a tab-bar shortcut onto [navigator].
/// Each variant maps to an existing per-feature view; the router only
/// hands over the necessary controllers.
void pushShortcut({
  required NavigatorState navigator,
  required ShortcutTarget target,
  String? shortcutId,
  required TaskController taskController,
  required FolderController folderController,
  required NoteController noteController,
  required ContactController contactController,
  required ValueNotifier<DateTime?> activeDueDate,
  required ValueNotifier<String?> activeListId,
}) {
  Widget? page;
  switch (target) {
    case ShortcutTarget.smartInbox:
      page = InboxView(
        controller: taskController,
        folderController: folderController,
      );
    case ShortcutTarget.smartToday:
      page = TodayView(
        controller: taskController,
        folderController: folderController,
        activeDueDate: activeDueDate,
      );
    case ShortcutTarget.smartTomorrow:
      page = TomorrowView(
        controller: taskController,
        folderController: folderController,
        activeDueDate: activeDueDate,
      );
    case ShortcutTarget.smartUpcoming:
      page = UpcomingView(
        controller: taskController,
        folderController: folderController,
      );
    case ShortcutTarget.smartAllTasks:
      page = AllTasksView(
        controller: taskController,
        folderController: folderController,
      );
    case ShortcutTarget.smartCompleted:
      page = CompletedView(
        controller: taskController,
        folderController: folderController,
      );
    case ShortcutTarget.smartTrash:
      page = TrashView(
        taskController: taskController,
        folderController: folderController,
      );
    case ShortcutTarget.list:
      if (shortcutId == null) return;
      final list = folderController.listById(shortcutId);
      if (list == null) return;
      page = ListTaskView(
        list: list,
        taskController: taskController,
        folderController: folderController,
        contactController: contactController,
        activeListId: activeListId,
      );
    case ShortcutTarget.folder:
      if (shortcutId == null) return;
      final folder = folderController.folderById(shortcutId);
      if (folder == null) return;
      page = FolderView(
        folder: folder,
        folderController: folderController,
        taskController: taskController,
        contactController: contactController,
        activeListId: activeListId,
      );
    case ShortcutTarget.noteFolder:
      if (shortcutId == null) return;
      final folder = noteController.folderById(shortcutId);
      if (folder == null) return;
      page = NoteFolderView(
        folder: folder,
        controller: noteController,
      );
  }
  navigator.push(FastRoute<void>(builder: (_) => page!));
}
