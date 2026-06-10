import 'package:flutter/widgets.dart';

/// Payload dragged when a task row is long-pressed and dragged out of the
/// Tasks subwindow in Split Screen mode. Carries the task id so a drop target
/// (currently the Calendar day cells) can act on the specific task.
class TaskDragData {
  const TaskDragData(this.taskId, this.title);
  final String taskId;
  final String title;
}

/// Inherited flag that turns task rows into draggables. It is only provided
/// (with [enabled] = true) while a Split Screen pairing that contains the
/// Tasks tab is active, so task-row dragging never interferes with normal
/// browsing / reordering outside split mode.
class TaskDragScope extends InheritedWidget {
  const TaskDragScope({
    super.key,
    required this.enabled,
    this.onDropOnDay,
    required super.child,
  });

  /// When true, task rows wrap themselves in a [LongPressDraggable].
  final bool enabled;

  /// Called when a dragged task is dropped on a calendar day cell. The handler
  /// sets the task's due date to [date].
  final void Function(String taskId, DateTime date)? onDropOnDay;

  static TaskDragScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TaskDragScope>();

  @override
  bool updateShouldNotify(covariant TaskDragScope oldWidget) =>
      enabled != oldWidget.enabled || onDropOnDay != oldWidget.onDropOnDay;
}
