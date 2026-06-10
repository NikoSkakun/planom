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
