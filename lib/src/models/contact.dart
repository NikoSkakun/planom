import 'package:uuid/uuid.dart';

/// A person stored inside a Birthdays-type list. Distinct from `Task` so we
/// don't pollute the tasks table with contact-specific fields. Lives in the
/// `contacts` table; the `listId` ties it to the AppList that owns it.
class Contact {
  final String id;
  final String name;
  final String? note;
  final String listId;
  final int birthMonth; // 1–12
  final int birthDay; // 1–31
  final int? birthYear; // optional; null = year unknown
  final bool isCompletable; // whether the row shows a checkbox
  final bool isCompleted;
  final DateTime? completionDate;
  final List<int> reminderOffsets;
  final DateTime creationDate;
  final int sortOrder;
  final bool isDeleted;
  final DateTime? deletedDate;

  Contact({
    String? id,
    required this.name,
    this.note,
    required this.listId,
    required this.birthMonth,
    required this.birthDay,
    this.birthYear,
    this.isCompletable = false,
    this.isCompleted = false,
    this.completionDate,
    this.reminderOffsets = const [],
    DateTime? creationDate,
    this.sortOrder = 0,
    this.isDeleted = false,
    this.deletedDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  Contact copyWith({
    String? name,
    String? note,
    bool clearNote = false,
    String? listId,
    int? birthMonth,
    int? birthDay,
    int? birthYear,
    bool clearBirthYear = false,
    bool? isCompletable,
    bool? isCompleted,
    DateTime? completionDate,
    bool clearCompletionDate = false,
    List<int>? reminderOffsets,
    int? sortOrder,
    bool? isDeleted,
    DateTime? deletedDate,
    bool clearDeletedDate = false,
  }) =>
      Contact(
        id: id,
        name: name ?? this.name,
        note: clearNote ? null : (note ?? this.note),
        listId: listId ?? this.listId,
        birthMonth: birthMonth ?? this.birthMonth,
        birthDay: birthDay ?? this.birthDay,
        birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
        isCompletable: isCompletable ?? this.isCompletable,
        isCompleted: isCompleted ?? this.isCompleted,
        completionDate: clearCompletionDate
            ? null
            : (completionDate ?? this.completionDate),
        reminderOffsets: reminderOffsets ?? this.reminderOffsets,
        creationDate: creationDate,
        sortOrder: sortOrder ?? this.sortOrder,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedDate:
            clearDeletedDate ? null : (deletedDate ?? this.deletedDate),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'note': note,
        'listId': listId,
        'birthMonth': birthMonth,
        'birthDay': birthDay,
        'birthYear': birthYear,
        'isCompletable': isCompletable ? 1 : 0,
        'isCompleted': isCompleted ? 1 : 0,
        'completionDate': completionDate?.millisecondsSinceEpoch,
        'reminderOffsets': reminderOffsets.join(','),
        'creationDate': creationDate.millisecondsSinceEpoch,
        'sortOrder': sortOrder,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedDate': deletedDate?.millisecondsSinceEpoch,
      };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
        id: map['id'] as String,
        name: map['name'] as String,
        note: map['note'] as String?,
        listId: map['listId'] as String,
        birthMonth: map['birthMonth'] as int,
        birthDay: map['birthDay'] as int,
        birthYear: map['birthYear'] as int?,
        isCompletable: (map['isCompletable'] as int? ?? 0) == 1,
        isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
        completionDate: map['completionDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completionDate'] as int)
            : null,
        reminderOffsets: _parseOffsets(map['reminderOffsets'] as String?),
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
        sortOrder: map['sortOrder'] as int? ?? 0,
        isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
        deletedDate: map['deletedDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['deletedDate'] as int)
            : null,
      );

  static List<int> _parseOffsets(String? s) {
    if (s == null || s.isEmpty) return const [];
    return s
        .split(',')
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toList();
  }
}
