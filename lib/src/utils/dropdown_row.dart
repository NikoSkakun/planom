import 'package:flutter/cupertino.dart';

/// A single tappable row used inside the app's dropdown menu panels:
/// leading icon + label, optional [color] override (e.g. for destructive
/// actions). Shared by the tasks, task-detail and note-detail dropdowns.
class DropdownRow extends StatelessWidget {
  const DropdownRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 16, color: fg)),
          ),
        ],
      ),
    );
  }
}
