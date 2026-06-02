import 'package:uuid/uuid.dart';

import 'list_type.dart';

class AppList {
  final String id;
  final String name;
  final String? folderId;
  final DateTime creationDate;
  final int sortOrder;
  final int? color; // ARGB; null = no color
  final String? iconId; // null=default asset; SF-symbol key or absolute file path
  final int? iconColor; // ARGB override for SF-symbol icon; null=use accent
  final String? description; // optional free-text shown atop the list view
  final bool isDeleted;
  final DateTime? deletedDate;
  final ListType listType;

  AppList({
    String? id,
    required this.name,
    this.folderId,
    DateTime? creationDate,
    this.sortOrder = 0,
    this.color,
    this.iconId,
    this.iconColor,
    this.description,
    this.isDeleted = false,
    this.deletedDate,
    this.listType = ListType.tasks,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  AppList copyWith({
    String? name,
    String? folderId,
    bool clearFolder = false,
    int? sortOrder,
    int? color,
    bool clearColor = false,
    String? iconId,
    bool clearIconId = false,
    int? iconColor,
    bool clearIconColor = false,
    String? description,
    bool clearDescription = false,
    bool? isDeleted,
    DateTime? deletedDate,
    bool clearDeletedDate = false,
    ListType? listType,
  }) =>
      AppList(
        id: id,
        name: name ?? this.name,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        creationDate: creationDate,
        sortOrder: sortOrder ?? this.sortOrder,
        color: clearColor ? null : (color ?? this.color),
        iconId: clearIconId ? null : (iconId ?? this.iconId),
        iconColor: clearIconColor ? null : (iconColor ?? this.iconColor),
        description:
            clearDescription ? null : (description ?? this.description),
        isDeleted: isDeleted ?? this.isDeleted,
        deletedDate: clearDeletedDate ? null : (deletedDate ?? this.deletedDate),
        listType: listType ?? this.listType,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'folderId': folderId,
        'creationDate': creationDate.millisecondsSinceEpoch,
        'sortOrder': sortOrder,
        'color': color,
        'iconId': iconId,
        'iconColor': iconColor,
        'description': description,
        'isDeleted': isDeleted ? 1 : 0,
        'deletedDate': deletedDate?.millisecondsSinceEpoch,
        'listType': listType.value,
      };

  factory AppList.fromMap(Map<String, dynamic> map) => AppList(
        id: map['id'] as String,
        name: map['name'] as String,
        folderId: map['folderId'] as String?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
        sortOrder: map['sortOrder'] as int? ?? 0,
        color: map['color'] as int?,
        iconId: map['iconId'] as String?,
        iconColor: map['iconColor'] as int?,
        description: map['description'] as String?,
        isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
        deletedDate: map['deletedDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['deletedDate'] as int)
            : null,
        listType: ListType.fromString(map['listType'] as String?),
      );
}
