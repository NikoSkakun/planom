import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/app_folder.dart';
import '../tasks/task_controller.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
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

class _FolderViewState extends State<FolderView>
    with DropdownOverlayMixin {
  late AppFolder _currentFolder;
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
  }

  void _toggle(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  Widget _buildFolderChildren(
      BuildContext context, String folderId, double indent) {
    final subFolders = widget.folderController.foldersIn(folderId);
    final lists = widget.folderController.listsIn(folderId);
    return Column(
      children: [
        for (final f in subFolders) ...[
          _FolderListItem(
            icon: buildFolderItemIcon(f.iconId, isFolder: true),
            label: f.name,
            isFolder: true,
            indent: indent,
            onTap: () => Navigator.of(context).push(
              FastRoute<void>(
                builder: (_) => FolderView(
                  folder: f,
                  folderController: widget.folderController,
                  taskController: widget.taskController,
                  activeListId: widget.activeListId,
                ),
              ),
            ),
            onExpand: () => _toggle(f.id),
            isExpanded: _expandedIds.contains(f.id),
          ),
          if (_expandedIds.contains(f.id))
            _buildFolderChildren(context, f.id, indent + 24),
        ],
        for (final l in lists) ...[
          _FolderListItem(
            icon: buildFolderItemIcon(l.iconId, isFolder: false),
            label: l.name,
            indent: indent,
            count: widget.taskController.uncompletedCountForList(l.id) > 0
                ? widget.taskController.uncompletedCountForList(l.id)
                : null,
            onTap: () => Navigator.of(context).push(
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
        ],
      ],
    );
  }

  Future<bool> _confirmDelete(String name, {required bool isFolder}) {
    final s = S.of(context);
    return confirmMoveToTrash(
      context,
      name: name,
      isFolder: isFolder,
      body: isFolder ? s.moveToTrashFolderBody : s.moveToTrashListBody,
    );
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
    showDropdown(context, (dismiss) {
      return _FolderOptionsDropdown(
        onDismiss: dismiss,
        onRename: () {
          dismiss();
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
          dismiss();
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
          dismiss();
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
          dismiss();
          showItemInfoSheet(context, creationDate: _currentFolder.creationDate);
        },
        onDelete: () {
          dismiss();
          _deleteThisFolder(context);
        },
      );
    });
  }

  Future<void> _deleteThisFolder(BuildContext context) async {
    final confirmed =
        await _confirmDelete(_currentFolder.name, isFolder: true);
    if (!confirmed || !mounted) return;
    await widget.folderController.deleteFolderDeep(
      _currentFolder.id,
      widget.taskController.deleteTasksForList,
    );
    if (mounted) Navigator.of(context).pop();
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
                  return Center(
                    child: Text(
                      S.of(context).noItems,
                      style: const TextStyle(
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
                              child: Column(
                                children: [
                                  _FolderListItem(
                                    icon: buildFolderItemIcon(
                                      f.iconId,
                                      isFolder: true,
                                    ),
                                    label: f.name,
                                    isFolder: true,
                                    onTap: () => Navigator.of(context).push(
                                      FastRoute<void>(
                                        builder: (_) => FolderView(
                                          folder: f,
                                          folderController:
                                              widget.folderController,
                                          taskController: widget.taskController,
                                          activeListId: widget.activeListId,
                                        ),
                                      ),
                                    ),
                                    onExpand: () => _toggle(f.id),
                                    isExpanded: _expandedIds.contains(f.id),
                                  ),
                                  if (_expandedIds.contains(f.id))
                                    _buildFolderChildren(context, f.id, 24),
                                ],
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
    required this.onDelete,
  });

  final VoidCallback onDismiss;
  final VoidCallback onRename;
  final VoidCallback onChangeIcon;
  final VoidCallback onMoveTo;
  final VoidCallback onInfo;
  final VoidCallback onDelete;

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
                  label: S.of(context).rename,
                  icon: CupertinoIcons.pencil,
                  onTap: onRename),
              _DropdownItem(
                  label: S.of(context).changeIcon,
                  icon: CupertinoIcons.photo,
                  onTap: onChangeIcon),
              _DropdownItem(
                  label: S.of(context).moveTo,
                  icon: CupertinoIcons.folder,
                  onTap: onMoveTo),
              _DropdownItem(
                  label: S.of(context).info,
                  icon: CupertinoIcons.info,
                  onTap: onInfo),
              _DropdownItem(
                  label: S.of(context).delete,
                  icon: CupertinoIcons.trash,
                  onTap: onDelete,
                  color: CupertinoColors.destructiveRed),
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
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: effectiveColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: effectiveColor),
            ),
          ),
        ],
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
    this.onExpand,
    this.isExpanded = false,
    this.indent = 0,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool isFolder;
  final int? count;
  final VoidCallback? onExpand;
  final bool isExpanded;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16 + indent, 9, onExpand != null ? 4 : 16, 9),
                child: Row(
                  children: [
                    SizedBox(width: 22, height: 22, child: icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              isFolder ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (count != null && count! > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (onExpand != null)
            GestureDetector(
              onTap: onExpand,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 48,
                child: Center(
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
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
