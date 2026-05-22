import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

/// One row in [showSelectionMenu]. `isDestructive` renders the row in red
/// (typical iOS destructive action like "Clear" or "Remove").
class SelectionMenuOption<T> {
  const SelectionMenuOption({
    required this.value,
    required this.label,
    this.icon,
    this.isDestructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool isDestructive;
}

/// Shows a centred floating selection menu styled the same as the app's
/// three-dots dropdowns (rounded panel, drop shadow, vertical rows with
/// checkmarks on the current value). Returns the chosen value, or `null` if
/// the user tapped outside to dismiss.
///
/// Replaces system [CupertinoActionSheet] popups for single-choice pickers
/// (visibility, language, sort order, duration, etc.) so the whole app uses
/// one consistent menu style.
Future<T?> showSelectionMenu<T>({
  required BuildContext context,
  required List<SelectionMenuOption<T>> options,
  T? current,
  String? title,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<T?>();
  late OverlayEntry entry;

  void close(T? value) {
    if (completer.isCompleted) return;
    completer.complete(value);
    entry.remove();
  }

  entry = OverlayEntry(builder: (ctx) {
    return _SelectionMenuOverlay<T>(
      options: options,
      current: current,
      title: title,
      onSelect: (v) => close(v),
      onDismiss: () => close(null),
    );
  });

  overlay.insert(entry);
  return completer.future;
}

class _SelectionMenuOverlay<T> extends StatelessWidget {
  const _SelectionMenuOverlay({
    required this.options,
    required this.current,
    required this.title,
    required this.onSelect,
    required this.onDismiss,
  });

  final List<SelectionMenuOption<T>> options;
  final T? current;
  final String? title;
  final ValueChanged<T> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final separator = CupertinoColors.separator.resolveFrom(context);

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: const SizedBox.expand(),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Text(
                          title!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                            letterSpacing: -0.08,
                          ),
                        ),
                      ),
                      Container(height: 0.5, color: separator),
                    ],
                    for (int i = 0; i < options.length; i++) ...[
                      _OptionRow<T>(
                        option: options[i],
                        isSelected: options[i].value == current,
                        onTap: () => onSelect(options[i].value),
                      ),
                      if (i < options.length - 1)
                        Container(height: 0.5, color: separator),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final SelectionMenuOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = option.isDestructive
        ? CupertinoColors.destructiveRed
        : CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          if (option.icon != null) ...[
            Icon(option.icon, size: 18, color: color),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              option.label,
              style: TextStyle(fontSize: 16, color: color),
            ),
          ),
          if (isSelected)
            Icon(CupertinoIcons.checkmark, size: 16, color: AppColors.accent),
        ],
      ),
    );
  }
}
