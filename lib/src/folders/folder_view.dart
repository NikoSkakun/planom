import 'package:flutter/cupertino.dart';

import '../contacts/contact_controller.dart';
import '../localization/strings.dart';
import '../models/app_folder.dart';
import '../settings/settings_controller.dart';
import '../tasks/task_controller.dart';
import '../tasks/task_field_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import '../utils/item_info_sheet.dart';
import '../utils/plus_drag_controller.dart';
import '../utils/plus_drag_payload.dart';
import '../utils/undo_controller.dart';
import 'create_folder_list_sheet.dart'
    show
        CreateSheetInitial,
        EditItemArgs,
        showCreateFolderListSheet,
        showEditItemSheet;
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
    required this.contactController,
    required this.activeListId,
    this.settingsController,
  });

  final AppFolder folder;
  final FolderController folderController;
  final TaskController taskController;
  final ContactController contactController;
  final ValueNotifier<String?> activeListId;
  final SettingsController? settingsController;

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

  int? _folderCount(String folderId) {
    final prefs = widget.settingsController?.taskFieldPrefs;
    final mode = prefs?.folderCounterMode ?? FolderCounterMode.directOnly;
    if (mode == FolderCounterMode.hidden) return null;
    final listIds = mode == FolderCounterMode.recursive
        ? widget.folderController.listIdsInRecursive(folderId)
        : widget.folderController.listIdsIn(folderId);
    final count = widget.taskController.uncompletedCountForLists(listIds);
    return count > 0 ? count : null;
  }

  int? _listCount(String listId) {
    final prefs = widget.settingsController?.taskFieldPrefs;
    if (prefs != null && !prefs.showListCount) return null;
    final c = widget.taskController.uncompletedCountForList(listId);
    return c > 0 ? c : null;
  }

  Widget _buildFolderChildren(
      BuildContext context, String folderId, double indent) {
    final s = S.of(context);
    final subFolders = widget.folderController.foldersIn(folderId);
    final lists = widget.folderController.listsIn(folderId);
    return Column(
      children: [
        for (final f in subFolders) ...[
          Dismissible(
            key: ValueKey('exp_folder_${f.id}'),
            direction: DismissDirection.endToStart,
            background: _DeleteBackground(),
            confirmDismiss: (_) => _confirmDelete(f.name, isFolder: true),
            onDismissed: (_) async {
              final undo = UndoScope.maybeOf(context);
              final ts = await widget.folderController.deleteFolderDeep(
                f.id,
                widget.taskController.deleteTasksForList,
              );
              undo?.show(
                label: s.folderTrashedToast,
                onUndo: () async {
                  await widget.folderController.restoreAt(ts);
                  await widget.taskController.restoreAt(ts);
                },
              );
            },
            child: _FolderListItem(
              icon: buildFolderItemIcon(f.iconId,
                  isFolder: true, iconColor: f.iconColor),
              label: f.name,
              isFolder: true,
              indent: indent,
              count: _folderCount(f.id),
              onHoverAutoExpand: () {
                if (!_expandedIds.contains(f.id)) _toggle(f.id);
              },
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => FolderView(
                    folder: f,
                    folderController: widget.folderController,
                    taskController: widget.taskController,
                    contactController: widget.contactController,
                    activeListId: widget.activeListId,
                    settingsController: widget.settingsController,
                  ),
                ),
              ),
              onExpand: () => _toggle(f.id),
              isExpanded: _expandedIds.contains(f.id),
            ),
          ),
          if (_expandedIds.contains(f.id))
            _buildFolderChildren(context, f.id, indent + 24),
        ],
        for (final l in lists) ...[
          Dismissible(
            key: ValueKey('exp_list_${l.id}'),
            direction: DismissDirection.endToStart,
            background: _DeleteBackground(),
            confirmDismiss: (_) => _confirmDelete(l.name, isFolder: false),
            onDismissed: (_) async {
              final undo = UndoScope.maybeOf(context);
              final ts = DateTime.now();
              final savedFolderId = l.folderId;
              await widget.taskController
                  .deleteTasksForList(l.id, ts);
              await widget.folderController.deleteList(l.id);
              undo?.show(
                label: s.listTrashedToast,
                onUndo: () async {
                  await widget.folderController
                      .restoreList(l.id, savedFolderId);
                  await widget.taskController.restoreAt(ts);
                },
              );
            },
            child: _FolderListItem(
              icon: buildFolderItemIcon(l.iconId,
                  isFolder: false, iconColor: l.iconColor),
              label: l.name,
              indent: indent,
              count: _listCount(l.id),
              onAcceptPlus: () =>
                  PlusDragScope.of(context)?.onDropOnList?.call(l.id),
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  builder: (_) => ListTaskView(
                    list: l,
                    taskController: widget.taskController,
                    folderController: widget.folderController,
                    contactController: widget.contactController,
                    activeListId: widget.activeListId,
                  ),
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
        onAddList: () {
          dismiss();
          showCreateFolderListSheet(
            context,
            widget.folderController,
            parentFolderId: _currentFolder.id,
          );
        },
        onAddFolder: () {
          dismiss();
          showCreateFolderListSheet(
            context,
            widget.folderController,
            parentFolderId: _currentFolder.id,
            initialType: CreateSheetInitial.folder,
          );
        },
        onEdit: () {
          dismiss();
          _openEditSheet();
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

  Future<void> _openEditSheet() async {
    final result = await showEditItemSheet(
      context,
      args: EditItemArgs(
        name: _currentFolder.name,
        iconId: _currentFolder.iconId,
        iconColor: _currentFolder.iconColor,
        color: null,
        isFolder: true,
        supportsColor: false,
      ),
    );
    if (result == null || !mounted) return;
    final updated = _currentFolder.copyWith(
      name: result.name,
      iconId: result.iconId,
      clearIconId: result.iconId == null,
      iconColor: result.iconColor,
      clearIconColor: result.iconColor == null,
    );
    await widget.folderController.updateFolder(updated);
    if (mounted) setState(() => _currentFolder = updated);
  }

  Future<void> _deleteThisFolder(BuildContext context) async {
    final s = S.of(context);
    final confirmed =
        await _confirmDelete(_currentFolder.name, isFolder: true);
    if (!confirmed || !mounted) return;
    final undo = UndoScope.maybeOf(context);
    final ts = await widget.folderController.deleteFolderDeep(
      _currentFolder.id,
      widget.taskController.deleteTasksForList,
    );
    undo?.show(
      label: s.folderTrashedToast,
      onUndo: () async {
        await widget.folderController.restoreAt(ts);
        await widget.taskController.restoreAt(ts);
      },
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
              listenable: Listenable.merge([
                widget.folderController,
                widget.taskController,
                if (widget.settingsController != null)
                  widget.settingsController!,
              ]),
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
                            child: Column(
                              children: [
                                Dismissible(
                                  key: ValueKey(f.id),
                                  direction: DismissDirection.endToStart,
                                  background: _DeleteBackground(),
                                  confirmDismiss: (_) =>
                                      _confirmDelete(f.name, isFolder: true),
                                  onDismissed: (_) async {
                                    final undo =
                                        UndoScope.maybeOf(context);
                                    final ts = await widget.folderController
                                        .deleteFolderDeep(
                                      f.id,
                                      widget.taskController
                                          .deleteTasksForList,
                                    );
                                    undo?.show(
                                      label: S
                                          .of(context)
                                          .folderTrashedToast,
                                      onUndo: () async {
                                        await widget.folderController
                                            .restoreAt(ts);
                                        await widget.taskController
                                            .restoreAt(ts);
                                      },
                                    );
                                  },
                                  child: _FolderListItem(
                                    icon: buildFolderItemIcon(
                                      f.iconId,
                                      isFolder: true,
                                      iconColor: f.iconColor,
                                    ),
                                    label: f.name,
                                    isFolder: true,
                                    count: _folderCount(f.id),
                                    onHoverAutoExpand: () {
                                      if (!_expandedIds.contains(f.id)) {
                                        _toggle(f.id);
                                      }
                                    },
                                    onTap: () =>
                                        Navigator.of(context).push(
                                      FastRoute<void>(
                                        builder: (_) => FolderView(
                                          folder: f,
                                          folderController:
                                              widget.folderController,
                                          taskController:
                                              widget.taskController,
                                          contactController:
                                              widget.contactController,
                                          activeListId: widget.activeListId,
                                          settingsController:
                                              widget.settingsController,
                                        ),
                                      ),
                                    ),
                                    onExpand: () => _toggle(f.id),
                                    isExpanded:
                                        _expandedIds.contains(f.id),
                                  ),
                                ),
                                if (_expandedIds.contains(f.id))
                                  _buildFolderChildren(context, f.id, 24),
                              ],
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
                                final undo = UndoScope.maybeOf(context);
                                final ts = DateTime.now();
                                final savedFolderId = l.folderId;
                                await widget.taskController
                                    .deleteTasksForList(l.id, ts);
                                await widget.folderController.deleteList(l.id);
                                undo?.show(
                                  label: S.of(context).listTrashedToast,
                                  onUndo: () async {
                                    await widget.folderController
                                        .restoreList(l.id, savedFolderId);
                                    await widget.taskController.restoreAt(ts);
                                  },
                                );
                              },
                              child: _FolderListItem(
                                icon: buildFolderItemIcon(
                                  l.iconId,
                                  isFolder: false,
                                  iconColor: l.iconColor,
                                ),
                                label: l.name,
                                count: _listCount(l.id),
                                onAcceptPlus: () => PlusDragScope.of(context)
                                    ?.onDropOnList
                                    ?.call(l.id),
                                onTap: () =>
                                    Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => ListTaskView(
                                      list: l,
                                      taskController: widget.taskController,
                                      folderController: widget.folderController,
                                      contactController:
                                          widget.contactController,
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
            if (widget.settingsController == null ||
                widget.settingsController!.smartListPrefs.showAddFolderButton)
              Positioned(
                left: 20,
                bottom: 16,
                child: _CircleButton(
                  onPressed: () => showCreateFolderListSheet(
                    context,
                    widget.folderController,
                    parentFolderId: _currentFolder.id,
                  ),
                  // Dropping the Plus button opens the create sheet scoped
                  // to this folder, so the new list/folder lands inside.
                  onAcceptPlus: () => showCreateFolderListSheet(
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
    required this.onAddList,
    required this.onAddFolder,
    required this.onEdit,
    required this.onMoveTo,
    required this.onInfo,
    required this.onDelete,
  });

  final VoidCallback onDismiss;
  final VoidCallback onAddList;
  final VoidCallback onAddFolder;
  final VoidCallback onEdit;
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
                  label: S.of(context).addList,
                  icon: CupertinoIcons.add_circled,
                  onTap: onAddList),
              _DropdownItem(
                  label: S.of(context).addFolder,
                  icon: CupertinoIcons.folder_badge_plus,
                  onTap: onAddFolder),
              _DropdownItem(
                  label: S.of(context).editFolder,
                  icon: CupertinoIcons.pencil,
                  onTap: onEdit),
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
    this.onAcceptPlus,
    this.onHoverAutoExpand,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool isFolder;
  final int? count;
  final VoidCallback? onExpand;
  final bool isExpanded;
  final double indent;
  final VoidCallback? onAcceptPlus;
  // Folders only — invoked when the Plus button hovers for 1.5s so the
  // user can drill into a nested list.
  final VoidCallback? onHoverAutoExpand;

  @override
  Widget build(BuildContext context) {
    final row = IntrinsicHeight(
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

    if (onHoverAutoExpand != null) {
      return _FolderHoverDropTarget(
        onAutoExpand: onHoverAutoExpand!,
        child: row,
      );
    }
    if (onAcceptPlus == null) return row;
    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) => onAcceptPlus!(),
      builder: (context, candidates, _) {
        return Container(
          decoration: candidates.isEmpty
              ? null
              : BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
          child: row,
        );
      },
    );
  }
}

/// Drop target wrapper for **folder** rows inside FolderView. Mirrors the
/// `_FolderHoverDropTarget` in tasks_view.dart — see comment there for
/// behaviour.
class _FolderHoverDropTarget extends StatefulWidget {
  const _FolderHoverDropTarget({
    required this.onAutoExpand,
    required this.child,
  });

  final VoidCallback onAutoExpand;
  final Widget child;

  static const Duration hoverDuration = Duration(milliseconds: 1500);

  @override
  State<_FolderHoverDropTarget> createState() => _FolderHoverDropTargetState();
}

class _FolderHoverDropTargetState extends State<_FolderHoverDropTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _FolderHoverDropTarget.hoverDuration,
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAutoExpand();
        _ctrl.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) {
        _ctrl.forward(from: 0);
        return true;
      },
      onLeave: (_) {
        _ctrl.stop();
        _ctrl.value = 0;
      },
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Stack(
          children: [
            Container(
              decoration: hovering
                  ? BoxDecoration(
                      color: CupertinoColors.systemGrey4
                          .resolveFrom(context)
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: widget.child,
            ),
            if (hovering)
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) => SizedBox(
                    height: 2,
                    child: Stack(
                      children: [
                        Container(
                          color: CupertinoColors.separator
                              .resolveFrom(context),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _ctrl.value,
                          child: Container(color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.onPressed, this.onAcceptPlus});
  final VoidCallback onPressed;
  final VoidCallback? onAcceptPlus;

  Widget _button(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    if (onAcceptPlus == null) return _button(context);
    return DragTarget<PlusDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (_) => onAcceptPlus!(),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: hovering
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: _button(context),
        );
      },
    );
  }
}
