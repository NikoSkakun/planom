/// Startup plumbing that keeps a failure during boot from turning into a blank
/// app.
///
/// Everything `main()` awaits happens before the first frame, so an exception —
/// or an await that simply never returns — leaves the platform showing its
/// launch surface forever. On iOS that reads as a white screen with no way to
/// tell what went wrong. These helpers make sure the app either starts or says
/// why it didn't.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

/// Runs an optional startup step: one whose failure must not stop the app.
///
/// Plugin initialisation (notifications, calendar integrations) is best-effort
/// by design — the features it powers degrade, the app still opens. The
/// [timeout] matters as much as the try/catch: a platform channel that never
/// answers would otherwise hang boot indefinitely, which looks identical to a
/// crash from the outside.
Future<void> runOptionalStartupStep(
  String label,
  Future<void> Function() step, {
  Duration timeout = const Duration(seconds: 10),
  List<StartupProblem>? problems,
}) async {
  try {
    await step().timeout(timeout);
  } catch (error, stack) {
    problems?.add(StartupProblem(label, error, stack));
    debugPrint('Planom startup: optional step "$label" failed: $error');
  }
}

/// A startup step that failed. Collected rather than thrown so several can be
/// reported at once.
class StartupProblem {
  const StartupProblem(this.label, this.error, this.stack);

  final String label;
  final Object error;
  final StackTrace stack;

  @override
  String toString() => '$label: $error';
}

/// Shown when a step the app genuinely cannot run without fails — opening the
/// database, reading settings, loading the space list.
///
/// The point is that something legible reaches the screen: the failing step,
/// the error, and the stack, all selectable so they can be copied into a bug
/// report. [onRetry] re-runs the whole startup, which is enough to recover from
/// a transient failure (a locked database file, a slow disk) without the user
/// having to force-quit.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.label,
    required this.error,
    required this.stack,
    this.onRetry,
  });

  final String label;
  final Object error;
  final StackTrace? stack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Planom could not start',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Failed while $label.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      '$error\n\n${stack ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Menlo',
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ),
                ),
                if (onRetry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: onRetry,
                        child: const Text('Try again'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces the framework's error placeholder with one that stays readable in
/// release builds.
///
/// Flutter's default paints a plain light-grey rectangle once assertions are
/// off — indistinguishable from a blank screen when the widget that failed is
/// the whole app. This keeps the same footprint but says what broke.
void installReadableErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _StartupErrorBox(details: details);
  };
}

class _StartupErrorBox extends StatelessWidget {
  const _StartupErrorBox({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    // No Directionality is guaranteed here — this widget can replace anything,
    // including the root above MaterialApp/CupertinoApp.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF2B0F0F),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          child: Text(
            'Planom hit an error while drawing this screen:\n\n'
            '${details.exceptionAsString()}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFFFB4A9),
              fontFamily: 'Menlo',
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
