import 'package:flutter/widgets.dart';

import '../calendar/event_controller.dart';
import '../contacts/contact_controller.dart';
import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../routines/routine_controller.dart';
import '../tasks/task_controller.dart';
import '../theme/app_theme.dart';

/// Builds the JSON-serialisable payload the iOS widget extension consumes.
///
/// This is a pure function over the active space's controllers + the user's
/// appearance / locale settings, so it produces identical output whether it is
/// called from the foreground (live controllers) or from the headless
/// interactivity isolate (freshly-loaded controllers). The native side decodes
/// the structure in `ios/PlanomWidget/WidgetData.swift`.
class WidgetDataBuilder {
  const WidgetDataBuilder({
    required this.taskController,
    required this.eventController,
    required this.routineController,
    required this.contactController,
    required this.folderController,
    required this.accentColor,
    required this.locale,
    required this.spaceName,
    this.maxItemsPerSection = 25,
  });

  final TaskController taskController;
  final EventController eventController;
  final RoutineController routineController;
  final ContactController contactController;
  final FolderController folderController;
  final Color accentColor;
  final Locale locale;
  final String spaceName;
  final int maxItemsPerSection;

  static String _hex(Color c) {
    final argb = c.value & 0xFFFFFFFF;
    final rgb = argb & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Map<String, dynamic> build() {
    final s = S(locale);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── Today's tasks (today + overdue), mirrors TaskController.todayTasks ──
    final todayTasks = taskController.todayTasks;
    final tasksJson = <Map<String, dynamic>>[];
    for (final t in todayTasks.take(maxItemsPerSection)) {
      final due = t.dueDate == null
          ? null
          : DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      final overdue = due != null && due.isBefore(today) && !t.isCompleted;
      String? color;
      if (t.listId != null) {
        final list = folderController.listById(t.listId!);
        if (list?.color != null) color = _hex(Color(list!.color!));
      }
      tasksJson.add({
        'id': t.id,
        'title': t.title,
        'minutes': t.doTime,
        'completed': t.isCompleted,
        'priority': t.priority,
        'overdue': overdue,
        'color': color,
      });
    }

    // ── Tomorrow's tasks (for the agenda / stats look-ahead) ──
    final tomorrowJson = <Map<String, dynamic>>[];
    for (final t in taskController.tomorrowTasks.take(maxItemsPerSection)) {
      tomorrowJson.add({
        'id': t.id,
        'title': t.title,
        'minutes': t.doTime,
        'completed': t.isCompleted,
        'priority': t.priority,
      });
    }

    // ── Today's events ──
    // Timed events first (by start), all-day / untimed pushed to the end — the
    // same ordering the native agenda widget uses when merging tasks + events.
    final events = eventController.eventsForDate(today)
      ..sort((a, b) => (a.doTime ?? 100000).compareTo(b.doTime ?? 100000));
    final eventsJson = <Map<String, dynamic>>[];
    for (final e in events.take(maxItemsPerSection)) {
      eventsJson.add({
        'id': e.id,
        'title': e.title,
        'minutes': e.doTime,
        'allDay': e.doTime == null,
        'duration': e.duration,
      });
    }

    // ── Today's birthdays ──
    final birthdaysJson = <Map<String, dynamic>>[];
    for (final c in contactController.contactsForDate(today)) {
      int? age;
      if (c.birthYear != null) age = now.year - c.birthYear!;
      birthdaysJson.add({'name': c.name, 'age': age});
    }

    // ── Today's routines ──
    final routines = routineController.todayRoutines;
    final routinesJson = <Map<String, dynamic>>[];
    var routinesDone = 0;
    for (final r in routines) {
      final done = routineController.isTodayCompleted(r);
      if (done) routinesDone++;
      routinesJson.add({
        'id': r.id,
        'name': r.name,
        'color': _hex(Color(r.iconColor)),
        'done': done,
        'goalType': r.goalType,
        'progress': routineController.todayProgress(r.id),
        'goal': r.goalAmount,
        'unit': r.goalUnit,
      });
    }

    final todayCompleted = todayTasks.where((t) => t.isCompleted).length;

    return {
      'updatedAt': now.millisecondsSinceEpoch ~/ 1000,
      'accentColor': _hex(accentColor),
      'completionColor': _hex(AppColors.systemGreen),
      'spaceName': spaceName,
      'locale': locale.languageCode,
      'labels': {
        'today': s.today,
        'tomorrow': s.tomorrow,
        'tasks': s.tabTasks,
        'events': s.tabCalendar,
        'routines': s.tabRoutines,
        'inbox': s.inbox,
        'noTasks': s.widgetNoTasks,
        'allDone': s.widgetAllDone,
        'noEvents': s.widgetNoEvents,
        'noRoutines': s.widgetNoRoutines,
        'agenda': s.widgetAgendaTitle,
        'addTask': s.widgetAddTask,
        'remaining': s.widgetRemaining,
        'allDay': s.widgetAllDay,
        'birthday': s.widgetBirthday,
        'done': s.done,
      },
      'counts': {
        'todayTasks': todayTasks.length,
        'todayRemaining': taskController.todayUncompletedCount,
        'todayCompleted': todayCompleted,
        'inbox': taskController.inboxUncompletedCount,
        'tomorrowTasks': taskController.tomorrowUncompletedCount,
        'todayEvents': events.length,
        'birthdays': birthdaysJson.length,
        'routinesTotal': routines.length,
        'routinesDone': routinesDone,
      },
      'todayTasks': tasksJson,
      'tomorrowTasks': tomorrowJson,
      'todayEvents': eventsJson,
      'birthdays': birthdaysJson,
      'routines': routinesJson,
    };
  }
}
