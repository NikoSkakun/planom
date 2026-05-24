import 'dart:convert';

enum RecurrenceType { daily, weekly, monthly, yearly }

/// A simple repeating-task schedule. We don't aim for full RRULE — the four
/// common cases (every N days/weeks/months/years, plus weekly weekday picker)
/// cover ~99% of personal productivity use.
class Recurrence {
  const Recurrence({
    required this.type,
    this.interval = 1,
    this.weekdays = const [],
  });

  final RecurrenceType type;

  /// Repeat every N units of [type]. `1` = every day/week/month/year.
  final int interval;

  /// Only meaningful for [RecurrenceType.weekly]. 0=Mon … 6=Sun.
  final List<int> weekdays;

  /// Serialised as JSON in the `tasks.recurrence` column. `null` = no repeat.
  String toJson() => jsonEncode({
        'type': type.name,
        'interval': interval,
        if (weekdays.isNotEmpty) 'weekdays': weekdays,
      });

  static Recurrence? parse(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      final type = RecurrenceType.values.firstWhere(
        (e) => e.name == m['type'],
        orElse: () => RecurrenceType.daily,
      );
      return Recurrence(
        type: type,
        interval: (m['interval'] as int?) ?? 1,
        weekdays:
            (m['weekdays'] as List?)?.map((e) => e as int).toList() ?? const [],
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the next occurrence at or after [from]. The [from] argument is
  /// the date the user just completed — the next instance is at least one
  /// `interval` step away.
  DateTime nextAfter(DateTime from) {
    switch (type) {
      case RecurrenceType.daily:
        return DateTime(from.year, from.month, from.day + interval);
      case RecurrenceType.weekly:
        if (weekdays.isEmpty) {
          return DateTime(from.year, from.month, from.day + 7 * interval);
        }
        // Find the next weekday in our list that's at least 1 day in the
        // future. If we exhaust this week's options, jump `interval` weeks
        // forward to the first selected weekday.
        final fromWd = from.weekday - 1; // 0=Mon..6=Sun
        for (int i = 1; i <= 7; i++) {
          final wd = (fromWd + i) % 7;
          if (weekdays.contains(wd)) {
            return DateTime(from.year, from.month, from.day + i);
          }
        }
        // Shouldn't reach here with a non-empty list, but fall back safely.
        return DateTime(from.year, from.month, from.day + 7 * interval);
      case RecurrenceType.monthly:
        var year = from.year;
        var month = from.month + interval;
        while (month > 12) {
          year++;
          month -= 12;
        }
        // Clamp the day if the target month is shorter (e.g. Jan 31 → Feb 28).
        final daysInTarget = DateTime(year, month + 1, 0).day;
        final day = from.day > daysInTarget ? daysInTarget : from.day;
        return DateTime(year, month, day);
      case RecurrenceType.yearly:
        return DateTime(from.year + interval, from.month, from.day);
    }
  }
}
