import '../localization/strings.dart';
import 'package:flutter/widgets.dart';

/// Global mirror of the user's currency preferences, kept in sync by
/// [SettingsController]. Money is formatted in dozens of places (rows, chips,
/// summary cards, budget bars); mirroring the two values here means those call
/// sites don't each have to be handed the settings controller — the same
/// approach `TimeFormatPref` uses for the 12/24-hour clock.
class FinanceCurrency {
  /// Symbol placed before the amount, e.g. `$`, `€`, `₴`.
  static String symbol = r'$';

  /// Whether amounts render their minor units (cents). Off suits currencies
  /// that are used in whole units (¥, ₩, …).
  static bool showDecimals = true;
}

/// Currency symbols offered in Settings → Finance. The user can also type a
/// custom one, so this is a shortcut list rather than an exhaustive set.
const List<String> kCurrencySymbols = [
  r'$',
  '€',
  '£',
  '₴',
  '₽',
  '¥',
  '₹',
  '₺',
  '₪',
  'zł',
  'Kč',
  'kr',
  'CHF',
  'R\$',
  'C\$',
  'A\$',
];

/// Formats [cents] (minor units) as a currency string, e.g. `$1,234.56`.
///
/// [signed] prefixes an explicit `+` / `−` (used by transaction rows to show
/// direction); otherwise the value is rendered as an absolute amount.
String formatMoney(
  int cents, {
  bool signed = false,
  String? symbol,
  bool? showDecimals,
}) {
  final sym = symbol ?? FinanceCurrency.symbol;
  final decimals = showDecimals ?? FinanceCurrency.showDecimals;
  final negative = cents < 0;
  final abs = cents.abs();

  final String body;
  if (decimals) {
    final whole = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    body = '${_group(whole)}.$frac';
  } else {
    // Round to the nearest whole unit so a 0.60 entry doesn't read as 0.
    body = _group((abs + 50) ~/ 100);
  }

  final prefix = signed ? (negative ? '−' : '+') : (negative ? '−' : '');
  return '$prefix$sym$body';
}

/// Groups the integer part with thin separators (1234567 → `1,234,567`).
String _group(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Parses user input (`12`, `12.5`, `12,50`, `1 234.56`) into minor units.
/// Returns null when the text holds no parsable amount, so callers can keep
/// the submit button disabled.
int? parseAmountToCents(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  // Accept both decimal separators and ignore grouping whitespace
  // (including the no-break spaces some keyboards insert).
  text = text.replaceAll(RegExp(r'\s'), '');
  // A comma is a decimal separator only when it isn't used for grouping
  // (i.e. there's no dot in the string).
  if (!text.contains('.')) text = text.replaceAll(',', '.');
  text = text.replaceAll(',', '');
  final value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) return null;
  final cents = (value.abs() * 100).round();
  return cents;
}

/// `March 2026` for the month navigator / section headers.
String formatMonthYear(BuildContext context, DateTime month) =>
    '${monthsLong(context)[month.month - 1]} ${month.year}';

/// Day header used in the transaction list: `Today`, `Yesterday`, or
/// `Mon, 3 Mar`.
String formatTransactionDay(BuildContext context, DateTime date, DateTime now) {
  final s = S.of(context);
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return s.today;
  if (diff == 1) return s.yesterday;
  final weekday = weekdaysShort(context)[day.weekday - 1];
  final month = monthsShort(context)[day.month - 1];
  return '$weekday, ${day.day} $month';
}
