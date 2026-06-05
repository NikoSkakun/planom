import 'package:uuid/uuid.dart';

import 'item.dart';

/// Calendar-only entity: has a date, optional time, optional duration.
/// Unlike Task it cannot be "completed" — it just exists on the timeline.
class Event extends AppItem {
  final String title;
  final String? note;
  final DateTime date; // required, normalized to midnight
  final int? doTime;   // minutes since midnight; null = all-day / untimed
  final int? duration; // minutes; null = no defined duration
  final bool isDeleted;
  final DateTime? deletedDate;
  final List<int> reminderOffsets;

  /// JSON-encoded [Recurrence] rule, or null for a one-off event. A recurring
  /// event is stored once (anchored at [date]) and expanded onto each repeat
  /// day in the view layer.
  final String? recurrence;

  Event({
    String? id,
    DateTime? creationDate,
    String iconId = 'event',
    required this.title,
    this.note,
    required this.date,
    this.doTime,
    this.duration,
    this.isDeleted = false,
    this.deletedDate,
    this.reminderOffsets = const [],
    this.recurrence,
  }) : super(
          id: id ?? const Uuid().v4(),
          creationDate: creationDate ?? DateTime.now(),
          iconId: iconId,
        );

  Event copyWith({
    String? title,
    String? note,
    bool clearNote = false,
    DateTime? date,
    int? doTime,
    bool clearDoTime = false,
    int? duration,
    bool clearDuration = false,
    bool? isDeleted,
    DateTime? deletedDate,
    bool clearDeletedDate = false,
    List<int>? reminderOffsets,
    String? recurrence,
    bool clearRecurrence = false,
  }) {
    return Event(
      id: id,
      creationDate: creationDate,
      iconId: iconId,
      title: title ?? this.title,
      note: clearNote ? null : (note ?? this.note),
      date: date ?? this.date,
      doTime: clearDoTime ? null : (doTime ?? this.doTime),
      duration: clearDuration ? null : (duration ?? this.duration),
      isDeleted: isDeleted ?? this.isDeleted,
      deletedDate:
          clearDeletedDate ? null : (deletedDate ?? this.deletedDate),
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'creationDate': creationDate.millisecondsSinceEpoch,
        'iconId': iconId,
        'title': title,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'doTime': doTime,
        'duration': duration,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedDate': deletedDate?.millisecondsSinceEpoch,
        'reminderOffsets': reminderOffsets.join(','),
        'recurrence': recurrence,
      };

  factory Event.fromMap(Map<String, dynamic> map) => Event(
        id: map['id'] as String,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
        iconId: map['iconId'] as String,
        title: map['title'] as String,
        note: map['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        doTime: map['doTime'] as int?,
        duration: map['duration'] as int?,
        isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
        deletedDate: map['deletedDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['deletedDate'] as int)
            : null,
        reminderOffsets: _parseOffsets(map['reminderOffsets'] as String?),
        recurrence: map['recurrence'] as String?,
      );

  static List<int> _parseOffsets(String? s) {
    if (s == null || s.isEmpty) return const [];
    return s.split(',').map((e) => int.tryParse(e)).whereType<int>().toList();
  }
}
