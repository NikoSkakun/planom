import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../utils/dropdown_row.dart';

/// Dropdown shown by the ⋯ button in a tab's nav bar when the Settings tab is
/// hidden. Mirrors the Tasks tab: tapping ⋯ opens this menu, and Settings opens
/// only when its row is tapped — not immediately on the ⋯ tap.
class SettingsMenuOverlay extends StatelessWidget {
  const SettingsMenuOverlay({
    super.key,
    required this.onDismiss,
    required this.onSettings,
  });

  final VoidCallback onDismiss;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.paddingOf(context).top + 44.0 + 4.0;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: const SizedBox.expand(),
        ),
        Positioned(
          top: topOffset,
          right: 8,
          child: Container(
            width: 220,
            decoration: AppColors.menuDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownRow(
                  label: S.of(context).settings,
                  icon: CupertinoIcons.gear_alt,
                  onTap: onSettings,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
