import 'package:flutter/cupertino.dart';

import '../integrations/apple/device_calendar_controller.dart';
import '../integrations/apple/device_event.dart';
import '../integrations/apple/eventkit_service.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../utils/platform_capabilities.dart';
import '../utils/selection_menu.dart';

/// Connect / manage screen for the native Apple Calendar (EventKit)
/// integration. Mirrors `GoogleCalendarSettingsView` but for a single device
/// store: request access, toggle which device calendars show, pick a default
/// calendar for new events, sync now, and view the last-synced time.
class DeviceCalendarSettingsView extends StatelessWidget {
  const DeviceCalendarSettingsView({super.key, required this.controller});

  final DeviceCalendarController controller;

  Future<void> _pickDefault(BuildContext context) async {
    final s = S.of(context);
    final cals = controller.writableSelectedCalendars;
    if (cals.isEmpty) return;
    final options = <SelectionMenuOption<String>>[
      SelectionMenuOption(value: _localContainerKey, label: s.planomLocal),
      for (final c in cals)
        SelectionMenuOption(value: c.id, label: c.title),
    ];
    final pick = await showSelectionMenu<String>(
      context: context,
      title: s.appleCalendarDefault,
      current: controller.defaultCalendar?.id ?? _localContainerKey,
      options: options,
    );
    if (pick == null) return;
    if (pick == _localContainerKey) {
      await controller.clearDefaultCalendar();
      return;
    }
    final match = cals.where((c) => c.id == pick).toList();
    if (match.isNotEmpty) await controller.setDefaultCalendar(match.first);
  }

  static const String _localContainerKey = '__planom_local__';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.appleCalendar),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (ctx, _) {
            if (!PlatformCapabilities.supportsEventKit) {
              return _Message(message: s.appleCalendarNotAvailable);
            }

            final status = controller.authorizationStatus;
            // Permanently denied / restricted: the OS won't re-prompt, so point
            // the user at system Settings.
            if (status == EventKitAuthStatus.denied ||
                status == EventKitAuthStatus.restricted) {
              return _Message(message: s.appleCalendarAccessDenied);
            }

            if (!controller.isAuthorized) {
              return ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      s.appleCalendarConnectDesc,
                      style: TextStyle(fontSize: 14, color: labelColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionRow(
                    label: s.appleCalendarConnect,
                    trailing: controller.isLoading
                        ? const CupertinoActivityIndicator()
                        : Icon(CupertinoIcons.calendar_badge_plus,
                            color: AppColors.accent, size: 20),
                    onTap: controller.isLoading
                        ? null
                        : () => controller.connect(),
                  ),
                  if (controller.lastError != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(text: controller.lastError!),
                  ],
                ],
              );
            }

            final cals = controller.availableCalendars;
            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                Text(
                  s.appleCalendarCalendarsSection,
                  style: TextStyle(
                      fontSize: 13, color: labelColor, letterSpacing: -0.08),
                ),
                const SizedBox(height: 6),
                if (cals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(s.appleCalendarNoCalendars,
                        style: TextStyle(fontSize: 13, color: labelColor)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoDynamicColor.resolve(
                          CupertinoColors.tertiarySystemBackground, context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < cals.length; i++) ...[
                          if (i > 0) const SizedBox(height: 4),
                          _CalendarRow(
                            calendar: cals[i],
                            selected: controller.isCalendarSelected(cals[i]),
                            isDefault:
                                controller.defaultCalendar?.id == cals[i].id,
                            onToggle: (v) =>
                                controller.setCalendarSelected(cals[i], v),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  s.appleCalendarDefaultSection,
                  style: TextStyle(
                      fontSize: 13, color: labelColor, letterSpacing: -0.08),
                ),
                const SizedBox(height: 6),
                _NavRow(
                  label: s.appleCalendarDefault,
                  trailingLabel:
                      controller.defaultCalendar?.title ?? s.planomLocal,
                  onTap: () => _pickDefault(context),
                ),
                const SizedBox(height: 18),
                Text(
                  s.appleCalendarSyncSection,
                  style: TextStyle(
                      fontSize: 13, color: labelColor, letterSpacing: -0.08),
                ),
                const SizedBox(height: 6),
                _ActionRow(
                  label: s.appleCalendarSyncNow,
                  trailing: controller.isLoading
                      ? const CupertinoActivityIndicator()
                      : Icon(CupertinoIcons.arrow_clockwise,
                          color: AppColors.accent, size: 18),
                  onTap:
                      controller.isLoading ? null : () => controller.refresh(),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    controller.lastSyncAt == null
                        ? s.appleCalendarNeverSynced
                        : s.appleCalendarLastSynced.replaceFirst(
                            '{when}', _formatLastSync(controller.lastSyncAt!)),
                    style: TextStyle(fontSize: 13, color: labelColor),
                  ),
                ),
                const SizedBox(height: 18),
                _ActionRow(
                  label: s.appleCalendarDisconnect,
                  trailing: const Icon(CupertinoIcons.minus_circle,
                      color: CupertinoColors.destructiveRed, size: 20),
                  onTap:
                      controller.isLoading ? null : () => controller.disconnect(),
                ),
                if (controller.lastError != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(text: controller.lastError!),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatLastSync(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}

// ─── Pieces ───────────────────────────────────────────────────────────────────

class _Message extends StatelessWidget {
  const _Message({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle,
              size: 32, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({
    required this.calendar,
    required this.selected,
    required this.isDefault,
    required this.onToggle,
  });

  final DeviceCalendarMeta calendar;
  final bool selected;
  final bool isDefault;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: Color(calendar.color), shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(calendar.title,
                  style: const TextStyle(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (isDefault ||
                  !calendar.canWrite ||
                  calendar.sourceTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (calendar.sourceTitle.isNotEmpty) calendar.sourceTitle,
                      if (isDefault) s.appleCalendarDefaultBadge,
                      if (!calendar.canWrite) s.appleCalendarReadOnly,
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context)),
                  ),
                ),
            ],
          ),
        ),
        CupertinoSwitch(
          value: selected,
          onChanged: onToggle,
          activeColor: AppColors.accent,
        ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap, this.trailingLabel});

  final String label;
  final VoidCallback onTap;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 17,
                      color: CupertinoColors.label.resolveFrom(context))),
            ),
            if (trailingLabel != null) ...[
              Text(trailingLabel!,
                  style: TextStyle(
                      fontSize: 15,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context))),
              const SizedBox(width: 4),
            ],
            Icon(CupertinoIcons.chevron_right,
                size: 16,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow(
      {required this.label, required this.trailing, required this.onTap});

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 17,
                      color: CupertinoColors.label.resolveFrom(context))),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CupertinoColors.systemRed.withOpacity(0.3)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, color: CupertinoColors.systemRed)),
    );
  }
}
