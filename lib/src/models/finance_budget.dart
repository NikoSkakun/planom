import 'package:uuid/uuid.dart';

/// How often a [FinanceBudget]'s allowance resets.
enum BudgetPeriod { monthly, weekly }

String encodeBudgetPeriod(BudgetPeriod p) =>
    p == BudgetPeriod.weekly ? 'weekly' : 'monthly';

BudgetPeriod decodeBudgetPeriod(String? raw) =>
    raw == 'weekly' ? BudgetPeriod.weekly : BudgetPeriod.monthly;

/// A spending allowance, either for one category or — when [categoryId] is
/// null — for total spending in the period ("overall budget").
///
/// [amount] is in minor units (cents), matching [FinanceTransaction.amount].
/// At most one budget exists per category (and one overall); the controller
/// enforces that by replacing an existing row instead of adding a second.
class FinanceBudget {
  FinanceBudget({
    String? id,
    this.categoryId,
    required this.amount,
    this.period = BudgetPeriod.monthly,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  final String id;

  /// Category the allowance applies to; null = overall spending budget.
  final String? categoryId;

  /// Allowance in minor units (cents).
  final int amount;
  final BudgetPeriod period;
  final DateTime creationDate;

  bool get isOverall => categoryId == null;

  FinanceBudget copyWith({int? amount, BudgetPeriod? period}) => FinanceBudget(
        id: id,
        categoryId: categoryId,
        amount: amount ?? this.amount,
        period: period ?? this.period,
        creationDate: creationDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'categoryId': categoryId,
        'amount': amount,
        'period': encodeBudgetPeriod(period),
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory FinanceBudget.fromMap(Map<String, dynamic> map) => FinanceBudget(
        id: map['id'] as String,
        categoryId: map['categoryId'] as String?,
        amount: map['amount'] as int? ?? 0,
        period: decodeBudgetPeriod(map['period'] as String?),
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );
}
