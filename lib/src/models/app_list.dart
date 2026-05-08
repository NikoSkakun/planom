import 'package:uuid/uuid.dart';

class AppList {
  final String id;
  final String name;
  final String? folderId;
  final DateTime creationDate;
  final int sortOrder;
  final int? color; // ARGB; null = no color
  final String? iconId; // null=default asset; SF-symbol key or absolute file path

  AppList({
    String? id,
    required this.name,
    this.folderId,
    DateTime? creationDate,
    this.sortOrder = 0,
    this.color,
    this.iconId,
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
  }) =>
      AppList(
        id: id,
        name: name ?? this.name,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        creationDate: creationDate,
        sortOrder: sortOrder ?? this.sortOrder,
        color: clearColor ? null : (color ?? this.color),
        iconId: clearIconId ? null : (iconId ?? this.iconId),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'folderId': folderId,
        'creationDate': creationDate.millisecondsSinceEpoch,
        'sortOrder': sortOrder,
        'color': color,
        'iconId': iconId,
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
      );
}
