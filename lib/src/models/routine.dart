import 'package:uuid/uuid.dart';

import 'item.dart';

/// A daily habit. Each calendar day is tracked independently via
/// [RoutineEntry] rows, so history is preserved and the routine "resets"
/// automatically every day (no entry for a day = not done that day).
///
/// NOTE: only daily frequency is supported right now. The weekly /
/// "days after completion" schedules and the auto-reset / carry-over options
/// were removed in the routines refactor and will be reintroduced later — see
/// the commented-out UI in `routine_creation_view.dart`.
class Routine extends AppItem {
  final String name;
  final int iconColor; // ARGB tint for SF-symbol icons (ignored for photos)

  final String goalType; // 'achieve_all' | 'certain_amount'
  final int? goalAmount;
  final String? goalUnit;
  final int? recordAmount;

  /// Reserved for future schedule types. Always 'daily' today.
  final String frequencyType;

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
        // Tolerate legacy rows / backups where this is absent.
        frequencyType: (map['frequencyType'] as String?) ?? 'daily',
      );
}
