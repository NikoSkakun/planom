import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/recurrence.dart';
import '../utils/selection_menu.dart';

/// Sentinel result wrapping the user's choice. `null` outer = dismissed,
/// `value: null` inner = "No Repeat".
class RecurrenceResult {
  const RecurrenceResult(this.value);
  final Recurrence? value;
}

/// Opens a small picker with the four most common repeats. Returns the
/// chosen [Recurrence] (or `null` value for "No Repeat"), or `null` if the
/// menu was dismissed.
Future<RecurrenceResult?> showRecurrencePicker(
  BuildContext context,
  Recurrence? current,
) async {
  final s = S.of(context);
  final result = await showSelectionMenu<String>(
    context: context,
    title: s.repeat,
    current: _currentKey(current),
    options: [
      SelectionMenuOption(value: 'none', label: s.repeatNone),
      SelectionMenuOption(value: 'daily', label: s.repeatDaily),
      SelectionMenuOption(value: 'weekly', label: s.repeatWeekly),
      SelectionMenuOption(value: 'monthly', label: s.repeatMonthly),
      SelectionMenuOption(value: 'yearly', label: s.repeatYearly),
    ],
  );
  if (result == null) return null;
  switch (result) {
    case 'none':
      return const RecurrenceResult(null);
    case 'daily':
      return const RecurrenceResult(Recurrence(type: RecurrenceType.daily));
    case 'weekly':
      return const RecurrenceResult(Recurrence(type: RecurrenceType.weekly));
    case 'monthly':
      return const RecurrenceResult(Recurrence(type: RecurrenceType.monthly));
    case 'yearly':
      return const RecurrenceResult(Recurrence(type: RecurrenceType.yearly));
  }
  return null;
}

String _currentKey(Recurrence? r) {
  if (r == null) return 'none';
  return r.type.name;
}

String formatRecurrence(BuildContext context, Recurrence? r) {
  final s = S.of(context);
  if (r == null) return s.repeatNone;
  switch (r.type) {
    case RecurrenceType.daily:
      return s.repeatDaily;
    case RecurrenceType.weekly:
      return s.repeatWeekly;
    case RecurrenceType.monthly:
      return s.repeatMonthly;
    case RecurrenceType.yearly:
      return s.repeatYearly;
  }
}
