import 'package:uuid/uuid.dart';

/// A user-defined named group of tasks within an [AppList]. Sections give
/// users a way to subdivide a list (e.g. "Today", "Later") without creating
/// nested lists. Each list also has an implicit "Completed" section appended
/// at the bottom; that one is virtual — it has no row in `list_sections`.
class ListSection {
  final String id;
  final String listId;
  final String name;
  final int sortOrder;
  final bool isCollapsed;
  final DateTime creationDate;

  ListSection({
    String? id,
    required this.listId,
    required this.name,
    this.sortOrder = 0,
    this.isCollapsed = false,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  ListSection copyWith({
    String? name,
    int? sortOrder,
    bool? isCollapsed,
  }) =>
      ListSection(
        id: id,
        listId: listId,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        isCollapsed: isCollapsed ?? this.isCollapsed,
        creationDate: creationDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'listId': listId,
        'name': name,
        'sortOrder': sortOrder,
        'isCollapsed': isCollapsed ? 1 : 0,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory ListSection.fromMap(Map<String, dynamic> map) => ListSection(
        id: map['id'] as String,
        listId: map['listId'] as String,
        name: map['name'] as String,
        sortOrder: map['sortOrder'] as int? ?? 0,
        isCollapsed: (map['isCollapsed'] as int? ?? 0) == 1,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );
}
