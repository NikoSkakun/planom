import 'package:uuid/uuid.dart';

/// A flat label that can be attached to any task. Names are unique
/// case-insensitively; uniqueness is enforced in [TaskController.addTag].
class Tag {
  Tag({
    String? id,
    DateTime? creationDate,
    required this.name,
    this.color,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  final String id;
  final String name;
  final int? color; // ARGB; null = no accent (chip uses neutral grey)
  final DateTime creationDate;

  Tag copyWith({String? name, int? color, bool clearColor = false}) => Tag(
        id: id,
        creationDate: creationDate,
        name: name ?? this.name,
        color: clearColor ? null : (color ?? this.color),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory Tag.fromMap(Map<String, dynamic> map) => Tag(
        id: map['id'] as String,
        name: map['name'] as String,
        color: map['color'] as int?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );
}
