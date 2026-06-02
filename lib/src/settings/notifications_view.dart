import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../notifications/notification_service.dart';
import '../spaces/space_manager.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import '../utils/platform_capabilities.dart';
import '../utils/selection_menu.dart';
import 'badge_sources_view.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

class NotificationsSettingsView extends StatefulWidget {
  const NotificationsSettingsView({super.key, this.settingsController});

  final SettingsController? settingsController;

  @override
  State<NotificationsSettingsView> createState() =>
      _NotificationsSettingsViewState();
}

class _NotificationsSettingsViewState
    extends State<NotificationsSettingsView> {
  bool? _permissionGranted;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _checking = true);
    final granted = await NotificationService.instance.checkPermission();
    if (mounted) setState(() { _permissionGranted = granted; _checking = false; });
  }

  Future<void> _requestPermission() async {
    setState(() => _checking = true);
    final granted = await NotificationService.instance.requestPermission();
    if (mounted) setState(() { _permissionGranted = granted; _checking = false; });
    if (!granted && mounted) {
      _showPermissionHint();
    }
  }

  void _showPermissionHint() {
    final s = S.of(context);
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.sectionNotifications),
        content: Text(s.notificationsPermissionHint),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);

    final granted = _permissionGranted ?? false;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.sectionNotifications),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            Text(
              s.sectionNotifications,
              style: TextStyle(
                  fontSize: 13, color: labelColor, letterSpacing: -0.08),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.notificationsEnabled,
                        style: const TextStyle(fontSize: 17)),
                  ),
                  if (_checking)
                    const CupertinoActivityIndicator()
                  else
                    CupertinoSwitch(
                      value: granted,
                      onChanged: granted ? null : (_) => _requestPermission(),
                      activeColor: AppColors.accent,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                granted
                    ? 'Notifications are enabled. You can set reminders on tasks and events.'
                    : s.notificationsPermissionHint,
                style: TextStyle(fontSize: 13, color: labelColor),
              ),
            ),

            // ── App icon badge ─────────────────────────────────────────
            if (PlatformCapabilities.supportsAppBadge &&
                widget.settingsController != null) ...[
              const SizedBox(height: 24),
              Text(
                s.appBadge,
                style: TextStyle(
                    fontSize: 13, color: labelColor, letterSpacing: -0.08),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: widget.settingsController!,
                builder: (ctx, _) {
                  final sc = widget.settingsController!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsNavRow(
                        label: s.appBadgeMode,
                        trailingLabel: _badgeModeLabel(s, sc.badgeMode),
                        onTap: () => _pickBadgeMode(ctx, sc),
                      ),
                      if (sc.badgeMode == BadgeMode.custom) ...[
                        const SizedBox(height: 1),
                        SettingsNavRow(
                          label: s.appBadgeSources,
                          trailingLabel: sc.badgeCustomSources.isEmpty
                              ? s.defaultListNone
                              : '${sc.badgeCustomSources.length}',
                          onTap: () => _openBadgeSources(ctx, sc),
                        ),
                      ],
                      const SizedBox(height: 1),
                      SettingsToggleRow(
                        label: s.appBadgeIncludeRoutines,
                        value: sc.badgeIncludeRoutines,
                        enabled: sc.badgeMode != BadgeMode.none,
                        onChanged: sc.updateBadgeIncludeRoutines,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  s.appBadgeHint,
                  style: TextStyle(fontSize: 13, color: labelColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _badgeModeLabel(S s, BadgeMode m) {
    switch (m) {
      case BadgeMode.none:
        return s.appBadgeNone;
      case BadgeMode.todayTasks:
        return s.appBadgeTodayTasks;
      case BadgeMode.todayTasksAndEvents:
        return s.appBadgeTodayTasksAndEvents;
      case BadgeMode.inboxTasks:
        return s.appBadgeInbox;
      case BadgeMode.allUncompleted:
        return s.appBadgeAllUncompleted;
      case BadgeMode.custom:
        return s.appBadgeCustom;
    }
  }

  void _openBadgeSources(BuildContext context, SettingsController sc) {
    final folderController = SpaceManagerProvider.of(context).folderController;
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => BadgeSourcesView(
          settingsController: sc,
          folderController: folderController,
        ),
      ),
    );
  }

  Future<void> _pickBadgeMode(
      BuildContext context, SettingsController sc) async {
    final s = S.of(context);
    final selected = await showSelectionMenu<BadgeMode>(
      context: context,
      title: s.appBadgeMode,
      current: sc.badgeMode,
      options: BadgeMode.values
          .map((m) => SelectionMenuOption(
                value: m,
                label: _badgeModeLabel(s, m),
              ))
          .toList(),
    );
    if (selected != null) await sc.updateBadgeMode(selected);
  }
}
