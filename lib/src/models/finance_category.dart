import 'package:uuid/uuid.dart';

/// What a finance entry does to the ledger: money out, money in, or a move
/// between two of the user's own accounts.
///
/// Transfers are deliberately excluded from income / expense totals and from
/// budgets — moving your own money isn't spending it.
enum FinanceEntryType { expense, income, transfer }

String encodeFinanceEntryType(FinanceEntryType t) => t.name;

FinanceEntryType decodeFinanceEntryType(String? raw) {
  switch (raw) {
    case 'income':
      return FinanceEntryType.income;
    case 'transfer':
      return FinanceEntryType.transfer;
    default:
      return FinanceEntryType.expense;
  }
}

/// A spending / earning bucket a [FinanceTransaction] can be filed under
/// (Groceries, Rent, Salary …). Categories are per-space data, seeded with a
/// default set the first time the Finance tab is used in a space.
///
/// Only [FinanceEntryType.expense] and [FinanceEntryType.income] categories
/// exist — transfers are never categorised.
///
/// [iconId] is a key into `kFinanceCategoryIcons` (see
/// `lib/src/finance/finance_icons.dart`) — not the custom-photo icon storage
/// used by folders/lists/routines.
class FinanceCategory {
  FinanceCategory({
    String? id,
    required this.name,
    this.iconId = 'tag',
    required this.color,
    this.type = FinanceEntryType.expense,
    this.sortOrder = 0,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  final String id;
  final String name;
  final String iconId;

  /// ARGB colour used for the category dot / icon tint.
  final int color;
  final FinanceEntryType type;
  final int sortOrder;
  final DateTime creationDate;

  FinanceCategory copyWith({
    String? name,
    String? iconId,
    int? color,
    FinanceEntryType? type,
    int? sortOrder,
  }) =>
      FinanceCategory(
        id: id,
        name: name ?? this.name,
        iconId: iconId ?? this.iconId,
        color: color ?? this.color,
        type: type ?? this.type,
        sortOrder: sortOrder ?? this.sortOrder,
        creationDate: creationDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconId': iconId,
        'color': color,
        'type': encodeFinanceEntryType(type),
        'sortOrder': sortOrder,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory FinanceCategory.fromMap(Map<String, dynamic> map) => FinanceCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        iconId: map['iconId'] as String? ?? 'tag',
        color: map['color'] as int? ?? 0xFF8E8E93,
        type: decodeFinanceEntryType(map['type'] as String?),
        sortOrder: map['sortOrder'] as int? ?? 0,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );
}
