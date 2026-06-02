import 'package:flutter/cupertino.dart';

/// A read-only card showing a folder's or list's description, rendered at the
/// top of the inside-folder / inside-list views as a separate block.
class ItemDescriptionBlock extends StatelessWidget {
  const ItemDescriptionBlock({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        description,
        style: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}
