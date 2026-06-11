import 'package:flutter/widgets.dart';

/// True when the on-screen keyboard is currently visible in the window
/// hosting [context].
///
/// Reads the root [FlutterView]'s insets instead of the inherited
/// [MediaQuery]: Cupertino scaffolds (CupertinoTabScaffold and
/// CupertinoPageScaffold) consume the bottom view inset for their own
/// keyboard avoidance, so `MediaQuery.viewInsetsOf` reads 0 inside a tab
/// even while the keyboard is fully open — which silently broke every
/// "is the keyboard up?" decision made from within a tab's subtree.
bool isKeyboardVisible(BuildContext context) =>
    View.of(context).viewInsets.bottom > 0;

/// Marks the window during which the keyboard-appearance refresh
/// (`_KeyboardBrightnessReactor` in app.dart) deliberately unfocuses and
/// refocuses the active text field to re-attach the IME after a light/dark
/// flip.
///
/// Views that tear their editor down on focus loss (note / task detail)
/// check [isActive] to keep the editor mounted across that gap — tearing it
/// down would detach the FocusNode and turn the reactor's refocus into a
/// silent no-op. Outside this window a focus drop is treated as a real
/// dismissal (hide-keyboard button, iOS shake-to-undo dialog stealing first
/// responder, tap elsewhere) and must NOT trigger any automatic refocus:
/// fighting those flows re-opens the keyboard the user just dismissed.
class KeyboardAppearanceRefresh {
  KeyboardAppearanceRefresh._();

  static DateTime? _startedAt;

  /// Auto-expiry so a refresh that dies mid-flight can't leave focus-loss
  /// handling deferred forever. Generously covers the reactor's refocus +
  /// both verify retries.
  static const Duration _window = Duration(seconds: 2);

  static void begin() => _startedAt = DateTime.now();

  static void end() => _startedAt = null;

  static bool get isActive {
    final t = _startedAt;
    return t != null && DateTime.now().difference(t) < _window;
  }
}

