import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../folders/folder_icon_picker.dart';
import '../localization/strings.dart';
import '../notes/note_controller.dart';
import '../spaces/space_manager.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/selection_menu.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';
import 'tab_bar_config.dart';

/// Settings page for managing the multi-page tab bar layout.
class TabBarPagesView extends StatelessWidget {
  const TabBarPagesView({super.key, required this.controller});

  final SettingsController controller;

  Future<void> _addPage(BuildContext context) async {
    final cfg = controller.tabBarConfig;
    await controller.updateTabBarConfig(cfg.addPage());
  }

  Future<void> _removePage(BuildContext context, int idx) async {
    final cfg = controller.tabBarConfig;
    if (cfg.pages.length <= 1) return;
    final s = S.of(context);
    final ok = await confirmHardDelete(
      context,
      title: s.removePageTitle,
      body: s.removePageBody,
      confirmLabel: s.delete,
    );
    if (ok) await controller.updateTabBarConfig(cfg.removePage(idx));
  }

  Future<void> _addItem(BuildContext context, int pageIdx) async {
    final s = S.of(context);
    final cfg = controller.tabBarConfig;
    if (cfg.pages[pageIdx].length >= TabBarConfig.maxItemsPerPage) return;

    final kind = await showSelectionMenu<String>(
      context: context,
      title: s.addTab,
      options: [
        SelectionMenuOption(value: 'builtin', label: s.tabKindBuiltin),
        SelectionMenuOption(value: 'shortcut', label: s.tabKindShortcut),
      ],
    );
    if (kind == null) return;
    if (!context.mounted) return;
    if (kind == 'builtin') {
      await _addBuiltinItem(context, pageIdx);
    } else {
      await _addShortcutItem(context, pageIdx);
    }
  }

  Future<void> _addBuiltinItem(BuildContext context, int pageIdx) async {
    final s = S.of(context);
    final cfg = controller.tabBarConfig;
    // Show all 5 builtins — duplicates across pages are allowed (e.g. user
    // may want Tasks accessible from every page).
    final picked = await showSelectionMenu<int>(
      context: context,
      title: s.tabKindBuiltin,
      options: [
        SelectionMenuOption(value: 0, label: s.tabTasks),
        SelectionMenuOption(value: 1, label: s.tabNotes),
        SelectionMenuOption(value: 2, label: s.tabCalendar),
        SelectionMenuOption(value: 3, label: s.tabRoutines),
        SelectionMenuOption(value: 4, label: s.tabSettings),
      ],
    );
    if (picked == null) return;
    await controller.updateTabBarConfig(
        cfg.addItemToPage(pageIdx, TabItem.builtin(picked)));
  }

  Future<void> _addShortcutItem(BuildContext context, int pageIdx) async {
    final s = S.of(context);
    final cfg = controller.tabBarConfig;
    final target = await showSelectionMenu<ShortcutTarget>(
      context: context,
      title: s.tabKindShortcut,
      options: [
        SelectionMenuOption(value: ShortcutTarget.smartInbox, label: s.inbox),
        SelectionMenuOption(value: ShortcutTarget.smartToday, label: s.today),
        SelectionMenuOption(value: ShortcutTarget.smartTomorrow, label: s.tomorrow),
        SelectionMenuOption(
            value: ShortcutTarget.smartUpcoming, label: s.upcoming),
        SelectionMenuOption(
            value: ShortcutTarget.smartAllTasks, label: s.allTasks),
        SelectionMenuOption(
            value: ShortcutTarget.smartCompleted, label: s.completed),
        SelectionMenuOption(value: ShortcutTarget.smartTrash, label: s.trash),
        SelectionMenuOption(value: ShortcutTarget.list, label: s.tabShortcutList),
        SelectionMenuOption(
            value: ShortcutTarget.folder, label: s.tabShortcutFolder),
        SelectionMenuOption(
            value: ShortcutTarget.noteFolder, label: s.tabShortcutNoteFolder),
      ],
    );
    if (target == null) return;
    if (!context.mounted) return;

    String? shortcutId;
    String? customLabel;

    if (target == ShortcutTarget.list || target == ShortcutTarget.folder) {
      final fc = SpaceManagerProvider.of(context).folderController;
      final result = await _pickFolderOrList(context, fc, target);
      if (result == null) return;
      shortcutId = result.$1;
      customLabel = result.$2;
    } else if (target == ShortcutTarget.noteFolder) {
      final nc = SpaceManagerProvider.of(context).noteController;
      final result = await _pickNoteFolder(context, nc);
      if (result == null) return;
      shortcutId = result.$1;
      customLabel = result.$2;
    }

    await controller.updateTabBarConfig(cfg.addItemToPage(
      pageIdx,
      TabItem.shortcut(
        shortcutTarget: target,
        shortcutId: shortcutId,
        customLabel: customLabel,
      ),
    ));
  }

