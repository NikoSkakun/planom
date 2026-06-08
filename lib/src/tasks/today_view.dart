import 'package:flutter/cupertino.dart';

import '../calendar/event_controller.dart';
import '../calendar/today_events_section.dart';
import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../routines/routine_controller.dart';
import '../routines/routines_today_section.dart';
import '../settings/settings_controller.dart';
import '../utils/notifier_reset.dart';
import 'selectable_task_list_shell.dart';
import 'task_controller.dart';

class TodayView extends StatefulWidget {
  const TodayView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.activeDueDate,
    this.routineController,
    this.eventController,
    this.settingsController,
  });

  final TaskController controller;
  final FolderController folderController;
  final ValueNotifier<DateTime?> activeDueDate;

  /// Optional — when provided and the matching setting is on, today's routines
  /// / events are shown as collapsible sections between the uncompleted and
  /// completed tasks.
  final RoutineController? routineController;
  final EventController? eventController;
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
    // Deferred to avoid notifying the shell while this view is unmounting.
    resetNotifierAfterFrame(widget.activeDueDate, null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sc = widget.settingsController;

    Widget shell(Widget? between) => SelectableTaskListShell(
          title: s.today,
          taskController: widget.controller,
          folderController: widget.folderController,
          tasks: () => widget.controller.todayTasks,
          emptyText: s.noTasksForToday,
          betweenContent: between,
        );

    if (sc == null) return shell(null);

    return ListenableBuilder(
      listenable: sc,
      builder: (context, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final sections = <Widget>[];
        if (sc.showEventsInToday && widget.eventController != null) {
          sections.add(TodayEventsSection(
            controller: widget.eventController!,
            date: today,
          ));
        }
        if (sc.showRoutinesInToday && widget.routineController != null) {
          sections.add(RoutinesTodaySection(
            controller: widget.routineController!,
            date: today,
          ));
        }
        final between = sections.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: sections,
              );
        return shell(between);
      },
    );
  }
}
