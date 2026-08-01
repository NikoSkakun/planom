import 'package:uuid/uuid.dart';

import 'finance_category.dart';

/// A single money movement: an expense or an income entry.
///
/// [amount] is stored in **minor units** (cents) as a non-negative integer —
/// never a double, so sums stay exact. The direction of the movement lives in
/// [type], not in the sign of the amount.
class FinanceTransaction {
  FinanceTransaction({
    String? id,
    required this.title,
    required this.amount,
    this.type = FinanceEntryType.expense,
    this.categoryId,
    required this.date,
    this.note,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  final String id;
  final String title;

  /// Minor units (cents). Always >= 0 — see [type] for the direction.
  final int amount;
  final FinanceEntryType type;

  /// Category this entry is filed under, or null for "Uncategorized".
  final String? categoryId;

  /// Day the money moved, normalized to midnight.
  final DateTime date;
  final String? note;
  final DateTime creationDate;

  /// Signed amount in minor units: negative for expenses, positive for income.
  /// Handy for running balances.
  int get signedAmount => type == FinanceEntryType.income ? amount : -amount;

  FinanceTransaction copyWith({
    String? title,
    int? amount,
    FinanceEntryType? type,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? date,
    String? note,
    bool clearNote = false,
  }) =>
      FinanceTransaction(
        id: id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
        date: date ?? this.date,
        note: clearNote ? null : (note ?? this.note),
        creationDate: creationDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': encodeFinanceEntryType(type),
        'categoryId': categoryId,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) =>
      FinanceTransaction(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: map['amount'] as int? ?? 0,
        type: decodeFinanceEntryType(map['type'] as String?),
        categoryId: map['categoryId'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        note: map['note'] as String?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );
}
