import 'package:uuid/uuid.dart';

/// What kind of place the money sits in. Purely presentational (icon +
/// grouping); balances are computed the same way for every type.
enum FinanceAccountType { cash, card, bank, savings, other }

String encodeAccountType(FinanceAccountType t) => t.name;

FinanceAccountType decodeAccountType(String? raw) =>
    FinanceAccountType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => FinanceAccountType.cash,
    );

/// A wallet, card or bank account money moves through.
///
/// Each account carries its **own currency** — amounts are never converted
/// between currencies (no exchange rates anywhere in the app); totals across
/// accounts are grouped per currency instead.
class FinanceAccount {
  FinanceAccount({
    String? id,
    required this.name,
    this.type = FinanceAccountType.cash,
    required this.currencyCode,
    this.initialBalance = 0,
    this.color = 0xFF007AFF,
    this.iconId = 'creditcard',
    this.sortOrder = 0,
    this.isArchived = false,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  final String id;
  final String name;
  final FinanceAccountType type;

  /// ISO-4217-style code (`USD`, `EUR`, `UAH`, …). Resolved to a symbol
  /// through `kCurrencies` — an unknown code renders as the code itself.
  final String currencyCode;

  /// Opening balance in minor units; may be negative (e.g. a card in debt).
  final int initialBalance;
  final int color;
  final String iconId;
  final int sortOrder;

  /// Archived accounts stay for history but are hidden from pickers and the
  /// account strip.
  final bool isArchived;
  final DateTime creationDate;

  FinanceAccount copyWith({
    String? name,
    FinanceAccountType? type,
    String? currencyCode,
    int? initialBalance,
    int? color,
    String? iconId,
    int? sortOrder,
    bool? isArchived,
  }) =>
      FinanceAccount(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        currencyCode: currencyCode ?? this.currencyCode,
        initialBalance: initialBalance ?? this.initialBalance,
        color: color ?? this.color,
        iconId: iconId ?? this.iconId,
        sortOrder: sortOrder ?? this.sortOrder,
        isArchived: isArchived ?? this.isArchived,
        creationDate: creationDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': encodeAccountType(type),
        'currencyCode': currencyCode,
        'initialBalance': initialBalance,
        'color': color,
        'iconId': iconId,
        'sortOrder': sortOrder,
        'isArchived': isArchived ? 1 : 0,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  // Reads defensively for the same reason as [Goal.fromMap]: a row from the
  // reverted Finance build stores `colorValue` / `openingBalance`, and this
  // runs while the space is loading, where a throw costs the whole launch.
  factory FinanceAccount.fromMap(Map<String, dynamic> map) => FinanceAccount(
        id: map['id'] as String? ?? const Uuid().v4(),
        name: map['name'] as String? ?? '',
        type: decodeAccountType(map['type'] as String?),
        currencyCode: map['currencyCode'] as String? ?? 'USD',
        initialBalance:
            map['initialBalance'] as int? ?? map['openingBalance'] as int? ?? 0,
        color: map['color'] as int? ?? map['colorValue'] as int? ?? 0xFF007AFF,
        iconId: map['iconId'] as String? ?? 'creditcard',
        sortOrder: map['sortOrder'] as int? ?? 0,
        isArchived: (map['isArchived'] as int? ?? 0) == 1,
        creationDate: DateTime.fromMillisecondsSinceEpoch(
            map['creationDate'] as int? ?? 0),
      );
}
