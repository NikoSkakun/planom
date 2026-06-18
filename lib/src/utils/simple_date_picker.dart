import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';

/// A minimal modal date picker (date only, no time). Returns the chosen day at
/// midnight, or null if dismissed. Used by Finance and Goals where a plain due
/// date — without the task/event time-of-day machinery — is all that's needed.
Future<DateTime?> showSimpleDatePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? minimum,
  DateTime? maximum,
}) async {
  final s = S.of(context);
  var selected = initial ?? DateTime.now();
  selected = DateTime(selected.year, selected.month, selected.day);
  DateTime? result;
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => Container(
      height: 320,
      color: CupertinoColors.systemBackground.resolveFrom(ctx),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text(s.cancel),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                CupertinoButton(
                  child: Text(s.done),
                  onPressed: () {
                    result = selected;
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selected,
                minimumDate: minimum,
                maximumDate: maximum,
                onDateTimeChanged: (d) =>
                    selected = DateTime(d.year, d.month, d.day),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result;
}

/// Formats a date as a short, locale-agnostic human string (e.g. "18 Jun 2026").
String formatShortDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
