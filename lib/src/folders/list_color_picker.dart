import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

const kListColorPresets = [
  0xFFFF3B30, // Red
  0xFFFF9500, // Orange
  0xFFFFCC00, // Yellow
  0xFF34C759, // Green
  0xFF00C7BE, // Teal
  0xFF32ADE6, // Light Blue
  0xFF007AFF, // Blue
  0xFF5856D6, // Indigo
  0xFFAF52DE, // Purple
  0xFFFF2D55, // Pink
  0xFFA2845E, // Brown
  0xFF8E8E93, // Gray
];

/// Inline color swatch grid. Calls [onSelect] immediately when the user taps.
class ListColorSwatches extends StatelessWidget {
  const ListColorSwatches({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final int? selected;
  final void Function(int?) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _NullSwatch(
          isSelected: selected == null,
          onTap: () => onSelect(null),
          context: context,
        ),
        ...kListColorPresets.map(
          (c) => _ColorSwatch(
            color: c,
            isSelected: selected == c,
            onTap: () => onSelect(c),
            context: context,
          ),
        ),
      ],
    );
  }
}

class _NullSwatch extends StatelessWidget {
  const _NullSwatch({
    required this.isSelected,
    required this.onTap,
    required this.context,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          border: Border.all(
            color: isSelected
                ? CupertinoColors.label.resolveFrom(context)
                : CupertinoColors.separator.resolveFrom(context),
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Icon(
          CupertinoIcons.xmark,
          size: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.context,
  });

  final int color;
  final bool isSelected;
  final VoidCallback onTap;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(color),
          border: isSelected
              ? Border.all(
                  color: CupertinoColors.label.resolveFrom(context),
                  width: 2.5,
                )
              : null,
        ),
        child: isSelected
            ? const Icon(CupertinoIcons.checkmark,
                size: 16, color: CupertinoColors.white)
            : null,
      ),
    );
  }
}

/// Shows a bottom sheet color picker. [onSelected] is called with the chosen
/// color (null = no color). The sheet is dismissed automatically on selection.
void showListColorPickerSheet(
  BuildContext context,
  int? currentColor,
  void Function(int?) onSelected,
) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _PickerSheet(
      currentColor: currentColor,
      onSelected: onSelected,
    ),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.currentColor, required this.onSelected});

  final int? currentColor;
  final void Function(int?) onSelected;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.paddingOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.separator.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'List Color',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ListColorSwatches(
            selected: _selected,
            onSelect: (c) {
              setState(() => _selected = c);
              widget.onSelected(c);
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        ],
      ),
    );
  }
}
