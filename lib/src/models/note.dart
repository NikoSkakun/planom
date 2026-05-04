import 'package:uuid/uuid.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final String? folderId;
  final DateTime creationDate;
  final DateTime modifiedDate;
  final int sortOrder;

  Note({
    String? id,
    required this.title,
    required this.content,
    this.folderId,
    DateTime? creationDate,
    DateTime? modifiedDate,
    this.sortOrder = 0,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now(),
        modifiedDate = modifiedDate ?? DateTime.now();

  Note copyWith({
    String? title,
    String? content,
    String? folderId,
    bool clearFolderId = false,
    int? sortOrder,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        folderId: clearFolderId ? null : (folderId ?? this.folderId),
        creationDate: creationDate,
        modifiedDate: DateTime.now(),
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'folderId': folderId,
        'creationDate': creationDate.millisecondsSinceEpoch,
        'modifiedDate': modifiedDate.millisecondsSinceEpoch,
        'sortOrder': sortOrder,
      };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as String,
        title: map['title'] as String,
        content: map['content'] as String,
        folderId: map['folderId'] as String?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
        modifiedDate:
            DateTime.fromMillisecondsSinceEpoch(map['modifiedDate'] as int),
        sortOrder: map['sortOrder'] as int? ?? 0,
      );
}
