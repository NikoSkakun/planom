import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;

import 'package:flutter/material.dart' show ThemeMode;

import '../integrations/apple/device_calendar_controller.dart';
import '../integrations/google/google_calendar_controller.dart';
import '../localization/strings.dart';
import '../security/security_service.dart';
import '../spaces/space_manager.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'about_legal_view.dart';
import 'appearance_view.dart';
import 'backup_service.dart';
import 'data_view.dart';
import 'finance_settings_view.dart';
import '../utils/platform_capabilities.dart';
import 'device_calendar_settings_view.dart';
import 'google_calendar_settings_view.dart';
import 'module_settings_views.dart';
import 'notifications_view.dart';
import 'plus_button_settings_view.dart';
import 'security_view.dart';
import 'settings_controller.dart';
import 'spaces_view.dart';
import 'split_screen_settings_view.dart';
// import 'sync_settings_view.dart'; // Hidden until Sync feature is ready.
import 'tab_bar_pages_view.dart';
import 'tasks_settings_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.controller,
    this.backupService,
    this.securityService,
    this.googleCalendarController,
    this.deviceCalendarController,
    this.onClose,
    this.showCloseButton,
  });

  final SettingsController controller;
  final BackupService? backupService;
  final SecurityService? securityService;
  final GoogleCalendarController? googleCalendarController;
  final DeviceCalendarController? deviceCalendarController;

  /// Called to leave Settings when it's shown as the global overlay (the
  /// Settings tab is hidden). Null when Settings is a normal tab — then the
  /// view has no leading button.
  final VoidCallback? onClose;

  /// Drives whether the leading close button is shown. Reactive so the same
  /// (reparented) SettingsView gains/loses the button as the overlay opens
  /// and closes. Null → never show it.
  final ValueListenable<bool>? showCloseButton;

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
      options: (kSupportedLocales
          .map((loc) => SelectionMenuOption(
                value: loc.languageCode,
                label: kLanguageNames[loc.languageCode] ?? loc.languageCode,
              ))
          .toList()
        ..sort((a, b) =>
            a.label.toLowerCase().compareTo(b.label.toLowerCase()))),
    );
    if (selected != null) {
      widget.controller.updateLocale(Locale(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hasBackup = widget.backupService != null;

    final closeListenable = widget.showCloseButton;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        // Zero the leading inset: CupertinoNavigationBar pads a *custom*
        // leading by an extra 16 px that the auto-implied back button never
        // gets, which pushed our close chevron one button-width to the right
        // of every other screen's back button. With start:0 the custom
        // CupertinoNavigationBarBackButton lines up exactly with the native
        // one. (end is unused — this page has no trailing.)
        padding: const EdgeInsetsDirectional.only(start: 0),
        middle: Text(s.settings),
        // When shown as the global overlay (Settings tab hidden), the root
        // page has no route to pop back to, so it exposes its own close
        // button that returns to the underlying tab. Reactive so the
        // reparented view shows/hides it as the overlay opens/closes.
        leading: closeListenable == null
            ? null
            : ValueListenableBuilder<bool>(
                valueListenable: closeListenable,
                builder: (context, show, _) {
                  if (!show || widget.onClose == null) {
                    return const SizedBox.shrink();
                  }
                  // Native back button (standard chevron + alignment); the
                  // custom onPressed leaves the overlay instead of popping.
                  return CupertinoNavigationBarBackButton(
                    onPressed: widget.onClose,
                  );
                },
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // ── Appearance ──────────────────────────────────────────────
            _SectionHeader(s.sectionAppearance),
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
            _SectionHeader(s.sectionLanguage),
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

            // ── Modules ─────────────────────────────────────────────────
            const SizedBox(height: 18),
            _SectionHeader(s.sectionModules),
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
                  builder: (_) => CalendarSettingsView(
                    controller: widget.controller,
                    googleCalendarController: widget.googleCalendarController,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 1),
            _NavRow(
              label: s.tabRoutines,
              icon: CupertinoIcons.repeat,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => RoutinesSettingsView(
                    controller: widget.controller,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 1),
            _NavRow(
              label: s.tabFinance,
              icon: CupertinoIcons.money_dollar_circle,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => FinanceSettingsView(
                    controller: widget.controller,
                  ),
                ),
              ),
            ),

            // ── Spaces ──────────────────────────────────────────────────
            const SizedBox(height: 18),
            _SectionHeader(s.spaces),
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
            _SectionHeader(s.sectionCustomization),
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
            const SizedBox(height: 1),
            _NavRow(
              label: s.plusButton,
              icon: CupertinoIcons.add_circled,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => PlusButtonSettingsView(
                    controller: widget.controller,
                    googleCalendarController: widget.googleCalendarController,
                  ),
                ),
              ),
            ),

            // ── Notifications ────────────────────────────────────────
            const SizedBox(height: 18),
            _SectionHeader(s.sectionNotifications),
            _NavRow(
              label: s.sectionNotifications,
              icon: CupertinoIcons.bell,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => NotificationsSettingsView(
                    settingsController: widget.controller,
                  ),
                ),
              ),
            ),

            // ── Security ─────────────────────────────────────────────
            if (widget.securityService != null) ...[
              const SizedBox(height: 18),
              _SectionHeader(s.sectionSecurity),
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
            if (widget.googleCalendarController != null ||
                (widget.deviceCalendarController != null &&
                    PlatformCapabilities.supportsEventKit)) ...[
              const SizedBox(height: 18),
              _SectionHeader(s.sectionIntegrations),
              if (widget.googleCalendarController != null)
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
              if (widget.deviceCalendarController != null &&
                  PlatformCapabilities.supportsEventKit)
                ListenableBuilder(
                  listenable: widget.deviceCalendarController!,
                  builder: (ctx, _) {
                    final ek = widget.deviceCalendarController!;
                    final trailing = ek.isConnected
                        ? s.appleCalendarOn
                        : s.appleCalendarOff;
                    return _NavRow(
                      label: s.appleCalendar,
                      icon: CupertinoIcons.calendar_today,
                      trailingLabel: trailing,
                      onTap: () => Navigator.of(context).push(
                        FastRoute<void>(
                          builder: (_) => DeviceCalendarSettingsView(
                            controller: ek,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],

            if (hasBackup) ...[
              // ── Sync ──────────────────────────────────────────────
              // Hidden until the Sync feature is ready. Restore this block
              // (and the `sync_settings_view.dart` import) to re-enable it.
              // const SizedBox(height: 18),
              // _SectionHeader(s.sync),
              // _NavRow(
              //   label: s.sync,
              //   icon: CupertinoIcons.arrow_2_circlepath,
              //   onTap: () {
              //     final syncController =
              //         SpaceManagerProvider.of(context).syncController;
              //     Navigator.of(context).push(
              //       FastRoute<void>(
              //         builder: (_) =>
              //             SyncSettingsView(controller: syncController),
              //       ),
              //     );
              //   },
              // ),

              // ── Data ──────────────────────────────────────────────
              const SizedBox(height: 18),
              _SectionHeader(s.sectionData),
              _NavRow(
                label: s.sectionData,
                icon: CupertinoIcons.archivebox,
                onTap: () => Navigator.of(context).push(
                  FastRoute<void>(
                    builder: (_) => DataView(
                      backupService: widget.backupService!,
                      spaceManager: SpaceManagerProvider.of(context),
                      securityService: widget.securityService,
                    ),
                  ),
                ),
              ),
            ],

            // ── Advanced ────────────────────────────────────────────────
            const SizedBox(height: 18),
            _SectionHeader(s.sectionAdvanced),
            _NavRow(
              label: s.splitScreen,
              icon: CupertinoIcons.rectangle_grid_1x2,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => SplitScreenSettingsView(
                    controller: widget.controller,
                  ),
                ),
              ),
            ),

            // ── About ─────────────────────────────────────────────────
            const SizedBox(height: 18),
            _SectionHeader(s.sectionAbout),
            _NavRow(
              label: s.sectionAbout,
              icon: CupertinoIcons.info_circle,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => const AboutLegalView(),
                ),
              ),
            ),
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
    case 5: return s.tabFinance;
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
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Display ────────────────────────────────────────────
                  _SectionHeader(s.display),
                  _ToggleRow(
                    label: s.showLabels,
                    value: controller.showTabLabels,
                    onChanged: controller.updateShowTabLabels,
                  ),
                  const SizedBox(height: 18),
                  // ── Startup ────────────────────────────────────────────
                  _SectionHeader(s.startup),
                  _NavRow(
                    label: s.defaultTab,
                    trailingLabel: defaultTabLabel(s, controller),
                    onTap: () => showDefaultTabPicker(context, controller),
                  ),
                  const SizedBox(height: 18),
                  // ── Visible Tabs (page 1 + additional pages) ───────────
                  _SectionHeader(s.visibleTabs),
                  TabBarPagesEditor(controller: controller),
                  if (!controller.isTabVisible(4)) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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

// ── Shared row widgets ────────────────────────────────────────────────────────

/// Section header kept at the screen margin (horizontal 16) while the list
/// itself has no horizontal padding, so the full-width card rows below line
/// their text up with this header.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          letterSpacing: -0.08,
        ),
      ),
    );
  }
}

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
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return Container(
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
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

