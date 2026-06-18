import 'package:uuid/uuid.dart';

/// A long-term objective the user is working toward.
///
/// Two flavours ([type]):
/// - `numeric`  — measurable target ([targetAmount] of [unit], e.g. "Read 24
///                books"). Progress = [currentAmount] / [targetAmount].
/// - `milestone`— a checklist of [GoalMilestone] steps. Progress = done / total
///                milestones. When it has no milestones it behaves as a simple
///                done/not-done goal driven by [isCompleted].
class Goal {
  static const typeNumeric = 'numeric';
  static const typeMilestone = 'milestone';

  final String id;
  final String title;
  final String? note;

  /// SF-symbol key understood by [goalIconData], or a custom `icons/…` path.
  final String iconId;
  final int colorValue; // ARGB tint

  final String type; // numeric | milestone

  /// numeric only.
  final int? targetAmount;
  final int currentAmount;
  final String? unit;

  final DateTime startDate;
  final DateTime? targetDate;

  final bool isCompleted;
  final DateTime? completionDate;
  final bool isArchived;

  final int sortOrder;
  final DateTime creationDate;

  Goal({
    String? id,
    required this.title,
    this.note,
    this.iconId = 'flag',
    this.colorValue = 0xFFFF9500,
    this.type = typeMilestone,
    this.targetAmount,
    this.currentAmount = 0,
    this.unit,
    DateTime? startDate,
    this.targetDate,
    this.isCompleted = false,
    this.completionDate,
    this.isArchived = false,
    this.sortOrder = 0,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now(),
        startDate = startDate ?? creationDate ?? DateTime.now();

  bool get isNumeric => type == typeNumeric;

  Goal copyWith({
    String? title,
    String? note,
    bool clearNote = false,
    String? iconId,
    int? colorValue,
    String? type,
    int? targetAmount,
    bool clearTargetAmount = false,
    int? currentAmount,
    String? unit,
    bool clearUnit = false,
    DateTime? startDate,
    DateTime? targetDate,
    bool clearTargetDate = false,
    bool? isCompleted,
    DateTime? completionDate,
    bool clearCompletionDate = false,
    bool? isArchived,
    int? sortOrder,
  }) =>
      Goal(
        id: id,
        creationDate: creationDate,
        title: title ?? this.title,
        note: clearNote ? null : (note ?? this.note),
        iconId: iconId ?? this.iconId,
        colorValue: colorValue ?? this.colorValue,
        type: type ?? this.type,
        targetAmount:
            clearTargetAmount ? null : (targetAmount ?? this.targetAmount),
        currentAmount: currentAmount ?? this.currentAmount,
        unit: clearUnit ? null : (unit ?? this.unit),
        startDate: startDate ?? this.startDate,
        targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
        isCompleted: isCompleted ?? this.isCompleted,
        completionDate: clearCompletionDate
            ? null
            : (completionDate ?? this.completionDate),
        isArchived: isArchived ?? this.isArchived,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'note': note,
        'iconId': iconId,
        'colorValue': colorValue,
        'type': type,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'unit': unit,
        'startDate': startDate.millisecondsSinceEpoch,
        'targetDate': targetDate?.millisecondsSinceEpoch,
        'isCompleted': isCompleted ? 1 : 0,
        'completionDate': completionDate?.millisecondsSinceEpoch,
        'isArchived': isArchived ? 1 : 0,
        'sortOrder': sortOrder,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory Goal.fromMap(Map<String, dynamic> map) => Goal(
        id: map['id'] as String,
        title: map['title'] as String,
        note: map['note'] as String?,
        iconId: (map['iconId'] as String?) ?? 'flag',
        colorValue: (map['colorValue'] as int?) ?? 0xFFFF9500,
        type: (map['type'] as String?) ?? typeMilestone,
        targetAmount: map['targetAmount'] as int?,
        currentAmount: (map['currentAmount'] as int?) ?? 0,
        unit: map['unit'] as String?,
        startDate: DateTime.fromMillisecondsSinceEpoch(
            map['startDate'] as int? ?? map['creationDate'] as int? ?? 0),
        targetDate: map['targetDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['targetDate'] as int),
        isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
        completionDate: map['completionDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['completionDate'] as int),
        isArchived: (map['isArchived'] as int? ?? 0) == 1,
        sortOrder: (map['sortOrder'] as int?) ?? 0,
        creationDate: DateTime.fromMillisecondsSinceEpoch(
            map['creationDate'] as int? ?? 0),
      );
}