  Future<(String, String)?> _pickFolderOrList(
    BuildContext context,
    FolderController fc,
    ShortcutTarget target,
  ) async {
    final items = target == ShortcutTarget.list
        ? fc.lists.where((l) => !l.isDeleted).toList()
        : fc.folders.where((f) => !f.isDeleted).toList();
    if (items.isEmpty) return null;
    final picked = await showSelectionMenu<int>(
      context: context,
      title: target == ShortcutTarget.list ? S.of(context).list : S.of(context).folder,
      options: [
        for (var i = 0; i < items.length; i++)
          SelectionMenuOption(
            value: i,
            label: target == ShortcutTarget.list
                ? (items[i] as dynamic).name as String
                : (items[i] as dynamic).name as String,
          ),
      ],
    );
    if (picked == null) return null;
    final item = items[picked] as dynamic;
    return (item.id as String, item.name as String);
  }

  Future<(String, String)?> _pickNoteFolder(
      BuildContext context, NoteController nc) async {
    final folders = nc.folders.where((f) => !f.isDeleted).toList();
    if (folders.isEmpty) return null;
    final picked = await showSelectionMenu<int>(
      context: context,
      title: S.of(context).folder,
      options: [
        for (var i = 0; i < folders.length; i++)
          SelectionMenuOption(value: i, label: folders[i].name),
      ],
    );
    if (picked == null) return null;
    return (folders[picked].id, folders[picked].name);
  }

  Future<void> _removeItem(int pageIdx, int itemIdx) async {
    final cfg = controller.tabBarConfig;
    await controller.updateTabBarConfig(cfg.removeItem(pageIdx, itemIdx));
  }

  String _itemLabel(BuildContext context, TabItem item) {
    final s = S.of(context);
    if (item.kind == TabKind.builtin) {
      switch (item.builtinIndex) {
        case 0:
          return s.tabTasks;
        case 1:
          return s.tabNotes;
        case 2:
          return s.tabCalendar;
        case 3:
          return s.tabRoutines;
        default:
          return s.tabSettings;
      }
    }
    if (item.customLabel != null) return item.customLabel!;
    switch (item.shortcutTarget) {
      case ShortcutTarget.smartInbox:
        return s.inbox;
      case ShortcutTarget.smartToday:
        return s.today;
      case ShortcutTarget.smartTomorrow:
        return s.tomorrow;
      case ShortcutTarget.smartUpcoming:
        return s.upcoming;
      case ShortcutTarget.smartAllTasks:
        return s.allTasks;
      case ShortcutTarget.smartCompleted:
        return s.completed;
      case ShortcutTarget.smartTrash:
        return s.trash;
      case ShortcutTarget.list:
        return s.list;
      case ShortcutTarget.folder:
        return s.folder;
      case ShortcutTarget.noteFolder:
        return s.folder;
      default:
        return s.tabKindShortcut;
    }
  }

