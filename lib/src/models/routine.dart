import 'package:uuid/uuid.dart';

import 'item.dart';

/// A habit tracked per calendar day. Each day is recorded independently via
/// [RoutineEntry] rows, so history is preserved and the routine "resets"
/// automatically every day (no entry for a day = not done that day).
///
/// Two schedule types are supported:
/// - `'daily'` — appears every day.
/// - `'specific_days'` — appears only on the weekdays listed in [weekdays]
///   (0 = Mon … 6 = Sun); the list always has at least one day.
///
/// NOTE: the "days after completion" schedule and the auto-reset / carry-over
/// options were removed in the routines refactor and may be reintroduced later.
class Routine extends AppItem {
  final String name;
  final int iconColor; // ARGB tint for SF-symbol icons (ignored for photos)

  final String goalType; // 'achieve_all' | 'certain_amount'
  final int? goalAmount;
  final String? goalUnit;
  final int? recordAmount;

  final String frequencyType; // 'daily' | 'specific_days'

  /// Selected weekdays for `specific_days` (0 = Mon … 6 = Sun). Null for
  /// `daily`.
  final List<int>? weekdays;

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
        // Tolerate legacy rows / backups where these are absent.
        frequencyType: (map['frequencyType'] as String?) ?? 'daily',
        weekdays: _parseWeekdays(map['weekdays'] as String?),
      );

  // Empty strings round-trip as `null` so an empty list does not crash
  // `int.parse('')` on the next load.
  static List<int>? _parseWeekdays(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw.split(',').map(int.parse).toList();
  }
}
