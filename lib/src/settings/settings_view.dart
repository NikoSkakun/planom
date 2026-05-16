import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'backup_service.dart';
import 'settings_controller.dart';
import 'smart_list_prefs.dart';

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
      _showErrorDialog(
          'Export Failed', 'An error occurred while creating the backup.');
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
            content:
                const Text('Your data has been restored from the backup.'),
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
        _showErrorDialog(
            'Import Failed', 'An error occurred while reading the file.');
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

  void _showVisibilityPicker(
      BuildContext context, String key, SmartListVisibility current) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Visibility'),
        actions: SmartListVisibility.values.map((v) {
          final isSelected = v == current;
          return CupertinoActionSheetAction(
            onPressed: () {
              widget.controller.updateSmartListVisibility(key, v);
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                Text(
                  _visibilityLabel(v),
                  style: TextStyle(
                    color: isSelected
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.label,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  static String _visibilityLabel(SmartListVisibility v) {
    switch (v) {
      case SmartListVisibility.show:
        return 'Show';
      case SmartListVisibility.showIfNotEmpty:
        return 'If not empty';
      case SmartListVisibility.hidden:
        return 'Hidden';
    }
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
              builder: (context, _) =>
                  CupertinoSlidingSegmentedControl<ThemeMode>(
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

            // ── Smart Lists ─────────────────────────────────────────────
            const SizedBox(height: 32),
            Text(
              'Smart Lists',
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (ctx, _) {
                final prefs = widget.controller.smartListPrefs;
                return Column(
                  children: [
                    _SmartListRow(
                      icon: Image.asset('assets/icons/inbox.png',
                          width: 22, height: 22),
                      label: 'Inbox',
                    ),
                    const SizedBox(height: 1),
                    _SmartListRow(
                      icon: Image.asset('assets/icons/today.png',
                          width: 22, height: 22),
                      label: 'Today',
                      visibility: prefs.today,
                      onTap: () => _showVisibilityPicker(
                          ctx, 'today', prefs.today),
                    ),
                    const SizedBox(height: 1),
                    _SmartListRow(
                      icon: Image.asset('assets/icons/upcoming.png',
                          width: 22, height: 22),
                      label: 'Upcoming',
                      visibility: prefs.upcoming,
                      onTap: () => _showVisibilityPicker(
                          ctx, 'upcoming', prefs.upcoming),
                    ),
                    const SizedBox(height: 1),
                    _SmartListRow(
                      icon: const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 22,
                        color: Color(0xFF34C759),
                      ),
                      label: 'Completed',
                      visibility: prefs.completed,
                      onTap: () => _showVisibilityPicker(
                          ctx, 'completed', prefs.completed),
                    ),
                    const SizedBox(height: 1),
                    _SmartListRow(
                      icon: Icon(
                        CupertinoIcons.trash,
                        size: 22,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(ctx),
                      ),
                      label: 'Trash',
                      visibility: prefs.trash,
                      onTap: () => _showVisibilityPicker(
                          ctx, 'trash', prefs.trash),
                    ),
                  ],
                );
              },
            ),

            // ── Tab Bar ─────────────────────────────────────────────
            const SizedBox(height: 32),
            Text(
              'Tab Bar',
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (ctx, _) => Column(
                children: [
                  _ToggleRow(
                    label: 'Hide Labels',
                    value: widget.controller.hideTabLabels,
                    onChanged: widget.controller.updateHideTabLabels,
                  ),
                  const SizedBox(height: 1),
                  _ToggleRow(
                    label: 'Notes',
                    value: widget.controller.isTabVisible(1),
                    onChanged: (v) => widget.controller.setTabVisible(1, v),
                  ),
                  const SizedBox(height: 1),
                  _ToggleRow(
                    label: 'Calendar',
                    value: widget.controller.isTabVisible(2),
                    onChanged: (v) => widget.controller.setTabVisible(2, v),
                  ),
                  const SizedBox(height: 1),
                  _ToggleRow(
                    label: 'Routines',
                    value: widget.controller.isTabVisible(3),
                    onChanged: (v) => widget.controller.setTabVisible(3, v),
                  ),
                ],
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

class _SmartListRow extends StatelessWidget {
  const _SmartListRow({
    required this.icon,
    required this.label,
    this.visibility,
    this.onTap,
  });

  final Widget icon;
  final String label;
  final SmartListVisibility? visibility;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    final isDisabled = onTap == null;

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
            SizedBox(width: 22, height: 22, child: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: isDisabled
                      ? CupertinoColors.secondaryLabel.resolveFrom(context)
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isDisabled
                  ? 'Always shown'
                  : _visibilityLabel(visibility!),
              style: TextStyle(
                fontSize: 15,
                color:
                    CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            if (!isDisabled) ...[
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color:
                    CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _visibilityLabel(SmartListVisibility v) {
    switch (v) {
      case SmartListVisibility.show:
        return 'Show';
      case SmartListVisibility.showIfNotEmpty:
        return 'If not empty';
      case SmartListVisibility.hidden:
        return 'Hidden';
    }
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
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF4D00),
          ),
        ],
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
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
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
                color:
                    CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }
}
