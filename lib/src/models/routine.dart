import 'package:uuid/uuid.dart';

import 'item.dart';
import 'routine_reminder.dart';

/// A habit tracked per calendar day. Each day is recorded independently via
/// [RoutineEntry] rows, so history is preserved and the routine "resets"
/// automatically every day (no entry for a day = not done that day).
///
/// Schedule types ([frequencyType]):
/// - `'daily'`         — appears every day.
/// - `'specific_days'` — appears only on the weekdays listed in [weekdays]
///                       (0 = Mon … 6 = Sun); the list always has ≥1 day.
/// - `'interval'`      — appears every [intervalDays] days from [startDate].
///                       With [waitForCompletion], the next occurrence is
///                       anchored to the completion date and a missed occurrence
///                       carries forward as overdue (shifting future ones).
class Routine extends AppItem {
  final String name;
  final int iconColor; // ARGB tint for SF-symbol icons (ignored for photos)

  final String goalType; // 'achieve_all' | 'certain_amount'
  final int? goalAmount;
  final String? goalUnit;
  final int? recordAmount;

  final String frequencyType; // 'daily' | 'specific_days' | 'interval'

  /// Selected weekdays for `specific_days` (0 = Mon … 6 = Sun). Null otherwise.
  final List<int>? weekdays;

  /// Day the routine starts being active (date-only). Defaults to the creation
  /// day when null.
  final DateTime? startDate;

  /// Interval length in days for `interval` routines (≥ 1).
  final int? intervalDays;

  /// `interval` only: when true, the next occurrence is scheduled relative to
  /// the completion date rather than on a fixed grid, and a missed occurrence
  /// stays overdue until completed.
  final bool waitForCompletion;

  /// Reminders for this routine (see [RoutineReminder]).
  final List<RoutineReminder> reminders;

  /// Manual display order (ascending). Ties break on creation date.
  final int sortOrder;

  Routine({
    String? id,
    DateTime? creationDate,
    String iconId = 'drop.fill',
    required this.name,
    this.iconColor = 0xFF007AFF,
    required this.goalType,
    this.goalAmount,
    this.goalUnit,
    this.recordAmount,
    this.frequencyType = 'daily',
    this.weekdays,
    this.startDate,
    this.intervalDays,
    this.waitForCompletion = false,
    this.reminders = const [],
    this.sortOrder = 0,
  }) : super(
          id: id ?? const Uuid().v4(),
          creationDate: creationDate ?? DateTime.now(),
          iconId: iconId,
        );

  Routine copyWith({
    String? name,
    String? iconId,
    int? iconColor,
    String? goalType,
    int? goalAmount,
    bool clearGoalAmount = false,
    String? goalUnit,
    bool clearGoalUnit = false,
    int? recordAmount,
    bool clearRecordAmount = false,
    String? frequencyType,
    List<int>? weekdays,
    bool clearWeekdays = false,
    DateTime? startDate,
    bool clearStartDate = false,
    int? intervalDays,
    bool clearIntervalDays = false,
    bool? waitForCompletion,
    List<RoutineReminder>? reminders,
    int? sortOrder,
  }) {
    return Routine(
      id: id,
      creationDate: creationDate,
      iconId: iconId ?? this.iconId,
      name: name ?? this.name,
      iconColor: iconColor ?? this.iconColor,
      goalType: goalType ?? this.goalType,
      goalAmount: clearGoalAmount ? null : (goalAmount ?? this.goalAmount),
      goalUnit: clearGoalUnit ? null : (goalUnit ?? this.goalUnit),
      recordAmount:
          clearRecordAmount ? null : (recordAmount ?? this.recordAmount),
      frequencyType: frequencyType ?? this.frequencyType,
      weekdays: clearWeekdays ? null : (weekdays ?? this.weekdays),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      intervalDays:
          clearIntervalDays ? null : (intervalDays ?? this.intervalDays),
      waitForCompletion: waitForCompletion ?? this.waitForCompletion,
      reminders: reminders ?? this.reminders,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'creationDate': creationDate.millisecondsSinceEpoch,
        'iconId': iconId,
        'iconColor': iconColor,
        'name': name,
        'goalType': goalType,
        'goalAmount': goalAmount,
        'goalUnit': goalUnit,
        'recordAmount': recordAmount,
        'frequencyType': frequencyType,
        'weekdays': weekdays?.join(','),
        'startDate': startDate?.millisecondsSinceEpoch,
        'intervalDays': intervalDays,
        'waitForCompletion': waitForCompletion ? 1 : 0,
        'reminders': RoutineReminder.encode(reminders),
        'sortOrder': sortOrder,
      };

  factory Routine.fromMap(Map<String, dynamic> map) => Routine(
        id: map['id'] as String,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
        iconId: map['iconId'] as String,
        iconColor: map['iconColor'] as int,
        name: map['name'] as String,
        goalType: map['goalType'] as String,
        goalAmount: map['goalAmount'] as int?,
        goalUnit: map['goalUnit'] as String?,
        recordAmount: map['recordAmount'] as int?,
        // Tolerate legacy rows / backups where newer fields are absent.
        frequencyType: (map['frequencyType'] as String?) ?? 'daily',
        weekdays: _parseWeekdays(map['weekdays'] as String?),
        startDate: map['startDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
        intervalDays: map['intervalDays'] as int?,
        waitForCompletion: (map['waitForCompletion'] as int? ?? 0) == 1,
        reminders: RoutineReminder.decode(map['reminders'] as String?),
        sortOrder: map['sortOrder'] as int? ?? 0,
      );

  // Empty strings round-trip as `null` so an empty list does not crash
  // `int.parse('')` on the next load.
  static List<int>? _parseWeekdays(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw.split(',').map(int.parse).toList();
  }
}
