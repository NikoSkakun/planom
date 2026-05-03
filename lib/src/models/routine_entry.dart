import 'package:uuid/uuid.dart';

class RoutineEntry {
  final String id;
  final String routineId;
  final DateTime date; // normalized to midnight
  final int amount;

  RoutineEntry({
    String? id,
    required this.routineId,
    required this.date,
    this.amount = 0,
  }) : id = id ?? const Uuid().v4();

  RoutineEntry copyWith({int? amount}) => RoutineEntry(
        id: id,
        routineId: routineId,
        date: date,
        amount: amount ?? this.amount,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'routineId': routineId,
        'date': date.millisecondsSinceEpoch,
        'amount': amount,
      };

  factory RoutineEntry.fromMap(Map<String, dynamic> map) => RoutineEntry(
        id: map['id'] as String,
        routineId: map['routineId'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        amount: map['amount'] as int,
      );
}
