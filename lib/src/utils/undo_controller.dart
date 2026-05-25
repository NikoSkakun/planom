import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';

/// Animated "Revert" banner that pops up after a destructive action, gives
/// the user 5 seconds to undo, then fades out.
class UndoController extends ChangeNotifier {
  static const Duration visibleFor = Duration(seconds: 5);

  UndoAction? _pending;
  UndoAction? get pending => _pending;

  Timer? _timer;
  int _seq = 0;

  /// Shows a banner labelled [label]. Replaces any in-flight undo so the
  /// latest action wins (rapid-fire deletes don't pile up).
  void show({required String label, required Future<void> Function() onUndo}) {
    _timer?.cancel();
    _seq++;
    final id = _seq;
    _pending = UndoAction(label: label, onUndo: onUndo);
    notifyListeners();
    _timer = Timer(visibleFor, () {
      // Only clear if this is still the latest action — a newer show() may
      // have already replaced it.
      if (id == _seq) _dismiss();
    });
  }

  Future<void> invoke() async {
    final action = _pending;
    if (action == null) return;
    _timer?.cancel();
    _pending = null;
    notifyListeners();
    await action.onUndo();
  }

  void _dismiss() {
    _pending = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class UndoAction {
  UndoAction({required this.label, required this.onUndo});
  final String label;
  final Future<void> Function() onUndo;
}

/// Inherits an [UndoController] down the tree so any delete site can call
/// `UndoScope.of(context).show(...)`.
class UndoScope extends InheritedWidget {
  const UndoScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final UndoController controller;

  static UndoController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UndoScope>()?.controller;

  static UndoController of(BuildContext context) {
    final c = maybeOf(context);
    assert(c != null, 'No UndoScope in widget tree');
    return c!;
  }

  @override
  bool updateShouldNotify(UndoScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Bottom-anchored animated banner with a Revert action. Position it
/// inside a Stack — it sizes itself.
class UndoBanner extends StatelessWidget {
  const UndoBanner({super.key, required this.controller, this.bottomInset = 0});

  final UndoController controller;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pending = controller.pending;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final offset = Tween<Offset>(
              begin: const Offset(0, 1.2),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(
              position: offset,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: pending == null
              ? const SizedBox.shrink(key: ValueKey('undo-empty'))
              : Padding(
                  key: ValueKey('undo-${pending.label}'),
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
                  child: _BannerBody(
                    label: pending.label,
                    onUndo: () => controller.invoke(),
                  ),
                ),
        );
      },
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.label, required this.onUndo});

  final String label;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: Color(0xF01C1C1E),
        darkColor: Color(0xF0E5E5EA),
      ),
      context,
    );
    final fg = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: CupertinoColors.white,
        darkColor: Color(0xFF1C1C1E),
      ),
      context,
    );
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoButton(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minSize: 0,
            onPressed: onUndo,
            child: Text(
              s.revert,
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
