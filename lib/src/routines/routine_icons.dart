import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../folders/folder_icon_picker.dart'
    show isCustomIconId, resolveCustomIconPath;

/// Preset icon + background-color combos shown in the icon picker.
const kRoutineIconPresets = <(String, int)>[
  ('drop.fill', 0xFF007AFF),
  ('heart.fill', 0xFFFF3B30),
  ('flame.fill', 0xFFFF9500),
  ('star.fill', 0xFFFFCC00),
  ('bolt.fill', 0xFF34C759),
  ('moon.fill', 0xFF5856D6),
  ('book.fill', 0xFFAF52DE),
  ('pencil', 0xFFFF2D55),
  ('music.note', 0xFF5AC8FA),
  ('house.fill', 0xFFA2845E),
  ('stopwatch.fill', 0xFF8E8E93),
  ('checkmark.circle.fill', 0xFF00C7BE),
  ('figure.walk', 0xFF30B0C7),
  ('bed.double.fill', 0xFF6E6E73),
  ('fork.knife', 0xFFFF6B35),
  ('leaf.fill', 0xFF4CD964),
];

IconData routineIconData(String iconId) => switch (iconId) {
      'drop.fill' => CupertinoIcons.drop_fill,
      'heart.fill' => CupertinoIcons.heart_fill,
      'flame.fill' => CupertinoIcons.flame_fill,
      'star.fill' => CupertinoIcons.star_fill,
      'bolt.fill' => CupertinoIcons.bolt_fill,
      'moon.fill' => CupertinoIcons.moon_fill,
      'book.fill' => CupertinoIcons.book_fill,
      'pencil' => CupertinoIcons.pencil,
      'music.note' => CupertinoIcons.music_note,
      'house.fill' => CupertinoIcons.house_fill,
      'stopwatch.fill' => CupertinoIcons.stopwatch_fill,
      'checkmark.circle.fill' => CupertinoIcons.checkmark_circle_fill,
      'figure.walk' => CupertinoIcons.person_crop_circle,
      'bed.double.fill' => CupertinoIcons.bed_double_fill,
      'fork.knife' => CupertinoIcons.cart_fill,
      'leaf.fill' => CupertinoIcons.leaf_arrow_circlepath,
      _ => CupertinoIcons.circle_fill,
    };

/// A circular routine icon that renders either a custom photo (clipped to a
/// circle) or a tinted SF-symbol glyph. [dimmed] fades it (used when an
/// achieve-all routine is done) and [showCheck] overlays a checkmark.
class RoutineCircleIcon extends StatelessWidget {
  const RoutineCircleIcon({
    super.key,
    required this.iconId,
    required this.iconColor,
    this.size = 40,
    this.dimmed = false,
    this.showCheck = false,
  });

  final String iconId;
  final int iconColor;
  final double size;
  final bool dimmed;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final glyphSize = size * 0.5;

    if (isCustomIconId(iconId)) {
      final path = resolveCustomIconPath(iconId);
      Widget image = SizedBox(
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
      );
      if (showCheck) {
        image = Stack(
          alignment: Alignment.center,
          children: [
            image,
            Container(
              width: size,
              height: size,
              color: const Color(0x66000000),
              child: Icon(CupertinoIcons.checkmark,
                  color: CupertinoColors.white, size: glyphSize),
            ),
          ],
        );
      }
      return Opacity(
        opacity: dimmed ? 0.5 : 1,
        child: ClipOval(child: image),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dimmed ? Color(iconColor).withOpacity(0.5) : Color(iconColor),
        shape: BoxShape.circle,
      ),
      child: Icon(
        showCheck ? CupertinoIcons.checkmark : routineIconData(iconId),
        color: CupertinoColors.white,
        size: glyphSize,
      ),
    );
  }
}
