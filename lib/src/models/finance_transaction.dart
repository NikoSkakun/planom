import 'package:uuid/uuid.dart';

import 'finance_category.dart';

/// A single money movement: an expense, an income entry, or a transfer
/// between two of the user's own accounts.
///
/// [amount] is stored in **minor units** (cents) as a non-negative integer —
/// never a double, so sums stay exact. The direction of the movement lives in
/// [type], not in the sign of the amount. The amount is denominated in the
/// currency of [accountId]'s account (or the space's default currency when no
/// account is set).
class FinanceTransaction {
  FinanceTransaction({
    String? id,
    required this.title,
    required this.amount,
    this.type = FinanceEntryType.expense,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    this.toAmount,
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
  /// Always null for transfers.
  final String? categoryId;

  /// Account the money left (expense / transfer) or landed in (income).
  /// null = no account assigned; such entries are counted in the space's
  /// default currency.
  final String? accountId;

  /// Transfers only: the account the money lands in.
  final String? toAccountId;

  /// Transfers only: the amount credited to [toAccountId], in that account's
  /// currency. null means "same as [amount]" — the usual same-currency case.
  /// Cross-currency transfers carry both legs explicitly because the app
  /// never applies an exchange rate of its own.
  final int? toAmount;

  /// Day the money moved, normalized to midnight.
  final DateTime date;
  final String? note;
  final DateTime creationDate;

  /// Signed amount in minor units: negative for expenses, positive for income,
  /// zero for transfers (they move money without changing the total).
  int get signedAmount => switch (type) {
        FinanceEntryType.income => amount,
        FinanceEntryType.expense => -amount,
        FinanceEntryType.transfer => 0,
      };

  /// Amount credited to [toAccountId] for a transfer (defaults to [amount]).
  int get creditedAmount => toAmount ?? amount;

  bool get isTransfer => type == FinanceEntryType.transfer;

  FinanceTransaction copyWith({
    String? title,
    int? amount,
    FinanceEntryType? type,
    String? categoryId,
    bool clearCategoryId = false,
    String? accountId,
    bool clearAccountId = false,
    String? toAccountId,
    bool clearToAccountId = false,
    int? toAmount,
    bool clearToAmount = false,
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
        accountId: clearAccountId ? null : (accountId ?? this.accountId),
        toAccountId:
            clearToAccountId ? null : (toAccountId ?? this.toAccountId),
        toAmount: clearToAmount ? null : (toAmount ?? this.toAmount),
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
        'accountId': accountId,
        'toAccountId': toAccountId,
        'toAmount': toAmount,
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
        accountId: map['accountId'] as String?,
        toAccountId: map['toAccountId'] as String?,
        toAmount: map['toAmount'] as int?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        note: map['note'] as String?,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );
}
