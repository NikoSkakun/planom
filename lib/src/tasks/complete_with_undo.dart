import 'package:flutter/widgets.dart';

import '../localization/strings.dart';
import '../models/task.dart';
import '../utils/undo_controller.dart';
import 'task_controller.dart';

/// Toggles [task]'s completion and, when it transitions to *completed*,
/// surfaces a 5-second Undo banner that un-completes it.
///
/// No banner is shown when un-completing a task or when a recurring task
/// merely advances to its next occurrence — there's nothing destructive to
/// revert in those cases. This keeps the Undo affordance consistent across
/// every list (smart lists, user lists, the calendar day view) so checking a
/// task off always offers a quick way back.
void toggleTaskCompletedWithUndo(
  BuildContext context,
  TaskController controller,
  Task task,
) {
  // Capture before the async gap so we never touch a possibly-unmounted
  // context after the await.
  final undo = UndoScope.maybeOf(context);
  final label = S.of(context).taskCompletedToast;
  controller.toggleCompleted(task.id).then((result) {
    if (result == TaskToggleResult.completed) {
      undo?.show(
        label: label,
        onUndo: () => controller.toggleCompleted(task.id),
      );
    }
  });
}
