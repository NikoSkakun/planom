import 'package:flutter/cupertino.dart';

import '../integrations/google/google_calendar_controller.dart';
import '../integrations/google/oauth_config.dart';
import '../integrations/google/remote_event.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';

class GoogleCalendarSettingsView extends StatelessWidget {
  const GoogleCalendarSettingsView({super.key, required this.controller});

  final GoogleCalendarController controller;

  Future<void> _connect(BuildContext context) async {
    await controller.connect();
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    final s = S.of(context);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.googleCalendarDisconnect),
        content: Text(s.googleCalendarDisconnectBody),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.googleCalendarDisconnect),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (ok == true) await controller.disconnect();
  }

  Future<void> _pickDefault(BuildContext context) async {
    final s = S.of(context);
    final options = controller.writableSelectedCalendars
        .map((c) => SelectionMenuOption(
              value: c.id,
              label: c.summary,
            ))
        .toList();
    if (options.isEmpty) return;
    final pick = await showSelectionMenu<String>(
      context: context,
      title: s.googleCalendarDefault,
      current: controller.defaultCalendarId,
      options: options,
    );
    if (pick != null) await controller.setDefaultCalendar(pick);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.googleCalendar),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (ctx, _) {
            if (!isGoogleSignInConfigured) {
              return _SetupRequired(message: s.googleCalendarSetupRequired);
            }

            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _StatusBlock(
                  controller: controller,
                  onConnect: () => _connect(context),
                  onDisconnect: () => _confirmDisconnect(context),
                ),

                if (controller.isConnected) ...[
                  const SizedBox(height: 18),
                  Text(
                    s.googleCalendarCalendarsSection,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (controller.availableCalendars.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: Text(
                        s.googleCalendarNoCalendars,
                        style: TextStyle(fontSize: 14, color: labelColor),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final cal in controller.availableCalendars)
                          _CalendarRow(
                            calendar: cal,
                            selected: controller
                                .selectedCalendarIds
                                .contains(cal.id),
                            isDefault:
                                controller.defaultCalendarId == cal.id,
                            onToggle: (v) {
                              final next =
                                  Set<String>.of(controller.selectedCalendarIds);
                              if (v) {
                                next.add(cal.id);
                              } else {
                                next.remove(cal.id);
                                if (controller.defaultCalendarId == cal.id) {
                                  // Default got deselected — clear it; the
                                  // user can pick a new one below.
                                  controller.setDefaultCalendar('');
                                }
                              }
                              controller.setSelectedCalendars(next);
                            },
                          ),
                      ],
                    ),

                  const SizedBox(height: 18),
                  Text(
                    s.googleCalendarDefaultSection,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _NavRow(
                    label: s.googleCalendarDefault,
                    trailingLabel: _defaultLabel(controller, s),
                    onTap: () => _pickDefault(context),
                  ),

                  const SizedBox(height: 18),
                  Text(
                    s.googleCalendarSyncSection,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ActionRow(
                    label: s.googleCalendarSyncNow,
                    trailing: controller.isLoading
                        ? const CupertinoActivityIndicator()
                        : Icon(
                            CupertinoIcons.arrow_clockwise,
                            color: AppColors.accent,
                            size: 18,
                          ),
                    onTap: controller.isLoading
                        ? null
                        : () => controller.refresh(),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      controller.lastSyncAt == null
                          ? s.googleCalendarNeverSynced
                          : s.googleCalendarLastSynced
                              .replaceFirst('{when}',
                                  _formatLastSync(controller.lastSyncAt!)),
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                  ),

                  if (controller.lastError != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(text: controller.lastError!),
                  ],

                  const SizedBox(height: 24),
                  _DestructiveButton(
                    label: s.googleCalendarDisconnect,
                    onPressed: () => _confirmDisconnect(context),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _defaultLabel(GoogleCalendarController c, S s) {
    final id = c.defaultCalendarId;
    if (id == null || id.isEmpty) return s.googleCalendarNoDefault;
    for (final cal in c.availableCalendars) {
      if (cal.id == id) return cal.summary;
    }
    return s.googleCalendarNoDefault;
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

class _SetupRequired extends StatelessWidget {
  const _SetupRequired({required this.message});
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
          Text(
            message,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.controller,
    required this.onConnect,
    required this.onDisconnect,
  });

  final GoogleCalendarController controller;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );

    if (controller.isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.checkmark_alt,
                size: 18,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.googleCalendarConnected,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (controller.email != null)
                    Text(
                      controller.email!,
                      style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return CupertinoButton.filled(
      onPressed: controller.isLoading ? null : onConnect,
      child: controller.isLoading
          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
          : Text(s.googleCalendarConnect),
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

  final GoogleCalendarMeta calendar;
  final bool selected;
  final bool isDefault;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(calendar.color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  calendar.summary,
                  style: const TextStyle(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isDefault || !calendar.canWrite || calendar.primary)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (calendar.primary) s.googleCalendarPrimary,
                        if (isDefault) s.googleCalendarDefaultBadge,
                        if (!calendar.canWrite) s.googleCalendarReadOnly,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
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
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.onTap,
    this.trailingLabel,
  });

  final String label;
  final VoidCallback onTap;
  final String? trailingLabel;

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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        border: Border.all(
          color: CupertinoColors.systemRed.withOpacity(0.3),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: CupertinoColors.systemRed,
        ),
      ),
    );
  }
}

class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(color: CupertinoColors.destructiveRed),
        ),
      ),
    );
  }
}
