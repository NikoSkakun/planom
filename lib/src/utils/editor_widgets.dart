import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

/// Shared accent palette used by the icon/color pickers across editor screens.
const kEditorColors = <int>[
  0xFFFF3B30, 0xFFFF9500, 0xFFFFCC00, 0xFF34C759, 0xFF00C7BE,
  0xFF30B0C7, 0xFF007AFF, 0xFF5856D6, 0xFFAF52DE, 0xFFFF2D55,
  0xFFA2845E, 0xFF8E8E93,
];

/// A rounded, grouped-background container wrapping a single editor control.
class EditorField extends StatelessWidget {
  const EditorField({super.key, required this.child, this.padded = true});
  final Widget child;
  final bool padded;
  @override
  Widget build(BuildContext context) => Container(
        padding: padded
            ? const EdgeInsets.symmetric(vertical: 6)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );
}

/// A small uppercase section label.
class EditorLabel extends StatelessWidget {
  const EditorLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context))),
      );
}

/// A tappable settings-style row with a trailing value + chevron.
class EditorRowButton extends StatelessWidget {
  const EditorRowButton(
      {super.key,
      required this.label,
      required this.value,
      required this.onTap,
      this.leading});
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(child: Text(label)),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context))),
            ),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_right,
                size: 16,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
          ],
        ),
      ),
    );
  }
}

/// A reusable grid of (iconKey → glyph) choices. Tapping one calls [onPick]
/// with the icon key and its preset default color.
class EditorIconGrid extends StatelessWidget {
  const EditorIconGrid({
    super.key,
    required this.presets,
    required this.selected,
    required this.tint,
    required this.glyph,
    required this.onPick,
  });

  final List<(String, int)> presets;
  final String selected;
  final int tint;
  final IconData Function(String) glyph;
  final void Function(String iconKey, int defaultColor) onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final (icon, color) in presets)
          GestureDetector(
            onTap: () => onPick(icon, color),
            child: Container(
              decoration: BoxDecoration(
                color: Color(tint).withOpacity(icon == selected ? 1 : 0.18),
                shape: BoxShape.circle,
                border: icon == selected
                    ? Border.all(color: Color(tint), width: 2)
                    : null,
              ),
              child: Icon(
                glyph(icon),
                size: 20,
                color: icon == selected ? CupertinoColors.white : Color(tint),
              ),
            ),
          ),
      ],
    );
  }
}

/// A wrap of color swatches with the selected one checkmarked.
class EditorColorRow extends StatelessWidget {
  const EditorColorRow(
      {super.key, required this.selected, required this.onPick});
  final int selected;
  final void Function(int color) onPick;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in kEditorColors)
          GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: c == selected
                    ? Border.all(
                        color: CupertinoColors.label.resolveFrom(context),
                        width: 2)
                    : null,
              ),
              child: c == selected
                  ? const Icon(CupertinoIcons.checkmark,
                      size: 16, color: CupertinoColors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// A primary-accent full-width action button used at the bottom of editors.
class EditorPrimaryButton extends StatelessWidget {
  const EditorPrimaryButton(
      {super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          color: AppColors.accent,
          onPressed: onPressed,
          child: Text(label),
        ),
      );
}
