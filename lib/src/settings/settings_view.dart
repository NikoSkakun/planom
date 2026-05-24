import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart' show ReorderableDragStartListener, ReorderableListView, ThemeMode;

import '../integrations/google/google_calendar_controller.dart';
import '../localization/strings.dart';
import '../security/security_service.dart';
import '../spaces/space_manager.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'appearance_view.dart';
import 'backup_service.dart';
import 'data_view.dart';
import 'font_picker_view.dart';
import 'google_calendar_settings_view.dart';
import 'module_settings_views.dart';
import 'notifications_view.dart';
import 'security_view.dart';
import 'settings_controller.dart';
import 'spaces_view.dart';
import 'sync_settings_view.dart';
import 'tasks_settings_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.controller,
    this.backupService,
    this.securityService,
    this.googleCalendarController,
  });

  final SettingsController controller;
  final BackupService? backupService;
  final SecurityService? securityService;
  final GoogleCalendarController? googleCalendarController;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  Future<void> _showLanguagePicker(BuildContext context) async {
    final s = S.of(context);
    final current = widget.controller.locale.languageCode;
    final selected = await showSelectionMenu<String>(
      context: context,
      title: s.language,
      current: current,
      options: kSupportedLocales
          .map((loc) => SelectionMenuOption(
                value: loc.languageCode,
                label: kLanguageNames[loc.languageCode] ?? loc.languageCode,
              ))
          .toList(),
    );
    if (selected != null) {
      widget.controller.updateLocale(Locale(selected));
    }
  }

  void _openFontPicker(BuildContext context) {
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => FontPickerView(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final hasBackup = widget.backupService != null;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.settings),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ── Appearance ──────────────────────────────────────────────
            Text(
              s.sectionAppearance,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (ctx, _) {
                final tm = widget.controller.themeMode;
                final themeName = tm == ThemeMode.light
                    ? s.themeLight
                    : tm == ThemeMode.dark
                        ? s.themeDark
                        : s.themeSystem;
                return _NavRow(
                  label: s.sectionAppearance,
                  icon: CupertinoIcons.paintbrush,
                  trailingLabel: themeName,
                  onTap: () => Navigator.of(context).push(
                    FastRoute<void>(
                      builder: (_) => AppearanceView(
                        controller: widget.controller,
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Language ────────────────────────────────────────────────
            const SizedBox(height: 18),
            Text(
              s.sectionLanguage,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (ctx, _) {
                final code = widget.controller.locale.languageCode;
                return _NavRow(
                  label: s.language,
                  icon: CupertinoIcons.globe,
                  trailingLabel: kLanguageNames[code] ?? code,
                  onTap: () => _showLanguagePicker(context),
                );
              },
            ),
            const SizedBox(height: 1),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (ctx, _) {
                final key = widget.controller.fontKey;
                return _NavRow(
                  label: s.font,
                  icon: CupertinoIcons.textformat,
                  trailingLabel: key == kSystemFontKey
                      ? s.systemFont
                      : fontDisplayName(key),
                  onTap: () => _openFontPicker(context),
                );
              },
            ),

            // ── Modules ─────────────────────────────────────────────────
            const SizedBox(height: 18),
            Text(
              s.sectionModules,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
            _NavRow(
              label: s.tabTasks,
              icon: CupertinoIcons.checkmark_square,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => TasksSettingsView(
                    controller: widget.controller,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 1),
            _NavRow(
              label: s.tabNotes,
              icon: CupertinoIcons.doc_text,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => NotesSettingsView(
                    controller: widget.controller,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 1),
            _NavRow(
              label: s.tabCalendar,
              icon: CupertinoIcons.calendar,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => const CalendarSettingsView(),
                ),
              ),
            ),
            const SizedBox(height: 1),
            _NavRow(
              label: s.tabRoutines,
              icon: CupertinoIcons.repeat,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => const RoutinesSettingsView(),
                ),
              ),
            ),

            // ── Spaces ──────────────────────────────────────────────────
            const SizedBox(height: 18),
            Text(
              s.spaces,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
            _NavRow(
              label: s.spaces,
              icon: CupertinoIcons.square_stack_3d_up,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => const SpacesView(),
                ),
              ),
            ),

            // ── Tab Bar ─────────────────────────────────────────────────
            const SizedBox(height: 18),
            Text(
              s.sectionCustomization,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
            _NavRow(
              label: s.tabBar,
              icon: CupertinoIcons.rectangle_grid_1x2,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => TabBarSettingsView(
                    controller: widget.controller,
                  ),
                ),
              ),
            ),

            // ── Startup ─────────────────────────────────────────────────
            // Surfaced at the top level (not buried inside Tab Bar) so the
            // setting that controls "which tab opens on app launch" is easy
            // to find — discoverability complaint from real users.
            const SizedBox(height: 18),
            Text(
              s.startup,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (ctx, _) {
                return _NavRow(
                  label: s.defaultTab,
                  icon: CupertinoIcons.app_badge,
                  trailingLabel: defaultTabLabel(
                      s, widget.controller),
                  onTap: () =>
                      showDefaultTabPicker(context, widget.controller),
                );
              },
            ),

            // ── Notifications ────────────────────────────────────────
            const SizedBox(height: 18),
            Text(
              s.sectionNotifications,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
            _NavRow(
              label: s.sectionNotifications,
              icon: CupertinoIcons.bell,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => const NotificationsSettingsView(),
                ),
              ),
            ),

            // ── Security ─────────────────────────────────────────────
            if (widget.securityService != null) ...[
              const SizedBox(height: 18),
              Text(
                s.sectionSecurity,
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 6),
              _NavRow(
                label: s.sectionSecurity,
                icon: CupertinoIcons.lock,
                onTap: () => Navigator.of(context).push(
                  FastRoute<void>(
                    builder: (_) => SecuritySettingsView(
                      securityService: widget.securityService!,
                    ),
                  ),
                ),
              ),
            ],

            // ── Integrations ──────────────────────────────────────
            if (widget.googleCalendarController != null) ...[
              const SizedBox(height: 18),
              Text(
                s.sectionIntegrations,
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 6),
              ListenableBuilder(
                listenable: widget.googleCalendarController!,
                builder: (ctx, _) {
                  final gc = widget.googleCalendarController!;
                  final trailing = gc.isConnected
                      ? (gc.email ?? s.googleCalendarOn)
                      : s.googleCalendarOff;
                  return _NavRow(
                    label: s.googleCalendar,
                    icon: CupertinoIcons.calendar_badge_plus,
                    trailingLabel: trailing,
                    onTap: () => Navigator.of(context).push(
                      FastRoute<void>(
                        builder: (_) => GoogleCalendarSettingsView(
                          controller: gc,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],

            if (hasBackup) ...[
              // ── Sync ──────────────────────────────────────────────
              const SizedBox(height: 18),
              Text(
                s.sync,
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 6),
              _NavRow(
                label: s.sync,
                icon: CupertinoIcons.arrow_2_circlepath,
                onTap: () {
                  final syncController =
                      SpaceManagerProvider.of(context).syncController;
                  Navigator.of(context).push(
                    FastRoute<void>(
                      builder: (_) =>
                          SyncSettingsView(controller: syncController),
                    ),
                  );
                },
              ),

              // ── Data ──────────────────────────────────────────────
              const SizedBox(height: 18),
              Text(
                s.sectionData,
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 6),
              _NavRow(
                label: s.sectionData,
                icon: CupertinoIcons.archivebox,
                onTap: () => Navigator.of(context).push(
                  FastRoute<void>(
                    builder: (_) => DataView(
                      backupService: widget.backupService!,
                      securityService: widget.securityService,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tab Bar settings sub-page ────────────────────────────────────────────────

String _tabLabel(S s, int tabIndex) {
  switch (tabIndex) {
    case 0: return s.tabTasks;
    case 1: return s.tabNotes;
    case 2: return s.tabCalendar;
    case 3: return s.tabRoutines;
    case 4: return s.tabSettings;
    default: return '';
  }
}

/// Human-readable label for the controller's current default-tab value.
/// Exposed so both the top-level Settings row and the Tab Bar sub-page can
/// share one source of truth.
String defaultTabLabel(S s, SettingsController controller) {
  final value = controller.defaultTab;
  if (value == kLastOpenedTab) return s.lastOpenedTab;
  return _tabLabel(s, int.tryParse(value) ?? 0);
}

/// Opens the picker that lets the user pick the tab shown on app launch.
Future<void> showDefaultTabPicker(
    BuildContext context, SettingsController controller) async {
  final s = S.of(context);
  final visible =
      controller.tabOrder.where(controller.isTabVisible).toList();
  final selected = await showSelectionMenu<String>(
    context: context,
    title: s.defaultTab,
    current: controller.defaultTab,
    options: [
      SelectionMenuOption(value: kLastOpenedTab, label: s.lastOpenedTab),
      for (final i in visible)
        SelectionMenuOption(value: i.toString(), label: _tabLabel(s, i)),
    ],
  );
  if (selected != null) controller.updateDefaultTab(selected);
}

class TabBarSettingsView extends StatelessWidget {
  const TabBarSettingsView({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabBar),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (ctx, _) {
            final visibleCount = controller.visibleOptionalTabCount;
            final settingsVisible = controller.isTabVisible(4);
            final tabOrder = controller.tabOrder;

            bool isDisabled(int tabIndex) =>
                visibleCount == 1 && controller.isTabVisible(tabIndex);

            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Display ────────────────────────────────────────────
                  Text(
                    s.display,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ToggleRow(
                    label: s.hideLabels,
                    value: controller.hideTabLabels,
                    onChanged: controller.updateHideTabLabels,
                  ),
                  const SizedBox(height: 18),
                  // ── Startup ────────────────────────────────────────────
                  Text(
                    s.startup,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _NavRow(
                    label: s.defaultTab,
                    trailingLabel: defaultTabLabel(s, controller),
                    onTap: () => showDefaultTabPicker(context, controller),
                  ),
                  const SizedBox(height: 18),
                  // ── Visible Tabs (reorderable) ─────────────────────────
                  Text(
                    s.visibleTabs,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      final newOrder = List.of(tabOrder);
                      if (newIndex > oldIndex) newIndex--;
                      final item = newOrder.removeAt(oldIndex);
                      newOrder.insert(newIndex, item);
                      controller.updateTabOrder(newOrder);
                    },
                    children: [
                      for (int i = 0; i < tabOrder.length; i++)
                        _TabOrderRow(
                          key: ValueKey(tabOrder[i]),
                          index: i,
                          label: _tabLabel(s, tabOrder[i]),
                          isVisible: controller.isTabVisible(tabOrder[i]),
                          isDisabled: isDisabled(tabOrder[i]),
                          onVisibilityChanged: (v) =>
                              controller.setTabVisible(tabOrder[i], v),
                        ),
                    ],
                  ),
                  if (!settingsVisible) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        s.settingsAccessibleHint,
                        style: TextStyle(fontSize: 13, color: labelColor),
                      ),
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

// ── Tab order row ─────────────────────────────────────────────────────────────

class _TabOrderRow extends StatelessWidget {
  const _TabOrderRow({
    super.key,
    required this.index,
    required this.label,
    required this.isVisible,
    required this.isDisabled,
    required this.onVisibilityChanged,
  });

  final int index;
  final String label;
  final bool isVisible;
  final bool isDisabled;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            CupertinoSwitch(
              value: isVisible,
              onChanged: isDisabled ? null : onVisibilityChanged,
              activeColor: AppColors.accent,
            ),
            const SizedBox(width: 12),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                size: 20,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared row widgets ────────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.onTap,
    this.trailingLabel,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final String? trailingLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            if (trailingLabel != null) ...[
              Text(
                trailingLabel!,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            CupertinoSwitch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

