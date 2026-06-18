import 'package:uuid/uuid.dart';

/// A recurring spending limit. A budget caps spending for a single expense
/// [categoryId] (or all expenses when null) over a repeating [period], in
/// [currencyCode]. Progress is computed from the matching transactions in the
/// current period — nothing about progress is stored on the row.
class Budget {
  static const periodWeekly = 'weekly';
  static const periodMonthly = 'monthly';
  static const periodYearly = 'yearly';

  final String id;
  final String name;

  /// Expense category this budget limits, or null for an overall budget across
  /// every expense category.
  final String? categoryId;

  /// Limit in minor units (cents) of [currencyCode], per [period].
  final int amount;
  final String period; // weekly | monthly | yearly
  final String currencyCode;
  final int sortOrder;
  final DateTime creationDate;

  Budget({
    String? id,
    required this.name,
    this.categoryId,
    required this.amount,
    this.period = periodMonthly,
    this.currencyCode = 'USD',
    this.sortOrder = 0,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  Budget copyWith({
    String? name,
    String? categoryId,
    bool clearCategoryId = false,
    int? amount,
    String? period,
    String? currencyCode,
    int? sortOrder,
  }) =>
      Budget(
        id: id,
        creationDate: creationDate,
        name: name ?? this.name,
        categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
        amount: amount ?? this.amount,
        period: period ?? this.period,
        currencyCode: currencyCode ?? this.currencyCode,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'amount': amount,
        'period': period,
        'currencyCode': currencyCode,
        'sortOrder': sortOrder,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'] as String,
        name: map['name'] as String,
        categoryId: map['categoryId'] as String?,
        amount: (map['amount'] as int?) ?? 0,
        period: (map['period'] as String?) ?? periodMonthly,
        currencyCode: (map['currencyCode'] as String?) ?? 'USD',
        sortOrder: (map['sortOrder'] as int?) ?? 0,
        creationDate: DateTime.fromMillisecondsSinceEpoch(
            map['creationDate'] as int? ?? 0),
      );
}
