/// Id of the space that ships with the app. It is special in two ways: its
/// data lives in the shared `planom.db` rather than a file of its own, and it
/// cannot be deleted — so several subsystems key their "fall back to this one"
/// behaviour on it.
const String kDefaultSpaceId = 'default';

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
