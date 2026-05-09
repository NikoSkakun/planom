import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'backup_service.dart';
import 'settings_controller.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.controller,
    this.backupService,
  });

  static const routeName = '/settings';

  final SettingsController controller;
  final BackupService? backupService;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    if (widget.backupService == null) return;
    setState(() => _exporting = true);
    try {
      await widget.backupService!.exportBackup();
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('Export Failed', 'An error occurred while creating the backup.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    if (widget.backupService == null) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Replace All Data?'),
        content: const Text(
          'Importing will permanently replace all current data with the backup. This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Import'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      final success = await widget.backupService!.importBackup();
      if (!mounted) return;
      if (success) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Import Successful'),
            content: const Text('Your data has been restored from the backup.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog(
          'Import Failed',
          'The selected file is not a valid Planom backup.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showErrorDialog('Import Failed', 'An error occurred while reading the file.');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final hasBackup = widget.backupService != null;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        border: null,
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            // ── Appearance ──────────────────────────────────────────────
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => CupertinoSlidingSegmentedControl<ThemeMode>(
                groupValue: widget.controller.themeMode,
                onValueChanged: widget.controller.updateThemeMode,
                children: const {
                  ThemeMode.light: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Light'),
                  ),
                  ThemeMode.system: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('System'),
                  ),
                  ThemeMode.dark: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Dark'),
                  ),
                },
              ),
            ),

            if (hasBackup) ...[
              const SizedBox(height: 32),

              // ── Data ────────────────────────────────────────────────
              Text(
                'Data',
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 8),
              _DataRow(
                label: 'Export Backup',
                sublabel: 'Planom (.planom) · full restore',
                loading: _exporting,
                onTap: _exporting || _importing ? null : _export,
              ),
              const SizedBox(height: 1),
              _DataRow(
                label: 'Import Backup',
                sublabel: 'Planom (.planom) · replaces all data',
                loading: _importing,
                onTap: _exporting || _importing ? null : _import,
              ),
            ],
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
  });

  final String label;
  final String sublabel;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
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
                      color: disabled
                          ? CupertinoColors.secondaryLabel.resolveFrom(context)
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
