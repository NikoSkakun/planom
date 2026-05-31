import 'package:flutter/cupertino.dart';

import '../folders/folder_icon_picker.dart';
import '../integrations/google/google_calendar_controller.dart';
import '../localization/strings.dart';
import '../utils/selection_menu.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';
import 'smart_list_prefs.dart';

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

  static String _visibilityLabel(S s, SmartListVisibility v) {
    switch (v) {
      case SmartListVisibility.show:
        return s.visibilityShow;
      case SmartListVisibility.showIfNotEmpty:
        return s.visibilityIfNotEmpty;
      case SmartListVisibility.hidden:
        return s.visibilityHidden;
    }
  }

  Future<void> _showTrashVisibilityPicker(
      BuildContext context, SmartListVisibility current) async {
    final s = S.of(context);
    final selected = await showSelectionMenu<SmartListVisibility>(
      context: context,
      title: s.visibility,
      current: current,
      options: SmartListVisibility.values
          .map((v) => SelectionMenuOption(
                value: v,
                label: _visibilityLabel(s, v),
              ))
          .toList(),
    );
    if (selected != null) {
      controller.updateSmartListVisibility('notesTrash', selected);
    }
  }

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
            final prefs = controller.smartListPrefs;
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsSectionHeader(s.sectionSmartLists),
                  SettingsNavRow(
                    label: s.trash,
                    trailingLabel:
                        _visibilityLabel(s, prefs.notesTrash),
                    onTap: () => _showTrashVisibilityPicker(
                        context, prefs.notesTrash),
                  ),
                  const SizedBox(height: 18),
                  SettingsSectionHeader(s.sectionBody),
                  SettingsToggleRow(
                    label: s.useMarkdown,
                    value: prefs.notesUseMarkdown,
                    onChanged: controller.updateNotesUseMarkdown,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      s.useMarkdownHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SettingsSectionHeader(s.sectionTasksUi),
                  SettingsToggleRow(
                    label: s.showAddFolderButton,
                    value: controller.smartListPrefs.showNotesAddFolderButton,
                    onChanged: controller.updateShowNotesAddFolderButton,
                  ),
                  const SizedBox(height: 18),
                  SettingsSectionHeader(s.sectionDefaults),
                  GestureDetector(
                    onTap: () => showFolderIconPickerSheet(
                      context,
                      currentIconId: controller.defaultNoteFolderIcon,
                      isFolder: true,
                      onSelected: (id, _) =>
                          controller.updateDefaultNoteFolderIcon(id),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          CupertinoColors.tertiarySystemBackground,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: buildFolderItemIcon(
                                controller.defaultNoteFolderIcon,
                                isFolder: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.defaultNoteFolderIcon,
                              style: const TextStyle(fontSize: 17),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: CupertinoColors.tertiaryLabel
                                .resolveFrom(context),
                          ),
                        ],
                      ),
                    ),
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
  const CalendarSettingsView({
    super.key,
    required this.controller,
    this.googleCalendarController,
  });

  final SettingsController controller;
  final GoogleCalendarController? googleCalendarController;

  Future<void> _pickDefaultContainer(BuildContext context) async {
    final gc = googleCalendarController;
    if (gc == null) return;
    final s = S.of(context);
    final writable = gc.writableSelectedCalendars;
    if (writable.isEmpty) return;
    final multiAccount = gc.accountCount > 1;
    final options = <SelectionMenuOption<String>>[
      SelectionMenuOption(value: _localContainerKey, label: s.planomLocal),
      for (final cal in writable)
        SelectionMenuOption(
          value: cal.key,
          label: multiAccount ? '${cal.summary} · ${cal.accountId}' : cal.summary,
        ),
    ];
    final pick = await showSelectionMenu<String>(
      context: context,
      title: s.calendarDefaultContainer,
      current: gc.defaultCalendar?.key ?? _localContainerKey,
      options: options,
    );
    if (pick == null) return;
    if (pick == _localContainerKey) {
      await gc.clearDefaultCalendar();
      return;
    }
    final match = writable.where((c) => c.key == pick).toList();
    if (match.isNotEmpty) await gc.setDefaultCalendar(match.first);
  }

  String _defaultContainerLabel(S s, GoogleCalendarController? gc) {
    final def = gc?.defaultCalendar;
    if (def == null) return s.planomLocal;
    return (gc!.accountCount > 1)
        ? '${def.summary} · ${def.accountId}'
        : def.summary;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final gc = googleCalendarController;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabCalendar),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: gc == null
              ? controller
              : Listenable.merge([controller, gc]),
          builder: (context, _) {
            final hasWritableGoogleCalendars =
                gc != null && gc.isConnected && gc.writableSelectedCalendars.isNotEmpty;
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsToggleRow(
                    label: s.calendarAllowCreatingTasks,
                    value: controller.calendarAllowCreatingTasks,
                    onChanged: controller.updateCalendarAllowCreatingTasks,
                  ),
                  const SizedBox(height: 1),
                  SettingsToggleRow(
                    label: s.calendarAllowCreatingEvents,
                    value: controller.calendarAllowCreatingEvents,
                    onChanged: controller.updateCalendarAllowCreatingEvents,
                  ),
                  if (hasWritableGoogleCalendars) ...[
                    const SizedBox(height: 18),
                    SettingsNavRow(
                      label: s.calendarDefaultContainer,
                      trailingLabel: _defaultContainerLabel(s, gc),
                      onTap: () => _pickDefaultContainer(context),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Sentinel value for "Planom (Local)" in the default-container picker.
const String _localContainerKey = '__planom_local__';

class RoutinesSettingsView extends StatelessWidget {
  const RoutinesSettingsView({super.key});
  @override
  Widget build(BuildContext context) =>
      _EmptySettingsView(title: S.of(context).tabRoutines);
}
