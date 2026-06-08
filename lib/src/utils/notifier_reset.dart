import 'package:flutter/widgets.dart';

/// Schedules `notifier.value = value` to run *after* the current frame.
///
/// Use this from a `State.dispose()` that needs to reset a notifier owned by an
/// ancestor (e.g. the home shell's "active list / folder / date" notifiers that
/// drive the floating + button). Writing the value synchronously inside
/// `dispose()` notifies that notifier's listeners while the widget tree is
/// locked (the view is being unmounted during the build/finalize phase), which
/// throws:
///
///   setState() or markNeedsBuild() called when widget tree was locked.
///
/// Deferring to a post-frame callback performs the write once the tree is
/// unlocked. It is best-effort: if the notifier was itself disposed before the
/// frame completes (e.g. the whole shell is being torn down) the write is
/// silently skipped.
void resetNotifierAfterFrame<T>(ValueNotifier<T> notifier, T value) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      notifier.value = value;
    } catch (_) {
      // Notifier disposed before the frame ran — nothing left to reset.
    }
  });
}
