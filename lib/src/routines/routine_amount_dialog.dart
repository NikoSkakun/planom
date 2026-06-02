import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';

/// Prompts the user to type the completed amount for a manual-entry routine.
/// Pre-fills [current]; returns the new absolute amount, or null if cancelled.
Future<int?> showRoutineAmountDialog(
  BuildContext context, {
  required String name,
  required int current,
  String? unit,
}) {
  final ctrl = TextEditingController(text: current > 0 ? '$current' : '');
  final s = S.of(context);
  return showCupertinoDialog<int>(
    context: context,
    builder: (ctx) {
      return CupertinoAlertDialog(
        title: Text(name),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((unit ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    s.recordAmountPrompt(unit!),
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                    ),
                  ),
                ),
              CupertinoTextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                placeholder: '0',
                onSubmitted: (_) =>
                    Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim()) ?? 0),
            child: Text(s.done,
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    },
  );
}
