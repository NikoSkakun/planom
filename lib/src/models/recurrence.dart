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

  /// UTC-midnight day index for [d], so day arithmetic is DST-safe (no 23h/25h
  /// drift from local-time `difference`).
  static int _epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// Whether [date] is an occurrence of a series anchored at [start]. Used to
  /// expand a recurring event onto every day it repeats on. [date] on or after
  /// [start] only; the start day itself always counts.
  bool occursOn(DateTime start, DateTime date) {
    final sDay = _epochDay(start);
    final dDay = _epochDay(date);
    if (dDay < sDay) return false;
    final s = DateTime(start.year, start.month, start.day);
    final d = DateTime(date.year, date.month, date.day);
    switch (type) {
      case RecurrenceType.daily:
        return (dDay - sDay) % interval == 0;
      case RecurrenceType.weekly:
        if (weekdays.isEmpty) {
          if (d.weekday != s.weekday) return false;
          return ((dDay - sDay) ~/ 7) % interval == 0;
        }
        final wd = d.weekday - 1; // 0=Mon … 6=Sun
        if (!weekdays.contains(wd)) return false;
        // Compare Monday-aligned week indices so interval skips count whole
        // weeks regardless of which weekday start/date fall on.
        final sMon = sDay - (s.weekday - 1);
        final dMon = dDay - (d.weekday - 1);
        return ((dMon - sMon) ~/ 7) % interval == 0;
      case RecurrenceType.monthly:
        final monthsDiff = (d.year - s.year) * 12 + (d.month - s.month);
        if (monthsDiff < 0 || monthsDiff % interval != 0) return false;
        final daysInTarget = DateTime(d.year, d.month + 1, 0).day;
        final targetDay = s.day > daysInTarget ? daysInTarget : s.day;
        return d.day == targetDay;
      case RecurrenceType.yearly:
        final yearsDiff = d.year - s.year;
        if (yearsDiff < 0 || yearsDiff % interval != 0) return false;
        // Feb 29 anchors fall back to Feb 28 in non-leap years.
        if (s.month == 2 && s.day == 29) {
          final isLeap =
              (d.year % 4 == 0 && d.year % 100 != 0) || d.year % 400 == 0;
          return d.month == 2 && d.day == (isLeap ? 29 : 28);
        }
        return d.month == s.month && d.day == s.day;
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
