import 'package:uuid/uuid.dart';

class NoteFolder {
  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime creationDate;

  NoteFolder({
    String? id,
    required this.name,
    this.parentFolderId,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parentFolderId': parentFolderId,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory NoteFolder.fromMap(Map<String, dynamic> map) => NoteFolder(
        id: map['id'] as String,
        name: map['name'] as String,
        parentFolderId: map['parentFolderId'] as String?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );
}
