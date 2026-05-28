import 'package:flutter/widgets.dart';

import '../localization/strings.dart';
import '../models/task.dart';
import '../utils/undo_controller.dart';
import 'task_controller.dart';
import 'task_field_prefs.dart';

/// Toggles [task]'s completion and, when it transitions to *completed* and the
/// user has opted in (Settings → Tasks → "Undo on completion"), surfaces a
/// 5-second Undo banner that un-completes it.
///
/// No banner is shown when the preference is off (the default), when
/// un-completing a task, or when a recurring task merely advances to its next
/// occurrence — there's nothing destructive to revert in those cases. When the
/// banner is enabled it behaves identically across every list (smart lists,
/// user lists) so checking a task off always offers a quick way back.
void toggleTaskCompletedWithUndo(
  BuildContext context,
  TaskController controller,
  Task task,
) {
  // Off by default — when disabled, just toggle silently.
  if (!TaskCompletionUndoPref.enabled) {
    controller.toggleCompleted(task.id);
    return;
  }
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
