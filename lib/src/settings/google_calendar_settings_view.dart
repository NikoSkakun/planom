import 'package:flutter/cupertino.dart';

import '../integrations/google/google_account.dart';
import '../integrations/google/google_calendar_controller.dart';
import '../integrations/google/oauth_config.dart';
import '../integrations/google/remote_event.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';

class GoogleCalendarSettingsView extends StatelessWidget {
  const GoogleCalendarSettingsView({super.key, required this.controller});

  final GoogleCalendarController controller;

  Future<void> _addAccount(BuildContext context) async {
    final s = S.of(context);
    final mode = await showSelectionMenu<bool>(
      context: context,
      title: s.googleCalendarChooseMode,
      options: [
        SelectionMenuOption(
          value: false,
          label: '${s.googleCalendarReadWrite} — ${s.googleCalendarReadWriteDesc}',
        ),
        SelectionMenuOption(
          value: true,
          label: '${s.googleCalendarReadOnlyMode} — ${s.googleCalendarReadOnlyDesc}',
        ),
      ],
    );
    if (mode == null) return;
    await controller.addAccount(readOnly: mode);
  }

  Future<void> _confirmRemove(
      BuildContext context, GoogleAccount account) async {
    final s = S.of(context);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(account.email),
        content: Text(s.googleCalendarRemoveAccountBody),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.googleCalendarRemoveAccount),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (ok == true) await controller.removeAccount(account);
  }

  Future<void> _pickDefault(BuildContext context) async {
    final s = S.of(context);
    final cals = controller.writableSelectedCalendars;
    if (cals.isEmpty) return;
    final multiAccount = controller.accountCount > 1;
    final options = cals
        .map((c) => SelectionMenuOption(
              value: c.key,
              label: multiAccount ? '${c.summary} · ${c.accountId}' : c.summary,
            ))
        .toList();
    final pick = await showSelectionMenu<String>(
      context: context,
      title: s.googleCalendarDefault,
      current: controller.defaultCalendar?.key,
      options: options,
    );
    if (pick == null) return;
    final match = cals.where((c) => c.key == pick).toList();
    if (match.isNotEmpty) await controller.setDefaultCalendar(match.first);
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
                Text(
                  s.googleCalendarAccountsSection,
                  style: TextStyle(
                      fontSize: 13, color: labelColor, letterSpacing: -0.08),
                ),
                const SizedBox(height: 6),
                for (final account in controller.accounts) ...[
                  _AccountCard(
                    controller: controller,
                    account: account,
                    onRemove: () => _confirmRemove(context, account),
                  ),
                  const SizedBox(height: 12),
                ],
                _ActionRow(
                  label: s.googleCalendarAddAccount,
                  trailing: controller.isLoading
                      ? const CupertinoActivityIndicator()
                      : Icon(CupertinoIcons.add_circled,
                          color: AppColors.accent, size: 20),
                  onTap: controller.isLoading
                      ? null
                      : () => _addAccount(context),
                ),
                if (controller.isConnected) ...[
                  const SizedBox(height: 18),
                  Text(
                    s.googleCalendarDefaultSection,
                    style: TextStyle(
                        fontSize: 13,
                        color: labelColor,
                        letterSpacing: -0.08),
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
                        letterSpacing: -0.08),
                  ),
                  const SizedBox(height: 6),
                  _ActionRow(
                    label: s.googleCalendarSyncNow,
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
                          ? s.googleCalendarNeverSynced
                          : s.googleCalendarLastSynced.replaceFirst(
                              '{when}', _formatLastSync(controller.lastSyncAt!)),
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                  ),
                ],
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

  String _defaultLabel(GoogleCalendarController c, S s) {
    final def = c.defaultCalendar;
    return def?.summary ?? s.googleCalendarNoDefault;
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
          Text(message, style: const TextStyle(fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.controller,
    required this.account,
    required this.onRemove,
  });

  final GoogleCalendarController controller;
  final GoogleAccount account;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final cals = controller.calendarsForAccount(account.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.person_fill,
                    size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.email,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      account.readOnly
                          ? s.googleCalendarReadOnlyMode
                          : s.googleCalendarReadWrite,
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 32,
                onPressed: onRemove,
                child: const Icon(CupertinoIcons.minus_circle,
                    size: 22, color: CupertinoColors.destructiveRed),
              ),
            ],
          ),
          if (cals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(s.googleCalendarNoCalendars,
                  style: TextStyle(fontSize: 13, color: secondary)),
            )
          else
            ...cals.map((cal) => _CalendarRow(
                  calendar: cal,
                  selected: controller.isCalendarSelected(cal),
                  isDefault: controller.defaultCalendar?.key == cal.key,
                  onToggle: (v) => controller.setCalendarSelected(cal, v),
                )),
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

  final GoogleCalendarMeta calendar;
  final bool selected;
  final bool isDefault;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
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
                Text(calendar.summary,
                    style: const TextStyle(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
      ),
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
