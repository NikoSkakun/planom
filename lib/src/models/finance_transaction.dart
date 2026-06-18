import 'package:uuid/uuid.dart';

/// A single ledger entry.
///
/// - `income`   — money into [accountId], filed under [categoryId].
/// - `expense`  — money out of [accountId], filed under [categoryId].
/// - `transfer` — money out of [accountId] and into [toAccountId];
///                [categoryId] is null. Both accounts share the same [amount]
///                (cross-currency transfers are recorded at face value).
///
/// [amount] is always a positive integer in minor units (cents) of the
/// account's currency. The sign is implied by [type].
class FinanceTransaction {
  static const typeIncome = 'income';
  static const typeExpense = 'expense';
  static const typeTransfer = 'transfer';

  final String id;
  final String type;
  final int amount; // minor units, > 0
  final String accountId;
  final String? toAccountId; // transfers only
  final String? categoryId; // null for transfers
  final String title; // payee / description
  final String? note;
  final DateTime date;
  final DateTime creationDate;

  FinanceTransaction({
    String? id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.title = '',
    this.note,
    required this.date,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  bool get isIncome => type == typeIncome;
  bool get isExpense => type == typeExpense;
  bool get isTransfer => type == typeTransfer;

  /// Signed effect of this transaction on [accountId]'s balance.
  int signedFor(String account) {
    if (type == typeIncome && accountId == account) return amount;
    if (type == typeExpense && accountId == account) return -amount;
    if (type == typeTransfer) {
      if (accountId == account) return -amount;
      if (toAccountId == account) return amount;
    }
    return 0;
  }

  FinanceTransaction copyWith({
    String? type,
    int? amount,
    String? accountId,
    String? toAccountId,
    bool clearToAccountId = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? title,
    String? note,
    bool clearNote = false,
    DateTime? date,
  }) =>
      FinanceTransaction(
        id: id,
        creationDate: creationDate,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        accountId: accountId ?? this.accountId,
        toAccountId: clearToAccountId ? null : (toAccountId ?? this.toAccountId),
        categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
        title: title ?? this.title,
        note: clearNote ? null : (note ?? this.note),
        date: date ?? this.date,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'categoryId': categoryId,
        'title': title,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) =>
      FinanceTransaction(
        id: map['id'] as String,
        type: (map['type'] as String?) ?? typeExpense,
        amount: (map['amount'] as int?) ?? 0,
        accountId: map['accountId'] as String,
        toAccountId: map['toAccountId'] as String?,
        categoryId: map['categoryId'] as String?,
        title: (map['title'] as String?) ?? '',
        note: map['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int? ?? 0),
        creationDate: DateTime.fromMillisecondsSinceEpoch(
            map['creationDate'] as int? ?? 0),
      );
}
