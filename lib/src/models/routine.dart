import 'package:uuid/uuid.dart';

import 'item.dart';

class Routine extends AppItem {
  final String name;
  final int iconColor; // ARGB

  final String goalType; // 'achieve_all' | 'certain_amount'
  final int? goalAmount;
  final String? goalUnit;
  final int? recordAmount;

  final String frequencyType; // 'daily' | 'days_after_complete'
  final List<int>? weekdays; // 0=Mon … 6=Sun; null means all days
  final int? daysAfterComplete;

  final String autoReset; // 'everyday' | 'none'

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
    required this.frequencyType,
    this.weekdays,
    this.daysAfterComplete,
    required this.autoReset,
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
    int? daysAfterComplete,
    bool clearDaysAfterComplete = false,
    String? autoReset,
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
      daysAfterComplete: clearDaysAfterComplete
          ? null
          : (daysAfterComplete ?? this.daysAfterComplete),
      autoReset: autoReset ?? this.autoReset,
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
        'daysAfterComplete': daysAfterComplete,
        'autoReset': autoReset,
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
        frequencyType: map['frequencyType'] as String,
        weekdays: _parseWeekdays(map['weekdays'] as String?),
        daysAfterComplete: map['daysAfterComplete'] as int?,
        autoReset: map['autoReset'] as String,
      );

  // Empty strings round-trip as `null` so an empty weekday list does not crash
  // `int.parse('')` on the next load.
  static List<int>? _parseWeekdays(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw.split(',').map(int.parse).toList();
  }
}
