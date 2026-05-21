import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/app_list.dart';
import '../tasks/task_controller.dart';
import '../tasks/task_detail_view.dart';
import '../tasks/task_row.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import '../utils/item_info_sheet.dart';
import 'create_folder_list_sheet.dart';
import 'folder_controller.dart';
import 'folder_icon_picker.dart';
import 'list_color_picker.dart';
import 'move_to_sheet.dart';

class ListTaskView extends StatefulWidget {
  const ListTaskView({
    super.key,
    required this.list,
    required this.taskController,
    required this.folderController,
    required this.activeListId,
  });

  final AppList list;
  final TaskController taskController;
  final FolderController folderController;
  final ValueNotifier<String?> activeListId;

  @override
  State<ListTaskView> createState() => _ListTaskViewState();
}

class _ListTaskViewState extends State<ListTaskView>
    with DropdownOverlayMixin {
  late AppList _currentList;

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.activeListId.value = widget.list.id;
    });
  }

  @override
  void dispose() {
    widget.activeListId.value = null;
    super.dispose();
  }

  void _showDropdown(BuildContext context) {
    showDropdown(context, (dismiss) {
      return _ListOptionsDropdown(
        onDismiss: dismiss,
        onRename: () {
          dismiss();
          showRenameSheet(
            context,
            currentName: _currentList.name,
            onRename: (name) async {
              final updated = _currentList.copyWith(name: name);
              await widget.folderController.updateList(updated);
              if (mounted) setState(() => _currentList = updated);
            },
          );
        },
        onChangeColor: () {
          dismiss();
          showListColorPickerSheet(context, _currentList.color, (color) {
            final updated = _currentList.copyWith(
              color: color,
              clearColor: color == null,
            );
            widget.folderController.updateList(updated);
            if (mounted) setState(() => _currentList = updated);
          });
        },
        onChangeIcon: () {
          dismiss();
          showFolderIconPickerSheet(
            context,
            currentIconId: _currentList.iconId,
            isFolder: false,
            onSelected: (id) {
              final updated = _currentList.copyWith(
                iconId: id,
                clearIconId: id == null,
              );
              widget.folderController.updateList(updated);
              if (mounted) setState(() => _currentList = updated);
            },
          );
        },
        onMoveTo: () {
          dismiss();
          showMoveToSheet(
            context,
            folderController: widget.folderController,
            currentParentId: _currentList.folderId,
            onMove: (folderId) async {
              final updated = folderId == null
                  ? _currentList.copyWith(clearFolder: true)
                  : _currentList.copyWith(folderId: folderId);
              await widget.folderController.updateList(updated);
              if (mounted) setState(() => _currentList = updated);
            },
          );
        },
        onInfo: () {
          dismiss();
          showItemInfoSheet(context, creationDate: _currentList.creationDate);
        },
        onDelete: () {
          dismiss();
          _deleteThisList(context);
        },
      );
    });
  }

  Future<void> _deleteThisList(BuildContext context) async {
    final confirmed = await confirmMoveToTrash(
      context,
      name: _currentList.name,
      body: S.of(context).moveToTrashListBody,
    );
    if (!confirmed || !mounted) return;
    await widget.taskController.deleteTasksForList(_currentList.id);
    await widget.folderController.deleteList(_currentList.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(_currentList.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showDropdown(context),
          child: const Icon(CupertinoIcons.ellipsis, size: 26),
        ),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.taskController,
          builder: (context, _) {
            final tasks =
                widget.taskController.tasksForList(widget.list.id);
            final canReorder = widget.taskController.sortOrder ==
                TaskSortOrder.defaultOrder;

            if (tasks.isEmpty) {
              return Center(
                child: Text(
                  S.of(context).noTasks,
                  style:
                      const TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverReorderableList(
                  itemCount: tasks.length,
                  onReorder: canReorder
                      ? (old, neo) =>
                          widget.taskController.reorderTasks(
                            listId: widget.list.id,
                            oldIndex: old,
                            newIndex: neo,
                          )
                      : (_, __) {},
                  proxyDecorator: taskProxyDecorator,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('list_task_${task.id}'),
                      index: i,
                      enabled: canReorder,
                      child: Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: const TaskDeleteBackground(),
                        onDismissed: (_) =>
                            widget.taskController.deleteTask(task.id),
                        child: TaskRow(
                          task: task,
                          onToggle: () => widget.taskController
                              .toggleCompleted(task.id),
                          onTap: () => Navigator.of(context).push(
                            FastRoute<void>(
                              settings: const RouteSettings(
                                  name: TaskDetailView.routeName),
                              builder: (_) => TaskDetailView(
                                task: task,
                                controller: widget.taskController,
                                folderController: widget.folderController,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ListOptionsDropdown extends StatelessWidget {
  const _ListOptionsDropdown({
    required this.onDismiss,
    required this.onRename,
    required this.onChangeColor,
    required this.onChangeIcon,
    required this.onMoveTo,
    required this.onInfo,
    required this.onDelete,
  });

  final VoidCallback onDismiss;
  final VoidCallback onRename;
  final VoidCallback onChangeColor;
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
                  label: S.of(context).changeColor,
                  icon: CupertinoIcons.paintbrush_fill,
                  onTap: onChangeColor),
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: effectiveColor),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 17, color: effectiveColor),
          ],
        ),
      ),
    );
  }
}
