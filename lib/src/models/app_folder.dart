import 'package:uuid/uuid.dart';

class AppFolder {
  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime creationDate;
  final int sortOrder;
  final String? iconId; // null=default asset; SF-symbol key or absolute file path
  final int? iconColor; // ARGB override for SF-symbol icon; null=use accent
  final bool isDeleted;
  final DateTime? deletedDate;

  AppFolder({
    String? id,
    required this.name,
    this.parentFolderId,
    DateTime? creationDate,
    this.sortOrder = 0,
    this.iconId,
    this.iconColor,
    this.isDeleted = false,
    this.deletedDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  AppFolder copyWith({
    String? name,
    String? parentFolderId,
    bool clearParent = false,
    int? sortOrder,
    String? iconId,
    bool clearIconId = false,
    int? iconColor,
    bool clearIconColor = false,
    bool? isDeleted,
    DateTime? deletedDate,
    bool clearDeletedDate = false,
  }) =>
      AppFolder(
        id: id,
        name: name ?? this.name,
        parentFolderId:
            clearParent ? null : (parentFolderId ?? this.parentFolderId),
        creationDate: creationDate,
        sortOrder: sortOrder ?? this.sortOrder,
        iconId: clearIconId ? null : (iconId ?? this.iconId),
        iconColor: clearIconColor ? null : (iconColor ?? this.iconColor),
        isDeleted: isDeleted ?? this.isDeleted,
        deletedDate: clearDeletedDate ? null : (deletedDate ?? this.deletedDate),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parentFolderId': parentFolderId,
        'creationDate': creationDate.millisecondsSinceEpoch,
        'sortOrder': sortOrder,
        'iconId': iconId,
        'iconColor': iconColor,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedDate': deletedDate?.millisecondsSinceEpoch,
      };

  factory AppFolder.fromMap(Map<String, dynamic> map) => AppFolder(
        id: map['id'] as String,
        name: map['name'] as String,
        parentFolderId: map['parentFolderId'] as String?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
        sortOrder: map['sortOrder'] as int? ?? 0,
        iconId: map['iconId'] as String?,
        iconColor: map['iconColor'] as int?,
        isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
        deletedDate: map['deletedDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['deletedDate'] as int)
            : null,
      );
}
