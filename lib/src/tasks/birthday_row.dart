import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'task_row.dart';

/// Row used inside Birthdays-typed lists. Shows the contact's name, the
/// upcoming celebration date, and (when the year is known) the upcoming
/// age. Hides the checkbox unless the user explicitly opted in to
/// completing it.
class BirthdayRow extends StatelessWidget {
  const BirthdayRow({
    super.key,
    required this.task,
    required this.celebrationDate,
    required this.onTap,
    required this.onToggle,
  });

  final Task task;
  final DateTime celebrationDate;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final age = task.birthYear != null
        ? celebrationDate.year - task.birthYear!
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (task.isCompletable)
          MergeSemantics(
            child: Semantics(
              label: s.a11yToggleComplete,
              checked: task.isCompleted,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 9, bottom: 9),
                  child: RoundedCheckbox(
                    checked: task.isCompleted,
                    priority: task.priority,
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 9, bottom: 9),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.gift_fill,
                size: 16,
                color: AppColors.accent,
              ),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: MergeSemantics(
            child: Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.only(top: 9, bottom: 9, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          color: task.isCompleted
                              ? CupertinoColors.secondaryLabel
                                  .resolveFrom(context)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatDate(celebrationDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                          if (age != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· ${s.turns} $age',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (task.note != null && task.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            task.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
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
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
