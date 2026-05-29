import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/contact.dart';
import '../tasks/task_row.dart' show RoundedCheckbox;
import '../theme/app_theme.dart';

/// Row used inside Birthdays-type lists. Shows the contact's name, the
/// upcoming celebration date, and (when the year is known) the upcoming
/// age. Hides the checkbox unless the contact explicitly opted in via
/// "Show checkbox" in its detail view.
class ContactRow extends StatelessWidget {
  const ContactRow({
    super.key,
    required this.contact,
    required this.celebrationDate,
    required this.onTap,
    required this.onToggle,
  });

  final Contact contact;
  final DateTime celebrationDate;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final age = contact.birthYear != null
        ? celebrationDate.year - contact.birthYear!
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (contact.isCompletable)
          MergeSemantics(
            child: Semantics(
              label: s.a11yToggleComplete,
              checked: contact.isCompleted,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 9, bottom: 9),
                  child: RoundedCheckbox(
                    checked: contact.isCompleted,
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
                        contact.name,
                        style: TextStyle(
                          fontSize: 16,
                          color: contact.isCompleted
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
                      if (contact.note != null && contact.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            contact.note!,
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
