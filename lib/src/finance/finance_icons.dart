import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../folders/folder_icon_picker.dart'
    show isCustomIconId, resolveCustomIconPath;

/// String-key → glyph mapping for Finance accounts & categories. Keys are kept
/// stable (stored in the DB); the concrete [IconData] can change freely.
IconData financeIconData(String iconId) => switch (iconId) {
      'wallet' => CupertinoIcons.money_dollar_circle_fill,
      'cash' => CupertinoIcons.money_dollar,
      'bank' => CupertinoIcons.building_2_fill,
      'card' => CupertinoIcons.creditcard_fill,
      'savings' => CupertinoIcons.lock_fill,
      'investment' => CupertinoIcons.chart_bar_alt_fill,
      'briefcase' => CupertinoIcons.briefcase_fill,
      'chart_bar' => CupertinoIcons.chart_bar_alt_fill,
      'gift' => CupertinoIcons.gift_fill,
      'cart' => CupertinoIcons.cart_fill,
      'fork_knife' => CupertinoIcons.flame_fill,
      'car' => CupertinoIcons.car_fill,
      'house' => CupertinoIcons.house_fill,
      'bolt' => CupertinoIcons.bolt_fill,
      'bag' => CupertinoIcons.bag_fill,
      'heart' => CupertinoIcons.heart_fill,
      'film' => CupertinoIcons.film_fill,
      'airplane' => CupertinoIcons.airplane,
      'gamecontroller' => CupertinoIcons.game_controller_solid,
      'book' => CupertinoIcons.book_fill,
      'phone' => CupertinoIcons.device_phone_portrait,
      'star' => CupertinoIcons.star_fill,
      'tag' => CupertinoIcons.tag_fill,
      'money' => CupertinoIcons.money_dollar,
      'creditcard' => CupertinoIcons.creditcard_fill,
      _ => CupertinoIcons.circle_fill,
    };

/// Account-type presets shown when creating an account: (typeKey, iconKey).
const kAccountTypePresets = <(String, String)>[
  ('cash', 'cash'),
  ('bank', 'bank'),
  ('card', 'card'),
  ('savings', 'savings'),
  ('investment', 'investment'),
  ('other', 'wallet'),
];

/// Icon choices offered in the account / category icon picker, with a sensible
/// default tint each.
const kFinanceIconPresets = <(String, int)>[
  ('wallet', 0xFF34C759),
  ('cash', 0xFF34C759),
  ('bank', 0xFF007AFF),
  ('card', 0xFF5856D6),
  ('savings', 0xFFFF9500),
  ('investment', 0xFF30B0C7),
  ('briefcase', 0xFFA2845E),
  ('chart_bar', 0xFF30B0C7),
  ('gift', 0xFFFF2D55),
  ('cart', 0xFF34C759),
  ('fork_knife', 0xFFFF9500),
  ('car', 0xFF007AFF),
  ('house', 0xFFA2845E),
  ('bolt', 0xFFFFCC00),
  ('bag', 0xFFAF52DE),
  ('heart', 0xFFFF3B30),
  ('film', 0xFF5856D6),
  ('airplane', 0xFF5AC8FA),
  ('gamecontroller', 0xFFFF2D55),
  ('book', 0xFFAF52DE),
  ('phone', 0xFF8E8E93),
  ('star', 0xFFFFCC00),
  ('tag', 0xFF007AFF),
  ('money', 0xFF34C759),
];

/// A circular tinted Finance icon (or a clipped custom photo).
class FinanceCircleIcon extends StatelessWidget {
  const FinanceCircleIcon({
    super.key,
    required this.iconId,
    required this.colorValue,
    this.size = 40,
  });

  final String iconId;
  final int colorValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyphSize = size * 0.5;
    if (isCustomIconId(iconId)) {
      final path = resolveCustomIconPath(iconId);
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: path == null
              ? Container(color: CupertinoColors.systemGrey4.resolveFrom(context))
              : Image.file(
                  File(path),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                  ),
                ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(colorValue),
        shape: BoxShape.circle,
      ),
      child: Icon(financeIconData(iconId),
          color: CupertinoColors.white, size: glyphSize),
    );
  }
}
