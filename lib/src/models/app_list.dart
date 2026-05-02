import 'package:uuid/uuid.dart';

class AppList {
  final String id;
  final String name;
  final String? folderId;
  final DateTime creationDate;

  AppList({
    String? id,
    required this.name,
    this.folderId,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  AppList copyWith({String? name, String? folderId, bool clearFolder = false}) =>
      AppList(
        id: id,
        name: name ?? this.name,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        creationDate: creationDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'folderId': folderId,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory AppList.fromMap(Map<String, dynamic> map) => AppList(
        id: map['id'] as String,
        name: map['name'] as String,
        folderId: map['folderId'] as String?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );
}
