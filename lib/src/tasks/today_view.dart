import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../routines/routine_controller.dart';
import '../routines/routines_today_section.dart';
import '../settings/settings_controller.dart';
import 'selectable_task_list_shell.dart';
import 'task_controller.dart';

class TodayView extends StatefulWidget {
  const TodayView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.activeDueDate,
    this.routineController,
    this.settingsController,
  });

  final TaskController controller;
  final FolderController folderController;
  final ValueNotifier<DateTime?> activeDueDate;

  /// Optional — when both are provided and
  /// [SettingsController.showRoutinesInToday] is on, today's routines are
  /// shown as a collapsible section between the uncompleted and completed
  /// tasks.
  final RoutineController? routineController;
  final SettingsController? settingsController;

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
    final sc = widget.settingsController;
    final rc = widget.routineController;

    Widget shell(Widget? between) => SelectableTaskListShell(
          title: s.today,
          taskController: widget.controller,
          folderController: widget.folderController,
          tasks: () => widget.controller.todayTasks,
          emptyText: s.noTasksForToday,
          betweenContent: between,
        );

    if (sc == null || rc == null) return shell(null);

    return ListenableBuilder(
      listenable: sc,
      builder: (context, _) {
        final now = DateTime.now();
        final between = sc.showRoutinesInToday
            ? RoutinesTodaySection(
                controller: rc,
                date: DateTime(now.year, now.month, now.day),
              )
            : null;
        return shell(between);
      },
    );
  }
}
