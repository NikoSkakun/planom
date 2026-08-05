import 'package:flutter/cupertino.dart';

/// Icon keys offered when creating / editing a goal. Stored as a string on
/// [Goal.iconId]; [goalIcon] resolves a key to its glyph.
const List<String> kGoalIcons = [
  'flag',
  'star',
  'rocket',
  'target',
  'chart',
  'trophy',
  'heart',
  'book',
  'briefcase',
  'house',
  'bolt',
  'leaf',
  'paintbrush',
  'music',
  'globe',
  'sparkles',
];

IconData goalIcon(String? key) {
  switch (key) {
    case 'star':
      return CupertinoIcons.star_fill;
    case 'rocket':
      return CupertinoIcons.rocket_fill;
    case 'target':
      return CupertinoIcons.scope;
    case 'chart':
      return CupertinoIcons.chart_bar_alt_fill;
    case 'trophy':
      return CupertinoIcons.rosette;
    case 'heart':
      return CupertinoIcons.heart_fill;
    case 'book':
      return CupertinoIcons.book_fill;
    case 'briefcase':
      return CupertinoIcons.briefcase_fill;
    case 'house':
      return CupertinoIcons.house_fill;
    case 'bolt':
      return CupertinoIcons.bolt_fill;
    case 'leaf':
      return CupertinoIcons.leaf_arrow_circlepath;
    case 'paintbrush':
      return CupertinoIcons.paintbrush_fill;
    case 'music':
      return CupertinoIcons.music_note_2;
    case 'globe':
      return CupertinoIcons.globe;
    case 'sparkles':
      return CupertinoIcons.sparkles;
    case 'flag':
    default:
      return CupertinoIcons.flag_fill;
  }
}

/// Colour swatches offered for a goal, mirroring the app's accent palette.
const List<int> kGoalColors = [
  0xFFFF4D00,
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
];

/// Round tinted badge for a goal, used in the list and the detail header.
class GoalCircleIcon extends StatelessWidget {
  const GoalCircleIcon({
    super.key,
    required this.iconId,
    required this.color,
    this.size = 38,
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
      child: Icon(goalIcon(iconId), size: size * 0.5, color: tint),
    );
  }
}