  Widget _itemIcon(BuildContext context, TabItem item) {
    if (item.kind == TabKind.builtin) {
      switch (item.builtinIndex) {
        case 0:
          return const ImageIcon(
              AssetImage('assets/icons/tab_bar/tasks.png'), size: 20);
        case 1:
          return const ImageIcon(
              AssetImage('assets/icons/tab_bar/notes.png'), size: 20);
        case 2:
          return const ImageIcon(
              AssetImage('assets/icons/tab_bar/calendar.png'), size: 20);
        case 3:
          return const ImageIcon(
              AssetImage('assets/icons/tab_bar/routines.png'), size: 20);
        default:
          return const ImageIcon(
              AssetImage('assets/icons/tab_bar/settings.png'), size: 20);
      }
    }
    switch (item.shortcutTarget) {
      case ShortcutTarget.list:
      case ShortcutTarget.folder:
      case ShortcutTarget.noteFolder:
        return SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: buildFolderItemIcon(
              null,
              isFolder: item.shortcutTarget != ShortcutTarget.list,
            ),
          ),
        );
      case ShortcutTarget.smartInbox:
        return Image.asset('assets/icons/inbox.png', width: 20, height: 20);
      case ShortcutTarget.smartToday:
        return Image.asset('assets/icons/today.png', width: 20, height: 20);
      case ShortcutTarget.smartTomorrow:
        return Icon(CupertinoIcons.sun_max,
            size: 20, color: CupertinoColors.systemOrange.resolveFrom(context));
      case ShortcutTarget.smartUpcoming:
        return Image.asset('assets/icons/upcoming.png', width: 20, height: 20);
      case ShortcutTarget.smartAllTasks:
        return Icon(CupertinoIcons.tray_full,
            size: 20,
            color: CupertinoColors.secondaryLabel.resolveFrom(context));
      case ShortcutTarget.smartCompleted:
        return Icon(CupertinoIcons.checkmark_circle_fill,
            size: 20, color: AppColors.systemGreen);
      case ShortcutTarget.smartTrash:
        return Icon(CupertinoIcons.trash,
            size: 20,
            color: CupertinoColors.secondaryLabel.resolveFrom(context));
      default:
        return const Icon(CupertinoIcons.square, size: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabBarPages),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (ctx, _) {
            final cfg = controller.tabBarConfig;
            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                for (var p = 0; p < cfg.pages.length; p++) ...[
                  _PageHeader(
                    pageNumber: p + 1,
                    canRemove: cfg.pages.length > 1,
                    onRemove: () => _removePage(ctx, p),
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < cfg.pages[p].length; i++)
                    _ItemRow(
                      label: _itemLabel(ctx, cfg.pages[p][i]),
                      icon: _itemIcon(ctx, cfg.pages[p][i]),
                      onRemove: () => _removeItem(p, i),
                    ),
                  if (cfg.pages[p].length <
                      TabBarConfig.maxItemsPerPage) ...[
                    const SizedBox(height: 6),
                    _AddRow(
                      label: s.addTab,
                      onTap: () => _addItem(ctx, p),
                    ),
                  ],
                  const SizedBox(height: 18),
                ],
                SettingsNavRow(
                  label: s.addPage,
                  onTap: () => _addPage(context),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.tabBarPagesHint,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.pageNumber,
    required this.canRemove,
    required this.onRemove,
  });

  final int pageNumber;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            S.of(context).pageNumberLabel(pageNumber),
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              letterSpacing: -0.08,
            ),
          ),
        ),
        if (canRemove)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: onRemove,
            child: Icon(
              CupertinoIcons.minus_circle,
              size: 18,
              color: CupertinoColors.destructiveRed.resolveFrom(context),
            ),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.label,
    required this.icon,
    required this.onRemove,
  });

  final String label;
  final Widget icon;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(width: 22, height: 22, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 17))),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: onRemove,
            child: Icon(
              CupertinoIcons.minus_circle,
              size: 20,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.add,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontSize: 17, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}
