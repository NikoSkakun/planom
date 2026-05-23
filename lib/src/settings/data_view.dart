import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../security/security_service.dart';
import '../theme/app_theme.dart';
import 'backup_service.dart';

class DataView extends StatefulWidget {
  const DataView({
    super.key,
    required this.backupService,
    this.securityService,
  });

  final BackupService backupService;
  final SecurityService? securityService;

  @override
  State<DataView> createState() => _DataViewState();
}

class _DataViewState extends State<DataView> {
  bool _exporting = false;
  bool _importing = false;
  bool _resetting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await widget.backupService.exportBackup();
    } catch (_) {
      if (!mounted) return;
      _showError(S.of(context).exportFailed, S.of(context).exportFailedBody);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    final s = S.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.replaceAllData),
        content: Text(s.replaceAllDataBody),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.confirm),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _importing = true);
    try {
      final success = await widget.backupService.importBackup();
      if (!mounted) return;
      if (success) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(S.of(context).importSuccessful),
            content: Text(S.of(context).importSuccessfulBody),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(S.of(context).ok),
              ),
            ],
          ),
        );
      } else {
        _showError(S.of(context).importFailed, S.of(context).importFailedInvalid);
      }
    } catch (_) {
      if (mounted) {
        _showError(S.of(context).importFailed, S.of(context).importFailedRead);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _reset() async {
    final s = S.of(context);

    // First confirmation
    final step1 = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.resetAllDataQuestion),
        content: Text(s.resetAllDataBody),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.resetAllData),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    // Password verification (if set)
    final sec = widget.securityService;
    if (sec != null && sec.isLocked) {
      final verified = await _verifyPassword(sec);
      if (!verified || !mounted) return;
    }

    // Execute reset
    setState(() => _resetting = true);
    try {
      await widget.backupService.hardReset();
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<bool> _verifyPassword(SecurityService sec) async {
    final s = S.of(context);
    bool ok = false;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _PasswordCheck(
        isPin: sec.type.isPin,
        pinLength: sec.type.pinLength,
        onVerify: (pw) async {
          ok = await sec.verify(pw);
          if (ok && ctx.mounted) Navigator.of(ctx).pop();
          if (!ok && ctx.mounted) {
            // Show error inside the sheet — just pop and show alert
            Navigator.of(ctx).pop();
          }
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
    if (!ok && mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(s.wrongPassword),
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
    return ok;
  }

  void _showError(String title, String body) {
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.sectionData),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            // ── Backup section ──────────────────────────────────────────
            Text(
              s.sectionData,
              style: TextStyle(
                  fontSize: 13, color: labelColor, letterSpacing: -0.08),
            ),
            const SizedBox(height: 8),
            _DataRow(
              label: s.exportBackup,
              sublabel: s.exportBackupSublabel,
              loading: _exporting,
              onTap: _exporting || _importing || _resetting ? null : _export,
            ),
            const SizedBox(height: 1),
            _DataRow(
              label: s.importBackup,
              sublabel: s.importBackupSublabel,
              loading: _importing,
              onTap: _exporting || _importing || _resetting ? null : _import,
            ),

            // ── Danger zone ─────────────────────────────────────────────
            const SizedBox(height: 32),
            Text(
              s.cannotBeUndone,
              style: TextStyle(
                  fontSize: 13, color: labelColor, letterSpacing: -0.08),
            ),
            const SizedBox(height: 8),
            _DataRow(
              label: s.resetAllData,
              sublabel: s.resetAllDataBody,
              loading: _resetting,
              onTap: _exporting || _importing || _resetting ? null : _reset,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.sublabel,
    required this.loading,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final String sublabel;
  final bool loading;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);
    final disabled = onTap == null && !loading;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      color: isDestructive
                          ? CupertinoColors.destructiveRed
                          : disabled
                              ? CupertinoColors.secondaryLabel
                                  .resolveFrom(context)
                              : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const CupertinoActivityIndicator()
            else
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

// ── Password verification widget (used in reset flow) ────────────────────────

class _PasswordCheck extends StatefulWidget {
  const _PasswordCheck({
    required this.isPin,
    required this.pinLength,
    required this.onVerify,
    required this.onCancel,
  });

  final bool isPin;
  final int pinLength;
  final Future<void> Function(String) onVerify;
  final VoidCallback onCancel;

  @override
  State<_PasswordCheck> createState() => _PasswordCheckState();
}

class _PasswordCheckState extends State<_PasswordCheck> {
  String _entered = '';
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_busy || _entered.length >= widget.pinLength) return;
    setState(() => _entered += d);
    if (_entered.length == widget.pinLength) _submit(_entered);
  }

  void _onBack() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit(String pw) async {
    setState(() => _busy = true);
    await widget.onVerify(pw);
    if (mounted) setState(() { _busy = false; _entered = ''; });
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final s = S.of(context);
    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Text(s.currentPassword,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            if (widget.isPin) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.pinLength, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _entered.length
                          ? CupertinoColors.label.resolveFrom(context)
                          : CupertinoColors.systemGrey4.resolveFrom(context),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              _NumpadSmall(onDigit: _onDigit, onBack: _onBack),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: CupertinoTextField(
                  controller: _ctrl,
                  obscureText: true,
                  placeholder: s.enterPassword,
                  textAlign: TextAlign.center,
                  autofocus: true,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: CupertinoButton.filled(
                  onPressed: () => _submit(_ctrl.text.trim()),
                  child: Text(s.ok),
                ),
              ),
            ],
            CupertinoButton(
              onPressed: widget.onCancel,
              child: Text(s.cancel,
                  style: const TextStyle(
                      color: CupertinoColors.destructiveRed)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NumpadSmall extends StatelessWidget {
  const _NumpadSmall({required this.onDigit, required this.onBack});
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((d) {
            if (d.isEmpty) return const SizedBox(width: 80, height: 60);
            final isBack = d == '⌫';
            return SizedBox(
              width: 80,
              height: 60,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: isBack ? onBack : () => onDigit(d),
                child: Text(d,
                    style: TextStyle(
                        fontSize: isBack ? 20 : 26,
                        color: CupertinoColors.label.resolveFrom(context),
                        fontWeight: FontWeight.w300)),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
