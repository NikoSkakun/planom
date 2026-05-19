import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart' show ThemeMode;

import '../spaces/space_manager.dart';
import '../theme/app_theme.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import 'backup_service.dart';
import 'settings_controller.dart';
import 'smart_list_prefs.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.controller,
    this.backupService,
  });

  final SettingsController controller;
  final BackupService? backupService;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> with DropdownOverlayMixin {
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

  void _showSpacesMenu(BuildContext context) {
    final spaceManager = SpaceManagerProvider.of(context);
    showDropdown(context, (dismiss) {
      return _SpacesDropdown(
        spaceManager: spaceManager,
        onDismiss: dismiss,
        onAddSpace: () {
          dismiss();
          _showAddSpaceDialog(context, spaceManager);
        },
      );
    });
  }

  void _showAddSpaceDialog(BuildContext context, SpaceManager spaceManager) {
    final ctrl = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('New Space'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: 'Space name',
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              spaceManager.addSpace(name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
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
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: const Text('Settings'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showSpacesMenu(context),
          child: const Icon(CupertinoIcons.ellipsis, size: 26),
        ),
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
                        color: AppColors.systemGreen,
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

            // ── Tab Bar ─────────────────────────────────────────────────
            const SizedBox(height: 32),
            Text(
              'Customization',
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 8),
            _NavRow(
              label: 'Tab Bar',
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => TabBarSettingsView(
                    controller: widget.controller,
                  ),
                ),
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

// ── Spaces dropdown ──────────────────────────────────────────────────────────

class _SpacesDropdown extends StatelessWidget {
  const _SpacesDropdown({
    required this.spaceManager,
    required this.onDismiss,
    required this.onAddSpace,
  });

  final SpaceManager spaceManager;
  final VoidCallback onDismiss;
  final VoidCallback onAddSpace;

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.paddingOf(context).top + 44.0 + 4.0;
    final spaces = spaceManager.spaces;
    final activeId = spaceManager.activeSpaceId;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: const SizedBox.expand(),
        ),
        Positioned(
          top: topOffset,
          right: 8,
          child: Container(
            width: 220,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final space in spaces) ...[
                  _SpaceRow(
                    name: space.name,
                    isActive: space.id == activeId,
                    onTap: () {
                      onDismiss();
                      spaceManager.switchSpace(space.id);
                    },
                  ),
                  if (space != spaces.last)
                    Container(
                      height: 0.5,
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                ],
                Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                _SpaceRow(
                  name: 'New Space',
                  icon: CupertinoIcons.plus,
                  isActive: false,
                  onTap: onAddSpace,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpaceRow extends StatelessWidget {
  const _SpaceRow({
    required this.name,
    required this.isActive,
    required this.onTap,
    this.icon,
  });

  final String name;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, size: 18, color: fg)
          else
            Icon(
              CupertinoIcons.circle_fill,
              size: 10,
              color: isActive ? AppColors.accent : CupertinoColors.clear,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 16, color: fg),
            ),
          ),
          if (isActive)
            Icon(
              CupertinoIcons.checkmark,
              size: 16,
              color: AppColors.accent,
            ),
        ],
      ),
    );
  }
}

// ── Tab Bar settings sub-page ────────────────────────────────────────────────

class TabBarSettingsView extends StatelessWidget {
  const TabBarSettingsView({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        border: null,
        middle: Text('Tab Bar'),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (ctx, _) {
            final visibleCount = controller.visibleOptionalTabCount;
            final settingsVisible = controller.isTabVisible(4);

            bool isDisabled(int tabIndex) =>
                visibleCount == 1 && controller.isTabVisible(tabIndex);

            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                Text(
                  'Display',
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: 'Hide Labels',
                  value: controller.hideTabLabels,
                  onChanged: controller.updateHideTabLabels,
                ),
                const SizedBox(height: 32),
                Text(
                  'Visible Tabs',
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: 'Tasks',
                  value: controller.isTabVisible(0),
                  enabled: !isDisabled(0),
                  onChanged: (v) => controller.setTabVisible(0, v),
                ),
                const SizedBox(height: 1),
                _ToggleRow(
                  label: 'Notes',
                  value: controller.isTabVisible(1),
                  enabled: !isDisabled(1),
                  onChanged: (v) => controller.setTabVisible(1, v),
                ),
                const SizedBox(height: 1),
                _ToggleRow(
                  label: 'Calendar',
                  value: controller.isTabVisible(2),
                  enabled: !isDisabled(2),
                  onChanged: (v) => controller.setTabVisible(2, v),
                ),
                const SizedBox(height: 1),
                _ToggleRow(
                  label: 'Routines',
                  value: controller.isTabVisible(3),
                  enabled: !isDisabled(3),
                  onChanged: (v) => controller.setTabVisible(3, v),
                ),
                const SizedBox(height: 1),
                _ToggleRow(
                  label: 'Settings',
                  value: settingsVisible,
                  enabled: !isDisabled(4),
                  onChanged: (v) => controller.setTabVisible(4, v),
                ),
                if (!settingsVisible) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Settings is accessible from the options menu (⋯) in every other tab.',
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

// ── Shared row widgets ────────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
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
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
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
              onChanged: enabled ? onChanged : null,
              activeColor: AppColors.accent,
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
