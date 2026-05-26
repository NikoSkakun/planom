import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

/// A single batch action shown in [SelectionToolbar].
class SelectionAction {
  const SelectionAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
}

/// Bottom-of-screen toolbar shown while selection mode is active. Renders
/// the supplied [actions] as a single row of icon + label buttons. Sized
/// to clear the tab bar via [bottomInset].
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    super.key,
    required this.actions,
    this.bottomInset = 0,
  });

  final List<SelectionAction> actions;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomInset + 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions
            .map((a) => Expanded(child: _ActionButton(action: a)))
            .toList(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final SelectionAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive
        ? CupertinoColors.destructiveRed
        : AppColors.accent;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 4),
      onPressed: action.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
