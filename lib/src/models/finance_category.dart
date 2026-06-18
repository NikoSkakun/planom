import 'package:uuid/uuid.dart';

/// A bucket transactions are filed under (Groceries, Salary, Rent …). Each
/// category is either an income or an expense category — never both — so the
/// transaction sheets can show the right list.
class FinanceCategory {
  final String id;
  final String name;

  /// 'income' | 'expense'.
  final String kind;

  /// SF-symbol key understood by [financeIconData].
  final String iconId;
  final int colorValue; // ARGB tint

  final int sortOrder;
  final DateTime creationDate;

  FinanceCategory({
    String? id,
    required this.name,
    required this.kind,
    this.iconId = 'tag',
    this.colorValue = 0xFF007AFF,
    this.sortOrder = 0,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  bool get isIncome => kind == 'income';
  bool get isExpense => kind == 'expense';

  FinanceCategory copyWith({
    String? name,
    String? kind,
    String? iconId,
    int? colorValue,
    int? sortOrder,
  }) =>
      FinanceCategory(
        id: id,
        creationDate: creationDate,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        iconId: iconId ?? this.iconId,
        colorValue: colorValue ?? this.colorValue,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'kind': kind,
        'iconId': iconId,
        'colorValue': colorValue,
        'sortOrder': sortOrder,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory FinanceCategory.fromMap(Map<String, dynamic> map) => FinanceCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        kind: (map['kind'] as String?) ?? 'expense',
        iconId: (map['iconId'] as String?) ?? 'tag',
        colorValue: (map['colorValue'] as int?) ?? 0xFF007AFF,
        sortOrder: (map['sortOrder'] as int?) ?? 0,
        creationDate: DateTime.fromMillisecondsSinceEpoch(
            map['creationDate'] as int? ?? 0),
      );
}
