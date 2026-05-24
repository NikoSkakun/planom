import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';

/// Per-tab settings sub-pages reached from Settings → (Notes / Calendar /
/// Routines). They currently host no settings; the page exists so that
/// per-tab options have a stable home as features grow.
class _EmptySettingsView extends StatelessWidget {
  const _EmptySettingsView({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(title),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              s.noOptionsYet,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotesSettingsView extends StatelessWidget {
  const NotesSettingsView({super.key});
  @override
  Widget build(BuildContext context) =>
      _EmptySettingsView(title: S.of(context).tabNotes);
}

class CalendarSettingsView extends StatelessWidget {
  const CalendarSettingsView({super.key});
  @override
  Widget build(BuildContext context) =>
      _EmptySettingsView(title: S.of(context).tabCalendar);
}

class RoutinesSettingsView extends StatelessWidget {
  const RoutinesSettingsView({super.key});
  @override
  Widget build(BuildContext context) =>
      _EmptySettingsView(title: S.of(context).tabRoutines);
}
