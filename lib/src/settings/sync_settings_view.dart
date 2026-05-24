import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_state.dart';
import '../theme/app_theme.dart';

/// Settings → Sync sub-page. Lists every supported backend in tiered order
/// (free first, then paid) and exposes the operational controls (passphrase,
/// push, pull, disable) for whichever one is currently active.
class SyncSettingsView extends StatefulWidget {
  const SyncSettingsView({super.key, required this.controller});

  final SyncController controller;

  @override
  State<SyncSettingsView> createState() => _SyncSettingsViewState();
}

class _SyncSettingsViewState extends State<SyncSettingsView> {
  bool _busy = false;
  bool _hasPassphrase = false;

  @override
  void initState() {
    super.initState();
    widget.controller.hasPassphrase().then((v) {
      if (mounted) setState(() => _hasPassphrase = v);
    });
  }

  Future<void> _refreshPassphraseState() async {
    final has = await widget.controller.hasPassphrase();
    if (mounted) setState(() => _hasPassphrase = has);
  }

  Future<String?> _promptPassphrase({
    required String title,
    bool confirm = false,
  }) async {
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final s = S.of(context);
    String? result;
    String? error;

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => CupertinoAlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                s.syncPassphraseHint,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: ctrl,
                obscureText: true,
                autofocus: true,
                placeholder: s.enterPassphrase,
              ),
              if (confirm) ...[
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  placeholder: s.confirmPassword,
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(
                    color: CupertinoColors.destructiveRed,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.cancel),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final p = ctrl.text;
                if (p.isEmpty) {
                  setLocal(() => error = s.passwordRequired);
                  return;
                }
                if (confirm && p != confirmCtrl.text) {
                  setLocal(() => error = s.passwordsDoNotMatch);
                  return;
                }
                result = p;
                Navigator.of(ctx).pop();
              },
              child: Text(s.ok),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    confirmCtrl.dispose();
    return result;
  }

  Future<void> _enableICloud() async {
    // One-tap enable: don't gate on a passphrase. The default ships sync
    // using Apple's own encryption-at-rest. Users can add client-side E2E
    // later from the Encryption row below.
    await widget.controller.setBackend(SyncBackend.icloud);
  }

  Future<void> _setPassphrase() async {
    final s = S.of(context);
    final pass = await _promptPassphrase(
      title: s.setPassphrase,
      confirm: true,
    );
    if (pass == null) return;
    try {
      await widget.controller.setPassphrase(pass);
    } catch (e) {
      if (!mounted) return;
      _showAlert(s.exportFailed, e.toString());
      return;
    }
    await _refreshPassphraseState();
    if (!mounted) return;
    // Encrypt-and-replace the existing cloud copy so a fresh device pulling
    // tomorrow gets the new ciphertext, not the old plaintext.
    await widget.controller.pushNow();
  }

  Future<void> _removePassphrase() async {
    final s = S.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.removeEncryption),
        content: Text(s.removeEncryptionBody),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.clearPassphrase();
    await _refreshPassphraseState();
  }

  Future<void> _disable() async {
    final s = S.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.disableSync),
        content: Text(s.disableSyncBody),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    await widget.controller.disableAndWipeRemote();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pushNow() async {
    setState(() => _busy = true);
    await widget.controller.pushNow();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pullNow() async {
    final s = S.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.replaceAllData),
        content: Text(s.pullReplacesLocal),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    await widget.controller.pullNow();
    if (mounted) setState(() => _busy = false);
  }

  void _showAlert(String title, String body) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.of(context).ok),
          ),
        ],
      ),
    );
  }

  String _statusLabel(S s, SyncSnapshot snap) {
    switch (snap.status) {
      case SyncStatus.idle:
        return snap.lastSyncAt != null
            ? s.syncLastAt(_relative(snap.lastSyncAt!))
            : s.syncNever;
      case SyncStatus.pushing:
        return s.syncPushing;
      case SyncStatus.pulling:
        return s.syncPulling;
      case SyncStatus.succeeded:
        return s.syncSucceeded;
      case SyncStatus.failed:
        return snap.lastError ?? s.syncFailed;
      case SyncStatus.notConfigured:
        return s.syncNotConfigured;
      case SyncStatus.passphraseRequired:
        return s.syncPassphraseRequired;
      case SyncStatus.notAvailable:
        return s.syncNotAvailable;
    }
  }

  String _relative(DateTime when) {
    final delta = DateTime.now().difference(when);
    if (delta.inSeconds < 60) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final cardBg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.sync),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final snap = widget.controller.snapshot;
            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _SectionLabel(text: s.syncFreeSection, color: labelColor),
                _BackendCard(
                  bg: cardBg,
                  child: _BackendRow(
                    label: s.syncICloudTitle,
                    sublabel: s.syncICloudSublabel,
                    selected: snap.backend == SyncBackend.icloud,
                    tag: s.tagFree,
                    onTap: _busy ? null : _enableICloud,
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel(text: s.syncPaidSection, color: labelColor),
                _BackendCard(
                  bg: cardBg,
                  child: Column(
                    children: [
                      _BackendRow(
                        label: s.syncPlanomTitle,
                        sublabel: s.syncPlanomSublabel,
                        selected: snap.backend == SyncBackend.planom,
                        tag: s.tagComingSoon,
                        onTap: null,
                      ),
                      Container(
                        height: 0.5,
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                      _BackendRow(
                        label: s.syncCustomTitle,
                        sublabel: s.syncCustomSublabel,
                        selected: snap.backend == SyncBackend.custom,
                        tag: s.tagComingSoon,
                        onTap: null,
                      ),
                    ],
                  ),
                ),

                // Operational controls — only useful when a backend is active.
                if (snap.backend != SyncBackend.none) ...[
                  const SizedBox(height: 24),
                  _SectionLabel(text: s.syncStatusSection, color: labelColor),
                  _BackendCard(
                    bg: cardBg,
                    child: Column(
                      children: [
                        _InfoRow(
                          label: s.syncStatusLabel,
                          value: _statusLabel(s, snap),
                          showSpinner: snap.status == SyncStatus.pushing ||
                              snap.status == SyncStatus.pulling,
                        ),
                        Container(
                          height: 0.5,
                          color:
                              CupertinoColors.separator.resolveFrom(context),
                        ),
                        _TapRow(
                          label: s.syncNow,
                          onTap: _busy ? null : _pushNow,
                        ),
                        Container(
                          height: 0.5,
                          color:
                              CupertinoColors.separator.resolveFrom(context),
                        ),
                        _TapRow(
                          label: s.syncPullReplace,
                          onTap: _busy ? null : _pullNow,
                        ),
                        Container(
                          height: 0.5,
                          color:
                              CupertinoColors.separator.resolveFrom(context),
                        ),
                        _TapRow(
                          label: s.disableSync,
                          isDestructive: true,
                          onTap: _busy ? null : _disable,
                        ),
                      ],
                    ),
                  ),

                  // Encryption — separate section so it reads as an opt-in
                  // upgrade rather than a required setup step.
                  const SizedBox(height: 24),
                  _SectionLabel(
                      text: s.syncEncryptionSection, color: labelColor),
                  _BackendCard(
                    bg: cardBg,
                    child: Column(
                      children: [
                        _InfoRow(
                          label: s.syncEncryptionLabel,
                          value: _hasPassphrase
                              ? s.syncEncryptionOn
                              : s.syncEncryptionOff,
                        ),
                        Container(
                          height: 0.5,
                          color:
                              CupertinoColors.separator.resolveFrom(context),
                        ),
                        if (!_hasPassphrase)
                          _TapRow(
                            label: s.setPassphrase,
                            onTap: _busy ? null : _setPassphrase,
                          )
                        else
                          _TapRow(
                            label: s.removeEncryption,
                            isDestructive: true,
                            onTap: _busy ? null : _removePassphrase,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _hasPassphrase
                          ? s.syncPassphraseLossHint
                          : s.syncDefaultEncryptionHint,
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style:
              TextStyle(fontSize: 12, color: color, letterSpacing: 0.4),
        ),
      );
}

class _BackendCard extends StatelessWidget {
  const _BackendCard({required this.child, required this.bg});
  final Widget child;
  final Color bg;
  @override
  Widget build(BuildContext context) => Container(
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: child,
      );
}

class _BackendRow extends StatelessWidget {
  const _BackendRow({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.tag,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool selected;
  final String tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final labelColor = disabled
        ? CupertinoColors.tertiaryLabel.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(label,
                            style: TextStyle(fontSize: 16, color: labelColor)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(CupertinoIcons.checkmark,
                    color: AppColors.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label, required this.value, this.showSpinner = false});
  final String label;
  final String value;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          if (showSpinner)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: CupertinoActivityIndicator(radius: 9),
            ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow(
      {required this.label, required this.onTap, this.isDestructive = false});
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? CupertinoColors.tertiaryLabel.resolveFrom(context)
        : isDestructive
            ? CupertinoColors.destructiveRed
            : AppColors.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(label, style: TextStyle(fontSize: 16, color: color)),
      ),
    );
  }
}
