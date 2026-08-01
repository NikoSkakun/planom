import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'finance_format.dart';

/// Result of [showMoneyAmountDialog]: null = cancelled, `0` = cleared,
/// anything else = the amount in minor units (cents).
Future<int?> showMoneyAmountDialog(
  BuildContext context, {
  required String title,
  String? message,
  int? current,
  bool allowClear = true,
}) {
  final s = S.of(context);
  final ctrl = TextEditingController(
    text: (current ?? 0) > 0 ? _plain(current!) : '',
  );
  return showCupertinoDialog<int>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                  ),
                ),
              ),
            CupertinoTextField(
              controller: ctrl,
              autofocus: true,
              textAlign: TextAlign.center,
              placeholder: '${FinanceCurrency.symbol}0',
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              onSubmitted: (_) =>
                  Navigator.of(ctx).pop(parseAmountToCents(ctrl.text) ?? 0),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.cancel),
        ),
        if (allowClear && (current ?? 0) > 0)
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(0),
            child: Text(s.clear),
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () =>
              Navigator.of(ctx).pop(parseAmountToCents(ctrl.text) ?? 0),
          child: Text(
            s.done,
            style:
                TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Plain, parseable rendering of [cents] for the text field (no symbol or
/// grouping separators).
String _plain(int cents) {
  final whole = cents ~/ 100;
  final frac = cents % 100;
  return frac == 0 ? '$whole' : '$whole.${frac.toString().padLeft(2, '0')}';
}
