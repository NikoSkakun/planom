import 'package:uuid/uuid.dart';

class AppFolder {
  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime creationDate;

  AppFolder({
    String? id,
    required this.name,
    this.parentFolderId,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  AppFolder copyWith({String? name, String? parentFolderId, bool clearParent = false}) =>
      AppFolder(
        id: id,
        name: name ?? this.name,
        parentFolderId: clearParent ? null : (parentFolderId ?? this.parentFolderId),
        creationDate: creationDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parentFolderId': parentFolderId,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory AppFolder.fromMap(Map<String, dynamic> map) => AppFolder(
        id: map['id'] as String,
        name: map['name'] as String,
        parentFolderId: map['parentFolderId'] as String?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );
}
