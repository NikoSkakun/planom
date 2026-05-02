abstract class AppItem {
  final String id;
  final DateTime creationDate;
  final String iconId;

  const AppItem({
    required this.id,
    required this.creationDate,
    required this.iconId,
  });
}
