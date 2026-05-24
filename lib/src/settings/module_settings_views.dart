import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

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
  const NotesSettingsView({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabNotes),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsSectionHeader(s.sectionTasksUi),
                  SettingsToggleRow(
                    label: s.showAddFolderButton,
                    value: controller.smartListPrefs.showNotesAddFolderButton,
                    onChanged: controller.updateShowNotesAddFolderButton,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
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
