import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../utils/platform_capabilities.dart';

/// The most recent unhandled widget deep-link URI (`planom://<host>?…`).
///
/// [HomeShell] listens to this and reacts (switching tabs / opening creation
/// sheets), then resets it to null to mark the link consumed. Using a global
/// notifier — rather than threading a callback through the widget tree —
/// keeps the deep-link plumbing decoupled from the per-space `HomeShell`
/// instances, which are torn down and rebuilt on every space switch.
final ValueNotifier<Uri?> widgetDeepLink = ValueNotifier<Uri?>(null);

bool _deepLinksInitialized = false;

/// Wires the `home_widget` launch + click streams into [widgetDeepLink].
/// Call once during app start-up, after the widget service is initialised.
Future<void> initWidgetDeepLinks() async {
  if (_deepLinksInitialized || !PlatformCapabilities.supportsHomeWidgets) return;
  _deepLinksInitialized = true;

  // App launched from a terminated state by tapping a widget.
  try {
    final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initial != null) widgetDeepLink.value = initial;
  } catch (e) {
    debugPrint('[widgets] initiallyLaunchedFromHomeWidget failed: $e');
  }

  // App already running / resumed by a widget tap.
  HomeWidget.widgetClicked.listen((uri) {
    if (uri != null) widgetDeepLink.value = uri;
  });
}
