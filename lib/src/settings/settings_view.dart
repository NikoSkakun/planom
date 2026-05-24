import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart' show ReorderableDragStartListener, ReorderableListView, ThemeMode;

import '../localization/strings.dart';
import '../security/security_service.dart';
import '../spaces/space_manager.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'appearance_view.dart';
import 'backup_service.dart';
import 'data_view.dart';
import 'font_picker_view.dart';
import 'notifications_view.dart';
import 'security_view.dart';
import 'settings_controller.dart';
import 'smart_list_prefs.dart';
import 'sync_settings_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.controller,
    this.backupService,
    this.securityService,
  });

  final SettingsController controller;
  final BackupService? backupService;
  final SecurityService? securityService;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> with DropdownOverlayMixin {
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
        onDeleteSpace: (id) {
          dismiss();
          _confirmDeleteSpace(context, spaceManager, id);
        },
      );
    });
  }

  void _confirmDeleteSpace(
      BuildContext context, SpaceManager spaceManager, String id) {
    final s = S.of(context);
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.deleteSpace),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(s.deleteSpaceBody),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              spaceManager.deleteSpace(id);
            },
            child: Text(s.delete),
          ),
        ],
      ),
    );
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

  Future<void> _showVisibilityPicker(
      BuildContext context, String key, SmartListVisibility current) async {
    final s = S.of(context);
    final selected = await showSelectionMenu<SmartListVisibility>(
      context: context,
      title: s.visibility,
      current: current,
      options: SmartListVisibility.values
          .map((v) => SelectionMenuOption(
                value: v,
                label: _visibilityLabel(s, v),
              ))
          .toList(),
    );
    if (selected != null) {
      widget.controller.updateSmartListVisibility(key, selected);
    }
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

  Future<void> _showLanguagePicker(BuildContext context) async {
    final s = S.of(context);
    final current = widget.controller.locale.languageCode;
    final selected = await showSelectionMenu<String>(
      context: context,
      title: s.language,
      current: current,
      options: kSupportedLocales
          .map((loc) => SelectionMenuOption(
                value: loc.languageCode,
                label: kLanguageNames[loc.languageCode] ?? loc.languageCode,
              ))
          .toList(),
    );
    if (selected != null) {
      widget.controller.updateLocale(Locale(selected));
    }
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            const SizedBox(height: 6),
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
            const SizedBox(height: 18),
            Text(
              s.sectionLanguage,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
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
            const SizedBox(height: 18),
            Text(
              s.sectionSmartLists,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
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
                      icon: Icon(
                        CupertinoIcons.sun_max,
                        size: 22,
                        color: CupertinoColors.systemOrange
                            .resolveFrom(ctx),
                      ),
                      label: s.tomorrow,
                      visibility: prefs.tomorrow,
                      onTap: () => _showVisibilityPicker(
                          ctx, 'tomorrow', prefs.tomorrow),
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
                      icon: Icon(
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
            const SizedBox(height: 18),
            Text(
              s.sectionCustomization,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
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

            // ── Notifications ────────────────────────────────────────
            const SizedBox(height: 18),
            Text(
              s.sectionNotifications,
              style: TextStyle(
                fontSize: 13,
                color: labelColor,
                letterSpacing: -0.08,
              ),
            ),
            const SizedBox(height: 6),
            _NavRow(
              label: s.sectionNotifications,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => const NotificationsSettingsView(),
                ),
              ),
            ),

            // ── Security ─────────────────────────────────────────────
            if (widget.securityService != null) ...[
              const SizedBox(height: 18),
              Text(
                s.sectionSecurity,
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 6),
              _NavRow(
                label: s.sectionSecurity,
                onTap: () => Navigator.of(context).push(
                  FastRoute<void>(
                    builder: (_) => SecuritySettingsView(
                      securityService: widget.securityService!,
                    ),
                  ),
                ),
              ),
            ],

            if (hasBackup) ...[
              // ── Sync ──────────────────────────────────────────────
              const SizedBox(height: 18),
              Text(
                s.sync,
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 6),
              _NavRow(
                label: s.sync,
                onTap: () {
                  final syncController =
                      SpaceManagerProvider.of(context).syncController;
                  Navigator.of(context).push(
                    FastRoute<void>(
                      builder: (_) =>
                          SyncSettingsView(controller: syncController),
                    ),
                  );
                },
              ),

              // ── Data ──────────────────────────────────────────────
              const SizedBox(height: 18),
              Text(
                s.sectionData,
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 6),
              _NavRow(
                label: s.sectionData,
                onTap: () => Navigator.of(context).push(
                  FastRoute<void>(
                    builder: (_) => DataView(
                      backupService: widget.backupService!,
                      securityService: widget.securityService,
                    ),
                  ),
                ),
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
    required this.onDeleteSpace,
  });

  final SpaceManager spaceManager;
  final VoidCallback onDismiss;
  final VoidCallback onAddSpace;
  final void Function(String id) onDeleteSpace;

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
              borderRadius: BorderRadius.circular(14),
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
                    // The default space and the active space can't be deleted
                    // from here (switch away first to delete a non-default one).
                    onDelete: (space.id != 'default' && space.id != activeId)
                        ? () => onDeleteSpace(space.id)
                        : null,
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
    this.onDelete,
  });

  final String name;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;
  final VoidCallback? onDelete;

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
            )
          else if (onDelete != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  CupertinoIcons.delete,
                  size: 16,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
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

  String _tabLabel(S s, int tabIndex) {
    switch (tabIndex) {
      case 0: return s.tabTasks;
      case 1: return s.tabNotes;
      case 2: return s.tabCalendar;
      case 3: return s.tabRoutines;
      case 4: return s.tabSettings;
      default: return '';
    }
  }

  String _defaultTabLabel(S s, String value) {
    if (value == kLastOpenedTab) return s.lastOpenedTab;
    return _tabLabel(s, int.tryParse(value) ?? 0);
  }

  Future<void> _showDefaultTabPicker(BuildContext context) async {
    final s = S.of(context);
    final visible = controller.tabOrder.where(controller.isTabVisible).toList();
    final selected = await showSelectionMenu<String>(
      context: context,
      title: s.defaultTab,
      current: controller.defaultTab,
      options: [
        SelectionMenuOption(value: kLastOpenedTab, label: s.lastOpenedTab),
        for (final i in visible)
          SelectionMenuOption(value: i.toString(), label: _tabLabel(s, i)),
      ],
    );
    if (selected != null) controller.updateDefaultTab(selected);
  }

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
            final tabOrder = controller.tabOrder;

            bool isDisabled(int tabIndex) =>
                visibleCount == 1 && controller.isTabVisible(tabIndex);

            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Display ────────────────────────────────────────────
                  Text(
                    s.display,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ToggleRow(
                    label: s.hideLabels,
                    value: controller.hideTabLabels,
                    onChanged: controller.updateHideTabLabels,
                  ),
                  const SizedBox(height: 18),
                  // ── Startup ────────────────────────────────────────────
                  Text(
                    s.startup,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _NavRow(
                    label: s.defaultTab,
                    trailingLabel:
                        _defaultTabLabel(s, controller.defaultTab),
                    onTap: () => _showDefaultTabPicker(context),
                  ),
                  const SizedBox(height: 18),
                  // ── Visible Tabs (reorderable) ─────────────────────────
                  Text(
                    s.visibleTabs,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      final newOrder = List.of(tabOrder);
                      if (newIndex > oldIndex) newIndex--;
                      final item = newOrder.removeAt(oldIndex);
                      newOrder.insert(newIndex, item);
                      controller.updateTabOrder(newOrder);
                    },
                    children: [
                      for (int i = 0; i < tabOrder.length; i++)
                        _TabOrderRow(
                          key: ValueKey(tabOrder[i]),
                          index: i,
                          label: _tabLabel(s, tabOrder[i]),
                          isVisible: controller.isTabVisible(tabOrder[i]),
                          isDisabled: isDisabled(tabOrder[i]),
                          onVisibilityChanged: (v) =>
                              controller.setTabVisible(tabOrder[i], v),
                        ),
                    ],
                  ),
                  if (!settingsVisible) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        s.settingsAccessibleHint,
                        style: TextStyle(fontSize: 13, color: labelColor),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Tab order row ─────────────────────────────────────────────────────────────

class _TabOrderRow extends StatelessWidget {
  const _TabOrderRow({
    super.key,
    required this.index,
    required this.label,
    required this.isVisible,
    required this.isDisabled,
    required this.onVisibilityChanged,
  });

  final int index;
  final String label;
  final bool isVisible;
  final bool isDisabled;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              value: isVisible,
              onChanged: isDisabled ? null : onVisibilityChanged,
              activeColor: AppColors.accent,
            ),
            const SizedBox(width: 12),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                size: 20,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

