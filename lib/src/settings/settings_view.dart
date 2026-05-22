import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart' show ThemeMode;

import '../localization/strings.dart';
import '../spaces/space_manager.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import 'appearance_view.dart';
import 'backup_service.dart';
import 'font_picker_view.dart';
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
      _showErrorDialog(S.of(context).exportFailed, S.of(context).exportFailedBody);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    if (widget.backupService == null) return;
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
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      final success = await widget.backupService!.importBackup();
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
        _showErrorDialog(
          S.of(context).importFailed,
          S.of(context).importFailedInvalid,
        );
      }
    } catch (_) {
      if (mounted) {
        _showErrorDialog(
            S.of(context).importFailed, S.of(context).importFailedRead);
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
            child: Text(S.of(context).ok),
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
    final s = S.of(context);
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.newSpace),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: s.spaceName,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              spaceManager.addSpace(name);
            },
            child: Text(s.create),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  void _showVisibilityPicker(
      BuildContext context, String key, SmartListVisibility current) {
    final s = S.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(s.visibility),
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
                  _visibilityLabel(s, v),
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
          child: Text(s.cancel),
        ),
      ),
    );
  }

  static String _visibilityLabel(S s, SmartListVisibility v) {
    switch (v) {
      case SmartListVisibility.show:
        return s.visibilityShow;
      case SmartListVisibility.showIfNotEmpty:
        return s.visibilityIfNotEmpty;
      case SmartListVisibility.hidden:
        return s.visibilityHidden;
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final s = S.of(context);
    final current = widget.controller.locale.languageCode;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(s.language),
        actions: kSupportedLocales.map((loc) {
          final isSelected = loc.languageCode == current;
          return CupertinoActionSheetAction(
            onPressed: () {
              widget.controller.updateLocale(loc);
              Navigator.of(ctx).pop();
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
                  kLanguageNames[loc.languageCode] ?? loc.languageCode,
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
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.cancel),
        ),
      ),
    );
  }

  void _openFontPicker(BuildContext context) {
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => FontPickerView(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final hasBackup = widget.backupService != null;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.settings),
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
              s.sectionAppearance,
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
                final tm = widget.controller.themeMode;
                final themeName = tm == ThemeMode.light
                    ? s.themeLight
                    : tm == ThemeMode.dark
                        ? s.themeDark
                        : s.themeSystem;
                return _NavRow(
                  label: s.sectionAppearance,
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
            const SizedBox(height: 32),
            Text(
              s.sectionLanguage,
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
                final code = widget.controller.locale.languageCode;
                return _NavRow(
                  label: s.language,
                  trailingLabel: kLanguageNames[code] ?? code,
                  onTap: () => _showLanguagePicker(context),
                );
              },
            ),
            const SizedBox(height: 1),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (ctx, _) {
                final key = widget.controller.fontKey;
                return _NavRow(
                  label: s.font,
                  trailingLabel: key == kSystemFontKey
                      ? s.systemFont
                      : fontDisplayName(key),
                  onTap: () => _openFontPicker(context),
                );
              },
            ),

            // ── Smart Lists ─────────────────────────────────────────────
            const SizedBox(height: 32),
            Text(
              s.sectionSmartLists,
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
                      label: s.inbox,
                    ),
                    const SizedBox(height: 1),
                    _SmartListRow(
                      icon: Image.asset('assets/icons/today.png',
                          width: 22, height: 22),
                      label: s.today,
                      visibility: prefs.today,
                      onTap: () => _showVisibilityPicker(
                          ctx, 'today', prefs.today),
                    ),
                    const SizedBox(height: 1),
                    _SmartListRow(
                      icon: Image.asset('assets/icons/upcoming.png',
                          width: 22, height: 22),
                      label: s.upcoming,
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
                      label: s.completed,
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
                      label: s.trash,
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
              s.sectionCustomization,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 8),
            _NavRow(
              label: s.tabBar,
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
                s.sectionData,
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 8),
              _DataRow(
                label: s.exportBackup,
                sublabel: s.exportBackupSublabel,
                loading: _exporting,
                onTap: _exporting || _importing ? null : _export,
              ),
              const SizedBox(height: 1),
              _DataRow(
                label: s.importBackup,
                sublabel: s.importBackupSublabel,
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
    final s = S.of(context);

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
                  name: s.newSpace,
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
              color: isActive ? AppColors.accent : CupertinoColors.transparent,
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
            final visibleCount = controller.visibleOptionalTabCount;
            final settingsVisible = controller.isTabVisible(4);

            bool isDisabled(int tabIndex) =>
                visibleCount == 1 && controller.isTabVisible(tabIndex);

            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                Text(
                  s.display,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: s.hideLabels,
                  value: controller.hideTabLabels,
                  onChanged: controller.updateHideTabLabels,
                ),
                const SizedBox(height: 32),
                Text(
                  s.visibleTabs,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: s.tabTasks,
                  value: controller.isTabVisible(0),
                  enabled: !isDisabled(0),
                  onChanged: (v) => controller.setTabVisible(0, v),
                ),
                const SizedBox(height: 1),
                _ToggleRow(
                  label: s.tabNotes,
                  value: controller.isTabVisible(1),
                  enabled: !isDisabled(1),
                  onChanged: (v) => controller.setTabVisible(1, v),
                ),
                const SizedBox(height: 1),
                _ToggleRow(
                  label: s.tabCalendar,
                  value: controller.isTabVisible(2),
                  enabled: !isDisabled(2),
                  onChanged: (v) => controller.setTabVisible(2, v),
                ),
                const SizedBox(height: 1),
                _ToggleRow(
                  label: s.tabRoutines,
                  value: controller.isTabVisible(3),
                  enabled: !isDisabled(3),
                  onChanged: (v) => controller.setTabVisible(3, v),
                ),
                const SizedBox(height: 1),
                _ToggleRow(
                  label: s.tabSettings,
                  value: settingsVisible,
                  enabled: !isDisabled(4),
                  onChanged: (v) => controller.setTabVisible(4, v),
                ),
                if (!settingsVisible) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      s.settingsAccessibleHint,
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
  const _NavRow({required this.label, required this.onTap, this.trailingLabel});

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
    final s = S.of(context);
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
                  ? s.visibilityAlwaysShown
                  : _visibilityLabel(s, visibility!),
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

  static String _visibilityLabel(S s, SmartListVisibility v) {
    switch (v) {
      case SmartListVisibility.show:
        return s.visibilityShow;
      case SmartListVisibility.showIfNotEmpty:
        return s.visibilityIfNotEmpty;
      case SmartListVisibility.hidden:
        return s.visibilityHidden;
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
