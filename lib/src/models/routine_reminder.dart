import 'dart:convert';

/// A reminder attached to a [Routine]. Routines have no single "due time", so
/// reminders are expressed as clock times / delays rather than offsets.
///
/// Three kinds:
/// - `time`      — a fixed clock time, fires once on each active day.
///                 [value] = minute of day (0..1439).
/// - `spread`    — amount goals only: starting at [value] (minute of day), one
///                 reminder every [interval] minutes, one per planned iteration,
///                 spread through the day.
/// - `afterEach` — amount goals only: fires [value] minutes after each logged
///                 unit, until the daily goal is met (scheduled reactively).
class RoutineReminder {
  static const typeTime = 'time';
  static const typeSpread = 'spread';
  static const typeAfterEach = 'afterEach';

  final String type;
  final int value; // minute-of-day (time/spread) or delay minutes (afterEach)
  final int? interval; // spread only: minutes between reminders

  const RoutineReminder({
    required this.type,
    required this.value,
    this.interval,
  });

  const RoutineReminder.time(int minuteOfDay)
      : type = typeTime,
        value = minuteOfDay,
        interval = null;

  const RoutineReminder.spread({required int startMinute, required int every})
      : type = typeSpread,
        value = startMinute,
        interval = every;

  const RoutineReminder.afterEach(int delayMinutes)
      : type = typeAfterEach,
        value = delayMinutes,
        interval = null;

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        if (interval != null) 'interval': interval,
      };

  factory RoutineReminder.fromJson(Map<String, dynamic> m) => RoutineReminder(
        type: m['type'] as String,
        value: (m['value'] as num).toInt(),
        interval: (m['interval'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is RoutineReminder &&
      other.type == type &&
      other.value == value &&
      other.interval == interval;

  @override
  int get hashCode => Object.hash(type, value, interval);

  static String encode(List<RoutineReminder> list) =>
      jsonEncode(list.map((r) => r.toJson()).toList());

  static List<RoutineReminder> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((m) => RoutineReminder.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
