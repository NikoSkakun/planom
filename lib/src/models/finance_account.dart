import 'package:uuid/uuid.dart';

/// A place money lives: a wallet, bank account, card, savings pot, etc. The
/// running balance is derived (opening balance + the account's transactions),
/// never stored directly, so it can never drift out of sync with the ledger.
class FinanceAccount {
  final String id;
  final String name;

  /// SF-symbol key understood by [financeIconData] (Finance icons), or a custom
  /// `icons/…` photo path.
  final String iconId;
  final int colorValue; // ARGB tint

  /// One of: cash | bank | card | savings | investment | other.
  final String type;

  /// Opening balance in minor units (cents) of [currencyCode].
  final int openingBalance;

  final String currencyCode; // ISO-4217, e.g. 'USD'

  /// Archived accounts are hidden from the main lists but keep their history.
  final bool isArchived;

  final int sortOrder;
  final DateTime creationDate;

  FinanceAccount({
    String? id,
    required this.name,
    this.iconId = 'wallet',
    this.colorValue = 0xFF34C759,
    this.type = 'cash',
    this.openingBalance = 0,
    this.currencyCode = 'USD',
    this.isArchived = false,
    this.sortOrder = 0,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        creationDate = creationDate ?? DateTime.now();

  FinanceAccount copyWith({
    String? name,
    String? iconId,
    int? colorValue,
    String? type,
    int? openingBalance,
    String? currencyCode,
    bool? isArchived,
    int? sortOrder,
  }) =>
      FinanceAccount(
        id: id,
        creationDate: creationDate,
        name: name ?? this.name,
        iconId: iconId ?? this.iconId,
        colorValue: colorValue ?? this.colorValue,
        type: type ?? this.type,
        openingBalance: openingBalance ?? this.openingBalance,
        currencyCode: currencyCode ?? this.currencyCode,
        isArchived: isArchived ?? this.isArchived,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconId': iconId,
        'colorValue': colorValue,
        'type': type,
        'openingBalance': openingBalance,
        'currencyCode': currencyCode,
        'isArchived': isArchived ? 1 : 0,
        'sortOrder': sortOrder,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory FinanceAccount.fromMap(Map<String, dynamic> map) => FinanceAccount(
        id: map['id'] as String,
        name: map['name'] as String,
        iconId: (map['iconId'] as String?) ?? 'wallet',
        colorValue: (map['colorValue'] as int?) ?? 0xFF34C759,
        type: (map['type'] as String?) ?? 'cash',
        openingBalance: (map['openingBalance'] as int?) ?? 0,
        currencyCode: (map['currencyCode'] as String?) ?? 'USD',
        isArchived: (map['isArchived'] as int? ?? 0) == 1,
        sortOrder: (map['sortOrder'] as int?) ?? 0,
        creationDate: DateTime.fromMillisecondsSinceEpoch(
            map['creationDate'] as int? ?? 0),
      );
}
