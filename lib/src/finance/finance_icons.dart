import 'package:flutter/cupertino.dart';

/// Icon keys offered when creating / editing a finance category. Stored as a
/// string on [FinanceCategory.iconId] so the DB stays icon-library agnostic;
/// [financeCategoryIcon] resolves a key back to its glyph.
const List<String> kFinanceCategoryIcons = [
  'cart',
  'bag',
  'flame',
  'car',
  'bus',
  'airplane',
  'house',
  'bolt',
  'drop',
  'wifi',
  'phone',
  'heart',
  'bandage',
  'book',
  'gamecontroller',
  'music_note',
  'film',
  'gift',
  'briefcase',
  'creditcard',
  'money_dollar',
  'chart_bar',
  'paw',
  'scissors',
  'wrench',
  'tag',
  'star',
  'plus_circle',
];

/// Icon keys offered for an account or card. Shares [financeCategoryIcon]'s
/// resolution so account and category badges can use the same widget.
const List<String> kFinanceAccountIcons = [
  'creditcard',
  'banknote',
  'wallet',
  'building',
  'piggy',
  'money_dollar',
  'chart_bar',
  'phone',
  'globe',
  'star',
  'bag',
  'tag',
];

/// Resolves a stored category icon key to its Cupertino glyph. Unknown keys
/// (e.g. from a newer build's backup) fall back to a neutral tag.
IconData financeCategoryIcon(String? key) {
  switch (key) {
    case 'cart':
      return CupertinoIcons.cart;
    case 'bag':
      return CupertinoIcons.bag;
    case 'flame':
      return CupertinoIcons.flame;
    case 'car':
      return CupertinoIcons.car_detailed;
    case 'bus':
      return CupertinoIcons.bus;
    case 'airplane':
      return CupertinoIcons.airplane;
    case 'house':
      return CupertinoIcons.house;
    case 'bolt':
      return CupertinoIcons.bolt;
    case 'drop':
      return CupertinoIcons.drop;
    case 'wifi':
      return CupertinoIcons.wifi;
    case 'phone':
      return CupertinoIcons.device_phone_portrait;
    case 'heart':
      return CupertinoIcons.heart;
    case 'bandage':
      return CupertinoIcons.bandage;
    case 'book':
      return CupertinoIcons.book;
    case 'gamecontroller':
      return CupertinoIcons.game_controller;
    case 'music_note':
      return CupertinoIcons.music_note;
    case 'film':
      return CupertinoIcons.film;
    case 'gift':
      return CupertinoIcons.gift;
    case 'briefcase':
      return CupertinoIcons.briefcase;
    case 'creditcard':
      return CupertinoIcons.creditcard;
    case 'money_dollar':
      return CupertinoIcons.money_dollar;
    case 'banknote':
      return CupertinoIcons.money_dollar_circle;
    case 'wallet':
      return CupertinoIcons.briefcase_fill;
    case 'building':
      return CupertinoIcons.building_2_fill;
    case 'piggy':
      return CupertinoIcons.arrow_down_circle;
    case 'chart_bar':
      return CupertinoIcons.chart_bar;
    case 'paw':
      return CupertinoIcons.paw;
    case 'scissors':
      return CupertinoIcons.scissors;
    case 'wrench':
      return CupertinoIcons.wrench;
    case 'star':
      return CupertinoIcons.star;
    case 'plus_circle':
      return CupertinoIcons.plus_circle;
    case 'tag':
    default:
      return CupertinoIcons.tag;
  }
}

/// Colour swatches offered for a category, mirroring the app's accent palette.
const List<int> kFinanceCategoryColors = [
  0xFFFF3B30,
  0xFFFF9500,
  0xFFFFCC00,
  0xFF34C759,
  0xFF00C7BE,
  0xFF30B0C7,
  0xFF007AFF,
  0xFF5856D6,
  0xFFAF52DE,
  0xFFFF2D55,
  0xFFA2845E,
  0xFF8E8E93,
];

/// Round tinted badge used for a category everywhere it appears (transaction
/// rows, pickers, budget rows, the breakdown list).
class FinanceCategoryIcon extends StatelessWidget {
  const FinanceCategoryIcon({
    super.key,
    required this.iconId,
    required this.color,
    this.size = 34,
  });

  final String? iconId;
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = Color(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withOpacity(0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(
        financeCategoryIcon(iconId),
        size: size * 0.5,
        color: tint,
      ),
    );
  }
}
