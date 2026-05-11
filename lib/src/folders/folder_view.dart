import 'package:flutter/cupertino.dart';

import '../models/app_folder.dart';
import '../tasks/task_controller.dart';
import '../utils/fast_route.dart';
import '../utils/item_info_sheet.dart';
import 'create_folder_list_sheet.dart' show showCreateFolderListSheet, showRenameSheet;
import 'folder_controller.dart';
import 'folder_icon_picker.dart';
import 'list_task_view.dart';
import 'move_to_sheet.dart';

class FolderView extends StatefulWidget {
  const FolderView({
    super.key,
    required this.folder,
    required this.folderController,
    required this.taskController,
    required this.activeListId,
  });

  final AppFolder folder;
  final FolderController folderController;
  final TaskController taskController;
  final ValueNotifier<String?> activeListId;

  @override
  State<FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends State<FolderView> {
  late AppFolder _currentFolder;

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
  }

  Future<bool> _confirmDelete(String name, {required bool isFolder}) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Move "$name" to Trash?'),
        content: Text(isFolder
            ? 'This folder and all its contents will be moved to Trash.'
            : 'This list and all its tasks will be moved to Trash.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Move to Trash'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _proxyDecorator(
      Widget child, int index, Animation<double> animation) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  void _showDropdown(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _FolderOptionsDropdown(
        onDismiss: () => entry.remove(),
        onRename: () {
          entry.remove();
          showRenameSheet(
            context,
            currentName: _currentFolder.name,
            onRename: (name) async {
              final updated = _currentFolder.copyWith(name: name);
              await widget.folderController.updateFolder(updated);
              if (mounted) setState(() => _currentFolder = updated);
            },
          );
        },
        onChangeIcon: () {
          entry.remove();
          showFolderIconPickerSheet(
            context,
            currentIconId: _currentFolder.iconId,
            isFolder: true,
            onSelected: (id) {
              final updated = _currentFolder.copyWith(
                iconId: id,
                clearIconId: id == null,
              );
              widget.folderController.updateFolder(updated);
              if (mounted) setState(() => _currentFolder = updated);
            },
          );
        },
        onMoveTo: () {
          entry.remove();
          showMoveToSheet(
            context,
            folderController: widget.folderController,
            currentParentId: _currentFolder.parentFolderId,
            excludeFolderId: _currentFolder.id,
            onMove: (folderId) async {
              final updated = folderId == null
                  ? _currentFolder.copyWith(clearParent: true)
                  : _currentFolder.copyWith(parentFolderId: folderId);
              await widget.folderController.updateFolder(updated);
              if (mounted) setState(() => _currentFolder = updated);
            },
          );
        },
        onInfo: () {
          entry.remove();
          showItemInfoSheet(context, creationDate: _currentFolder.creationDate);
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(_currentFolder.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showDropdown(context),
          child: const Icon(CupertinoIcons.ellipsis, size: 26),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListenableBuilder(
              listenable:
                  Listenable.merge([widget.folderController, widget.taskController]),
              builder: (context, _) {
                final subFolders =
                    widget.folderController.foldersIn(_currentFolder.id);
                final lists =
                    widget.folderController.listsIn(_currentFolder.id);

                if (subFolders.isEmpty && lists.isEmpty) {
                  return const Center(
                    child: Text(
                      'No items',
                      style: TextStyle(
                          color: CupertinoColors.secondaryLabel),
                    ),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 8)),

                    if (subFolders.isNotEmpty)
                      SliverReorderableList(
                        itemCount: subFolders.length,
                        onReorder: (old, neo) =>
                            widget.folderController.reorderFolders(
                                _currentFolder.id, old, neo),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final f = subFolders[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('sf_${f.id}'),
                            index: index,
                            child: Dismissible(
                              key: ValueKey(f.id),
                              direction: DismissDirection.endToStart,
                              background: _DeleteBackground(),
                              confirmDismiss: (_) =>
                                  _confirmDelete(f.name, isFolder: true),
                              onDismissed: (_) =>
                                  widget.folderController.deleteFolderDeep(
                                f.id,
                                widget.taskController.deleteTasksForList,
                              ),
                              child: _FolderListItem(
                                icon: buildFolderItemIcon(
                                  f.iconId,
                                  isFolder: true,
                                ),
                                label: f.name,
                                isFolder: true,
                                onTap: () =>
                                    Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => FolderView(
                                      folder: f,
                                      folderController: widget.folderController,
                                      taskController: widget.taskController,
                                      activeListId: widget.activeListId,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    if (lists.isNotEmpty)
                      SliverReorderableList(
                        itemCount: lists.length,
                        onReorder: (old, neo) =>
                            widget.folderController.reorderLists(
                                _currentFolder.id, old, neo),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final l = lists[index];
                          final count = widget.taskController
                              .uncompletedCountForList(l.id);
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('fl_${l.id}'),
                            index: index,
                            child: Dismissible(
                              key: ValueKey(l.id),
                              direction: DismissDirection.endToStart,
                              background: _DeleteBackground(),
                              confirmDismiss: (_) =>
                                  _confirmDelete(l.name, isFolder: false),
                              onDismissed: (_) async {
                                await widget.taskController
                                    .deleteTasksForList(l.id);
                                await widget.folderController.deleteList(l.id);
                              },
                              child: _FolderListItem(
                                icon: buildFolderItemIcon(
                                  l.iconId,
                                  isFolder: false,
                                ),
                                label: l.name,
                                count: count > 0 ? count : null,
                                onTap: () =>
                                    Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => ListTaskView(
                                      list: l,
                                      taskController: widget.taskController,
                                      folderController: widget.folderController,
                                      activeListId: widget.activeListId,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    const SliverToBoxAdapter(
                        child: SizedBox(height: 80)),
                  ],
                );
              },
            ),
            Positioned(
              left: 20,
              bottom: 16,
              child: _CircleButton(
                onPressed: () => showCreateFolderListSheet(
                  context,
                  widget.folderController,
                  parentFolderId: _currentFolder.id,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderOptionsDropdown extends StatelessWidget {
  const _FolderOptionsDropdown({
    required this.onDismiss,
    required this.onRename,
    required this.onChangeIcon,
    required this.onMoveTo,
    required this.onInfo,
  });

  final VoidCallback onDismiss;
  final VoidCallback onRename;
  final VoidCallback onChangeIcon;
  final VoidCallback onMoveTo;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.paddingOf(context).top + 44.0 + 4.0;
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
          child: _DropdownPanel(
            items: [
              _DropdownItem(
                  label: 'Rename',
                  icon: CupertinoIcons.pencil,
                  onTap: onRename),
              _DropdownItem(
                  label: 'Change Icon',
                  icon: CupertinoIcons.photo,
                  onTap: onChangeIcon),
              _DropdownItem(
                  label: 'Move to',
                  icon: CupertinoIcons.folder,
                  onTap: onMoveTo),
              _DropdownItem(
                  label: 'Info',
                  icon: CupertinoIcons.info,
                  onTap: onInfo),
            ],
          ),
        ),
      ],
    );
  }
}

class _DropdownPanel extends StatelessWidget {
  const _DropdownPanel({required this.items});

  final List<_DropdownItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                height: 0.5,
                color: CupertinoColors.separator.resolveFrom(context),
              ),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _DropdownItem extends StatelessWidget {
  const _DropdownItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 17,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: CupertinoColors.destructiveRed,
      child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
    );
  }
}

class _FolderListItem extends StatelessWidget {
  const _FolderListItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isFolder = false,
    this.count,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool isFolder;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            SizedBox(width: 22, height: 22, child: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: isFolder ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (count != null && count! > 0)
              Text(
                '$count',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel
                      .resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          shape: BoxShape.circle,
        ),
        child: Icon(
          CupertinoIcons.folder_badge_plus,
          size: 20,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }
}
