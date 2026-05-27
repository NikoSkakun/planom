import 'package:flutter/widgets.dart';

/// Shared notifier scope that lets descendants temporarily push the global
/// "+" floating action button further up the screen. The HomeShell creates
/// the notifier and positions the plus button via a ValueListenableBuilder
/// on it; views that show their own bottom-of-screen affordance (notably the
/// task selection toolbar) write the visible toolbar height into the scope
/// so the plus button reads as sitting just above the toolbar instead of
/// underneath it.
///
/// Only one view sets the inset at a time — the user is always looking at a
/// single tab. Each [PlusButtonLift] cell writes its desired value when
/// active and clears the value when it disappears.
class PlusButtonInsetScope extends InheritedWidget {
  const PlusButtonInsetScope({
    super.key,
    required this.inset,
    required super.child,
  });

  final ValueNotifier<double> inset;

  static ValueNotifier<double>? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PlusButtonInsetScope>();
    return scope?.inset;
  }

  @override
  bool updateShouldNotify(covariant PlusButtonInsetScope oldWidget) =>
      inset != oldWidget.inset;
}

/// Drop this anywhere in the tree to declare a temporary lift for the
/// global plus button. While this widget is mounted (and [lift] > 0), the
/// scope's inset notifier holds [lift]; on dispose / when [lift] returns
/// to 0 the inset clears to 0. Bypasses the scope silently when no
/// PlusButtonInsetScope is present (e.g. tests, isolated previews).
class PlusButtonLift extends StatefulWidget {
  const PlusButtonLift({
    super.key,
    required this.lift,
    required this.child,
  });

  /// Pixels to add to the plus button's bottom offset. 0 = no lift.
  final double lift;
  final Widget child;

  @override
  State<PlusButtonLift> createState() => _PlusButtonLiftState();
}

class _PlusButtonLiftState extends State<PlusButtonLift> {
  ValueNotifier<double>? _scope;

  void _applyLift() {
    final scope = _scope;
    if (scope == null) return;
    if (scope.value != widget.lift) {
      scope.value = widget.lift;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = PlusButtonInsetScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyLift();
    });
  }

  @override
  void didUpdateWidget(covariant PlusButtonLift old) {
    super.didUpdateWidget(old);
    if (old.lift != widget.lift) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyLift();
      });
    }
  }

  @override
  void dispose() {
    final scope = _scope;
    if (scope != null && scope.value == widget.lift && widget.lift != 0) {
      scope.value = 0;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
