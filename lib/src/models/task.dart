import 'package:uuid/uuid.dart';

import 'item.dart';

// 0=none 1=low 2=medium 3=high
enum TaskPriority { none, low, medium, high }

class Task extends AppItem {
  final String title;
  final String? note;
  final bool isCompleted;
  final DateTime? dueDate;
  final int? doTime; // minutes since midnight (0–1439), null = no time set
  final int? duration; // minutes; null = no defined duration
  final String? listId;
  final int priority; // TaskPriority.index
  final int sortOrder; // 0 = not yet manually sorted; >0 = user-defined position
  final bool isDeleted;
  final DateTime? deletedDate;
  final DateTime? completionDate;
  final List<int> reminderOffsets;
  final String? parentTaskId;
  final List<String> tagIds;
  final String? recurrence;
  // ID of the section inside the list this task belongs to (introduced for
  // user-defined sections). null = the default top section.
  final String? sectionId;

  Task({
    String? id,
    DateTime? creationDate,
    String iconId = 'inbox',
    required this.title,
    this.note,
    this.isCompleted = false,
    this.dueDate,
    this.doTime,
    this.duration,
    this.listId,
    this.priority = 0,
    this.sortOrder = 0,
    this.isDeleted = false,
    this.deletedDate,
    this.completionDate,
    this.reminderOffsets = const [],
    this.parentTaskId,
    this.tagIds = const [],
    this.recurrence,
    this.sectionId,
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
    int? duration,
    bool clearDuration = false,
    String? listId,
    bool clearListId = false,
    int? priority,
    int? sortOrder,
    bool? isDeleted,
    DateTime? deletedDate,
    bool clearDeletedDate = false,
    DateTime? completionDate,
    bool clearCompletionDate = false,
    List<int>? reminderOffsets,
    String? parentTaskId,
    bool clearParentTaskId = false,
    List<String>? tagIds,
    String? recurrence,
    bool clearRecurrence = false,
    String? sectionId,
    bool clearSectionId = false,
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
      duration: clearDuration ? null : (duration ?? this.duration),
      listId: clearListId ? null : (listId ?? this.listId),
      priority: priority ?? this.priority,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedDate: clearDeletedDate ? null : (deletedDate ?? this.deletedDate),
      completionDate: clearCompletionDate ? null : (completionDate ?? this.completionDate),
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      parentTaskId:
          clearParentTaskId ? null : (parentTaskId ?? this.parentTaskId),
      tagIds: tagIds ?? this.tagIds,
      recurrence:
          clearRecurrence ? null : (recurrence ?? this.recurrence),
      sectionId: clearSectionId ? null : (sectionId ?? this.sectionId),
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
        'duration': duration,
        'listId': listId,
        'priority': priority,
        'sortOrder': sortOrder,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedDate': deletedDate?.millisecondsSinceEpoch,
        'completionDate': completionDate?.millisecondsSinceEpoch,
        'reminderOffsets': reminderOffsets.join(','),
        'parentTaskId': parentTaskId,
        'tagIds': tagIds.join(','),
        'recurrence': recurrence,
        'sectionId': sectionId,
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
        duration: map['duration'] as int?,
        listId: map['listId'] as String?,
        priority: map['priority'] as int? ?? 0,
        sortOrder: map['sortOrder'] as int? ?? 0,
        isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
        deletedDate: map['deletedDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['deletedDate'] as int)
            : null,
        completionDate: map['completionDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completionDate'] as int)
            : null,
        reminderOffsets: _parseOffsets(map['reminderOffsets'] as String?),
        parentTaskId: map['parentTaskId'] as String?,
        tagIds: _parseIds(map['tagIds'] as String?),
        recurrence: map['recurrence'] as String?,
        sectionId: map['sectionId'] as String?,
      );

  static List<int> _parseOffsets(String? s) {
    if (s == null || s.isEmpty) return const [];
    return s.split(',').map((e) => int.tryParse(e)).whereType<int>().toList();
  }

  static List<String> _parseIds(String? s) {
    if (s == null || s.isEmpty) return const [];
    return s.split(',').where((e) => e.isNotEmpty).toList();
  }
}
