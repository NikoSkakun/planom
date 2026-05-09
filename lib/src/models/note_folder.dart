import 'package:uuid/uuid.dart';

class NoteFolder {
  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime creationDate;
  final int sortOrder;
  final String? iconId; // null=default asset; SF-symbol key or absolute file path

  NoteFolder({
    String? id,
    required this.name,
    this.parentFolderId,
    DateTime? creationDate,
    this.sortOrder = 0,
    this.iconId,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  NoteFolder copyWith({
    String? name,
    String? parentFolderId,
    bool clearParent = false,
    int? sortOrder,
    String? iconId,
    bool clearIconId = false,
  }) =>
      NoteFolder(
        id: id,
        name: name ?? this.name,
        parentFolderId:
            clearParent ? null : (parentFolderId ?? this.parentFolderId),
        creationDate: creationDate,
        sortOrder: sortOrder ?? this.sortOrder,
        iconId: clearIconId ? null : (iconId ?? this.iconId),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parentFolderId': parentFolderId,
        'creationDate': creationDate.millisecondsSinceEpoch,
        'sortOrder': sortOrder,
        'iconId': iconId,
      };

  factory NoteFolder.fromMap(Map<String, dynamic> map) => NoteFolder(
        id: map['id'] as String,
        name: map['name'] as String,
        parentFolderId: map['parentFolderId'] as String?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
        sortOrder: map['sortOrder'] as int? ?? 0,
        iconId: map['iconId'] as String?,
      );
}
