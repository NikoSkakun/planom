import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

import '../localization/strings.dart';
import '../models/task.dart';
import '../utils/task_drag_scope.dart';
import 'calendar_date_picker.dart';
import 'task_field_prefs.dart';

/// Shared proxy decorator for task drag-reorder animation.
Widget taskProxyDecorator(
    Widget child, int index, Animation<double> animation) {
  return Container(
    decoration: const BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class TaskDeleteBackground extends StatelessWidget {
  const TaskDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: CupertinoColors.destructiveRed,
      child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
    );
  }
}

class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    this.showList = false,
    this.listColor,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final bool showList;
  final Color? listColor;

  /// Returns true when the task's due date is in the past (strictly before
  /// today) and it hasn't been completed yet. Completed tasks don't carry an
  /// overdue badge even if their date is old.
  bool _isOverdue() {
    final due = task.dueDate;
    if (due == null || task.isCompleted) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(due.year, due.month, due.day).isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final dueDate = task.dueDate;
    final dateLabel = dueDate != null
        ? formatTaskDateRelative(context, dueDate, doTime: task.doTime)
        : null;
    final isOverdue = _isOverdue();
    final dateColor = isOverdue
        ? CupertinoColors.destructiveRed
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    final content = Row(
      // Top-align so the checkbox lines up with the first line of the
      // title when the title wraps to multiple lines.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox zone — includes the vertical padding so the full item height is tappable
        MergeSemantics(
          child: Semantics(
            label: S.of(context).a11yToggleComplete,
            checked: task.isCompleted,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 7, bottom: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoundedCheckbox(
                      checked: task.isCompleted,
                      priority: task.priority,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Text zone
        Expanded(
          child: MergeSemantics(
            child: Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Padding(
                  padding:
                      const EdgeInsets.only(top: 7, bottom: 7, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                color: task.isCompleted
                                    ? CupertinoColors.secondaryLabel
                                        .resolveFrom(context)
                                    : null,
                              ),
                            ),
                          ),
                          if (dateLabel != null) ...[
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: dateColor,
                                  fontWeight: isOverdue
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (task.note != null && task.note!.isNotEmpty)
                        Text(
                          task.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      if (showList && listColor != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: listColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    // In Split Screen mode (Tasks paired with Calendar) task rows become
    // draggable: long-press and drop onto a calendar day to set the due date.
    final dragScope = TaskDragScope.of(context);
    if (dragScope?.enabled == true) {
      return LongPressDraggable<TaskDragData>(
        data: TaskDragData(task.id, task.title),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: _DragFeedback(title: task.title),
        childWhenDragging: Opacity(opacity: 0.4, child: content),
        child: content,
      );
    }
    return content;
  }

  static Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return CupertinoColors.systemBlue;
      case 2:
        return CupertinoColors.systemOrange;
      case 3:
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }
}

/// Small pill shown under the finger while dragging a task row onto the
/// calendar in Split Screen mode.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      // Offset so the pill sits up-left of the fingertip rather than under it.
      offset: const Offset(8, 8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          title.isEmpty ? S.of(context).untitled : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class RoundedCheckbox extends StatelessWidget {
  const RoundedCheckbox({super.key, required this.checked, this.priority = 0});

  final bool checked;
  final int priority;

  @override
  Widget build(BuildContext context) {
    final borderColor = !checked && priority > 0
        ? TaskRow._priorityColor(priority)
        : CupertinoColors.tertiaryLabel.resolveFrom(context);
    final style = TaskCheckboxAppearance.current;
    final BoxDecoration deco;
    switch (style) {
      case TaskCheckboxStyle.sharpRect:
        deco = BoxDecoration(
          // borderRadius omitted → sharp corners
          color: checked ? AppColors.accent : null,
          border: checked ? null : Border.all(color: borderColor, width: 1.5),
        );
      case TaskCheckboxStyle.circle:
        deco = BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? AppColors.accent : null,
          border: checked ? null : Border.all(color: borderColor, width: 1.5),
        );
      case TaskCheckboxStyle.roundedRect:
        deco = BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: checked ? AppColors.accent : null,
          border: checked ? null : Border.all(color: borderColor, width: 1.5),
        );
    }

    final size = 20 * AppScale.factor;
    return Container(
      width: size,
      height: size,
      decoration: deco,
      child: checked
          ? Icon(CupertinoIcons.checkmark,
              size: 11 * AppScale.factor,
              color: CupertinoColors.white)
          : null,
    );
  }
}
