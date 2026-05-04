import 'package:flutter/cupertino.dart';

import '../models/task.dart';
import 'calendar_date_picker.dart';

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
    this.listName,
    this.isOverdue = false,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final bool showList;
  final String? listName;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onToggle,
              child: _RoundedCheckbox(
                checked: task.isCompleted,
                priority: task.priority,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      color: task.isCompleted
                          ? CupertinoColors.secondaryLabel.resolveFrom(context)
                          : null,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
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
                  if (isOverdue && task.dueDate != null)
                    Text(
                      formatTaskDate(task.dueDate!, doTime: task.doTime),
                      style: const TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.destructiveRed,
                      ),
                    )
                  else if (!isOverdue && task.dueDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.calendar,
                            size: 11,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatTaskDate(task.dueDate!,
                                doTime: task.doTime),
                            style: TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (showList && listName != null)
                    Text(
                      listName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                ],
              ),
            ),
            if (task.priority > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  CupertinoIcons.flag_fill,
                  size: 13,
                  color: _priorityColor(task.priority),
                ),
              ),
          ],
        ),
      ),
    );
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

class _RoundedCheckbox extends StatelessWidget {
  const _RoundedCheckbox({required this.checked, this.priority = 0});

  final bool checked;
  final int priority;

  @override
  Widget build(BuildContext context) {
    final borderColor = !checked && priority > 0
        ? TaskRow._priorityColor(priority)
        : CupertinoColors.tertiaryLabel.resolveFrom(context);

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: checked ? const Color(0xFFFF4D00) : null,
        border: checked
            ? null
            : Border.all(color: borderColor, width: 1.5),
      ),
      child: checked
          ? const Icon(CupertinoIcons.checkmark,
              size: 13, color: CupertinoColors.white)
          : null,
    );
  }
}
