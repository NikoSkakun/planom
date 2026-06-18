import 'package:uuid/uuid.dart';

/// One step toward a milestone-type [Goal]. Ordered within its goal by
/// [sortOrder].
class GoalMilestone {
  final String id;
  final String goalId;
  final String title;
  final bool isCompleted;
  final DateTime? completionDate;
  final int sortOrder;
  final DateTime creationDate;

  GoalMilestone({
    String? id,
    required this.goalId,
    required this.title,
    this.isCompleted = false,
    this.completionDate,
    this.sortOrder = 0,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  GoalMilestone copyWith({
    String? title,
    bool? isCompleted,
    DateTime? completionDate,
    bool clearCompletionDate = false,
    int? sortOrder,
  }) =>
      GoalMilestone(
        id: id,
        goalId: goalId,
        creationDate: creationDate,
        title: title ?? this.title,
        isCompleted: isCompleted ?? this.isCompleted,
        completionDate: clearCompletionDate
            ? null
            : (completionDate ?? this.completionDate),
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'goalId': goalId,
        'title': title,
        'isCompleted': isCompleted ? 1 : 0,
        'completionDate': completionDate?.millisecondsSinceEpoch,
        'sortOrder': sortOrder,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory GoalMilestone.fromMap(Map<String, dynamic> map) => GoalMilestone(
        id: map['id'] as String,
        goalId: map['goalId'] as String,
        title: map['title'] as String,
        isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
        completionDate: map['completionDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['completionDate'] as int),
        sortOrder: (map['sortOrder'] as int?) ?? 0,
        creationDate: DateTime.fromMillisecondsSinceEpoch(
            map['creationDate'] as int? ?? 0),
      );
}
