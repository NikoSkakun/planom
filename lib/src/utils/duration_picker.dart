import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'selection_menu.dart';

String formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

const _kDurationPresets = [15, 30, 45, 60, 90, 120, 180, 240];

/// Shows a duration picker with preset options plus a custom entry.
/// Returns the selected duration in minutes, `null` to clear, or
/// [current] if the picker was dismissed without a selection.
Future<int?> showDurationPicker(BuildContext context, int? current) async {
  const customSentinel = -2;
  const clearSentinel = -1;
  final s = S.of(context);

  // Show a checkmark on the current value only when it matches a preset.
  final presetCurrent =
      current != null && _kDurationPresets.contains(current) ? current : null;

  final result = await showSelectionMenu<int>(
    context: context,
    title: s.duration,
    current: presetCurrent,
    options: [
      for (final m in _kDurationPresets)
        SelectionMenuOption(value: m, label: formatDuration(m)),
      SelectionMenuOption(
        value: customSentinel,
        label: s.customDots,
        icon: CupertinoIcons.pencil,
      ),
      if (current != null)
        SelectionMenuOption(
          value: clearSentinel,
          label: s.clear,
          isDestructive: true,
        ),
    ],
  );

  if (result == null) return current;
  if (result == clearSentinel) return null;
  if (result == customSentinel) {
    return _showCustomDurationSheet(context, current);
  }
  return result;
}

Future<int?> _showCustomDurationSheet(
    BuildContext context, int? current) async {
  final initialDuration = Duration(minutes: current ?? 60);
  Duration selected = initialDuration;

  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) {
      final bg = CupertinoColors.systemBackground.resolveFrom(ctx);
      final separator = CupertinoColors.separator.resolveFrom(ctx);
      return Container(
        height: 320,
        color: bg,
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: separator, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(S.of(ctx).cancel),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(
                      S.of(ctx).ok,
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: initialDuration,
                onTimerDurationChanged: (d) => selected = d,
              ),
            ),
          ],
        ),
      );
    },
  );

  if (confirmed != true) return current;
  final minutes = selected.inMinutes;
  return minutes > 0 ? minutes : current;
}
