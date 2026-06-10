import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'settings_controller.dart';

/// Settings → Advanced → Split Screen.
///
/// A master enable toggle plus two entry-method toggles. The entry-method
/// toggles are greyed out (disabled) while the feature is off; flipping both
/// of them off forces the feature off (handled in [SettingsController]).
class SplitScreenSettingsView extends StatelessWidget {
  const SplitScreenSettingsView({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.splitScreen),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (ctx, _) {
            final enabled = controller.splitScreenEnabled;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ToggleRow(
                    label: s.splitScreenEnable,
                    value: enabled,
                    onChanged: controller.updateSplitScreenEnabled,
                  ),
                  const SizedBox(height: 18),
                  _ToggleRow(
                    label: s.splitScreenFromMenu,
                    value: controller.splitScreenFromMenu,
                    enabled: enabled,
                    onChanged: controller.updateSplitScreenFromMenu,
                  ),
                  const SizedBox(height: 1),
                  _ToggleRow(
                    label: s.splitScreenFromDrag,
                    value: controller.splitScreenFromDrag,
                    enabled: enabled,
                    onChanged: controller.updateSplitScreenFromDrag,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      s.splitScreenHint,
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    final textColor = enabled
        ? CupertinoColors.label.resolveFrom(context)
        : CupertinoColors.tertiaryLabel.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 17, color: textColor),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}
