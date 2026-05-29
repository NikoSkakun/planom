import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

/// Filled-circle checkbox used in front of rows while a SelectionController
/// is active. Matches the iOS Reminders / Mail selection look.
class SelectionCheckbox extends StatelessWidget {
  const SelectionCheckbox({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    if (checked) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.checkmark,
          size: 14,
          color: CupertinoColors.white,
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          width: 1.5,
        ),
      ),
    );
  }
}
