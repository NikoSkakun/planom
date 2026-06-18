import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../folders/folder_icon_picker.dart'
    show isCustomIconId, resolveCustomIconPath;

/// String-key → glyph mapping for Goals. Keys are stored in the DB; the glyph
/// can change freely.
IconData goalIconData(String iconId) => switch (iconId) {
      'flag' => CupertinoIcons.flag_fill,
      'star' => CupertinoIcons.star_fill,
      'rocket' => CupertinoIcons.rocket_fill,
      'book' => CupertinoIcons.book_fill,
      'heart' => CupertinoIcons.heart_fill,
      'bolt' => CupertinoIcons.bolt_fill,
      'flame' => CupertinoIcons.flame_fill,
      'money' => CupertinoIcons.money_dollar_circle_fill,
      'house' => CupertinoIcons.house_fill,
      'airplane' => CupertinoIcons.airplane,
      'dumbbell' => CupertinoIcons.sportscourt_fill,
      'leaf' => CupertinoIcons.leaf_arrow_circlepath,
      'paintbrush' => CupertinoIcons.paintbrush_fill,
      'music' => CupertinoIcons.music_note,
      'graduation' => CupertinoIcons.book_circle_fill,
      'globe' => CupertinoIcons.globe,
      'mountain' => CupertinoIcons.triangle_fill,
      'trophy' => CupertinoIcons.star_circle_fill,
      _ => CupertinoIcons.flag_fill,
    };

/// Icon + tint presets shown in the goal icon picker.
const kGoalIconPresets = <(String, int)>[
  ('flag', 0xFFFF9500),
  ('star', 0xFFFFCC00),
  ('rocket', 0xFFFF3B30),
  ('trophy', 0xFFFFCC00),
  ('book', 0xFFAF52DE),
  ('graduation', 0xFF5856D6),
  ('heart', 0xFFFF3B30),
  ('bolt', 0xFF34C759),
  ('flame', 0xFFFF9500),
  ('money', 0xFF34C759),
  ('house', 0xFFA2845E),
  ('airplane', 0xFF5AC8FA),
  ('dumbbell', 0xFF007AFF),
  ('leaf', 0xFF4CD964),
  ('paintbrush', 0xFFFF2D55),
  ('music', 0xFF5AC8FA),
  ('globe', 0xFF30B0C7),
  ('mountain', 0xFF8E8E93),
];

/// A circular tinted Goal icon (or a clipped custom photo).
class GoalCircleIcon extends StatelessWidget {
  const GoalCircleIcon({
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
      child: Icon(goalIconData(iconId),
          color: CupertinoColors.white, size: glyphSize),
    );
  }
}
