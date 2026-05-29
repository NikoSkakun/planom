class Space {
  const Space({
    required this.id,
    required this.name,
    required this.creationDate,
  });

  final String id;
  final String name;
  final DateTime creationDate;

  Space copyWith({String? name}) => Space(
        id: id,
        name: name ?? this.name,
        creationDate: creationDate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory Space.fromJson(Map<String, dynamic> j) => Space(
        id: j['id'] as String,
        name: j['name'] as String,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(j['creationDate'] as int),
      );
}
