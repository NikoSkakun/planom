import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';

/// Implicit virtual "Completed" header shown at the bottom of a task list.
/// Not editable — it simply counts the completed tasks and toggles their
/// visibility. Shared by user lists and the smart-list shell so the
/// collapse/expand affordance looks and behaves identically everywhere.
class CompletedSectionHeader extends StatelessWidget {
  const CompletedSectionHeader({
    super.key,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            AnimatedRotation(
              duration: const Duration(milliseconds: 180),
              turns: expanded ? 0 : -0.25,
              child: Icon(
                CupertinoIcons.chevron_down,
                size: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${S.of(context).sectionCompleted} ($count)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
