import 'package:uuid/uuid.dart';

import 'item.dart';

class Task extends AppItem {
  final String title;
  final String? note;
  final bool isCompleted;
  final DateTime? dueDate;
  final int? doTime; // minutes since midnight (0–1439), null = no time set
  final String? listId;

  Task({
    String? id,
    DateTime? creationDate,
    String iconId = 'inbox',
    required this.title,
    this.note,
    this.isCompleted = false,
    this.dueDate,
    this.doTime,
    this.listId,
  }) : super(
          id: id ?? const Uuid().v4(),
          creationDate: creationDate ?? DateTime.now(),
          iconId: iconId,
        );

  Task copyWith({
    String? title,
    String? note,
    bool? isCompleted,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? doTime,
    bool clearDoTime = false,
    String? listId,
    bool clearListId = false,
  }) {
    return Task(
      id: id,
      creationDate: creationDate,
      iconId: iconId,
      title: title ?? this.title,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      doTime: clearDoTime ? null : (doTime ?? this.doTime),
      listId: clearListId ? null : (listId ?? this.listId),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'creationDate': creationDate.millisecondsSinceEpoch,
        'iconId': iconId,
        'title': title,
        'note': note,
        'isCompleted': isCompleted ? 1 : 0,
        'dueDate': dueDate?.millisecondsSinceEpoch,
        'doTime': doTime,
        'listId': listId,
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as String,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
        iconId: map['iconId'] as String,
        title: map['title'] as String,
        note: map['note'] as String?,
        isCompleted: (map['isCompleted'] as int) == 1,
        dueDate: map['dueDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
            : null,
        doTime: map['doTime'] as int?,
        listId: map['listId'] as String?,
      );
}
