import 'package:flutter/cupertino.dart';

import '../folders/create_folder_list_sheet.dart';
import '../folders/folder_controller.dart';
import '../folders/folder_icon_picker.dart';
import '../folders/folder_view.dart';
import '../folders/list_task_view.dart';
import '../utils/fast_route.dart';
// KEEP: import for Completed smart list — re-enable when the list is shown again.
// import 'completed_view.dart';
import 'inbox_view.dart';
import 'task_controller.dart';
import 'today_view.dart';
import 'trash_view.dart';
import 'upcoming_view.dart';

class TasksView extends StatefulWidget {
  const TasksView({
    super.key,
    required this.controller,
    required this.folderController,
    required this.activeListId,
    required this.activeDueDate,
  });

  final TaskController controller;
  final FolderController folderController;
  final ValueNotifier<String?> activeListId;
  final ValueNotifier<DateTime?> activeDueDate;

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  final Set<String> _expandedIds = {};

  void _toggle(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  void _showSortSheet(BuildContext context) {
    final current = widget.controller.sortOrder;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Sort Tasks'),
        actions: TaskSortOrder.values.map((order) {
          final label = _sortLabel(order);
          final isSelected = order == current;
          return CupertinoActionSheetAction(
            onPressed: () {
              widget.controller.setSortOrder(order);
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark,
                        size: 16, color: CupertinoColors.activeBlue),
                  ),
                Text(
                  label,
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

  static String _sortLabel(TaskSortOrder order) {
    switch (order) {
      case TaskSortOrder.defaultOrder:
        return 'Default';
      case TaskSortOrder.creationDate:
        return 'By Creation Date';
      case TaskSortOrder.name:
        return 'By Name';
      case TaskSortOrder.priority:
        return 'By Priority';
      case TaskSortOrder.dateTime:
        return 'By Date & Time';
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String name,
      {required bool isFolder}) async {
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

  Widget _buildFolderChildren(
      BuildContext context, String folderId, double indent) {
    final subFolders = widget.folderController.foldersIn(folderId);
    final lists = widget.folderController.listsIn(folderId);

    return Column(
      children: [
        for (final f in subFolders) ...[
          _ListItem(
            iconAsset: 'assets/icons/folder.png',
            iconId: f.iconId,
            isFolder: true,
            label: f.name,
            indent: indent,
            onTap: () => Navigator.of(context).push(
              FastRoute<void>(
                builder: (_) => FolderView(
                  folder: f,
                  folderController: widget.folderController,
                  taskController: widget.controller,
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
          _ListItem(
            iconAsset: 'assets/icons/list.png',
            iconId: l.iconId,
            isFolder: false,
            label: l.name,
            indent: indent,
            count: widget.controller.uncompletedCountForList(l.id) > 0
                ? widget.controller.uncompletedCountForList(l.id)
                : null,
            onTap: () => Navigator.of(context).push(
              FastRoute<void>(
                builder: (_) => ListTaskView(
                  list: l,
                  taskController: widget.controller,
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: const Text('Tasks'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showSortSheet(context),
          child: const Icon(CupertinoIcons.arrow_up_arrow_down, size: 20),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: Listenable.merge(
                  [widget.controller, widget.folderController]),
              builder: (context, _) {
                final rootFolders =
                    widget.folderController.foldersIn(null);
                final rootLists = widget.folderController.listsIn(null);
                final todayCount = widget.controller.todayUncompletedCount;
                final upcomingCount =
                    widget.controller.upcomingUncompletedCount;
                // KEEP: re-enable when Completed smart list is shown again.
                // final completedCount = widget.controller.completedTasksCount;
                final hasTrash =
                    widget.controller.trashedTasks.isNotEmpty ||
                        widget.folderController.trashedFolders.isNotEmpty ||
                        widget.folderController.trashedLists.isNotEmpty;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _ListItem(
                            iconAsset: 'assets/icons/inbox.png',
                            label: 'Inbox',
                            count: widget.controller.inboxUncompletedCount,
                            onTap: () => Navigator.of(context).push(
                              FastRoute<void>(
                                builder: (_) => InboxView(
                                  controller: widget.controller,
                                  folderController: widget.folderController,
                                ),
                              ),
                            ),
                          ),
                          _ListItem(
                            iconAsset: 'assets/icons/today.png',
                            label: 'Today',
                            count: todayCount > 0 ? todayCount : null,
                            onTap: () => Navigator.of(context).push(
                              FastRoute<void>(
                                builder: (_) => TodayView(
                                  controller: widget.controller,
                                  folderController: widget.folderController,
                                  activeDueDate: widget.activeDueDate,
                                ),
                              ),
                            ),
                          ),
                          _ListItem(
                            iconAsset: 'assets/icons/upcoming.png',
                            label: 'Upcoming',
                            count: upcomingCount > 0 ? upcomingCount : null,
                            onTap: () => Navigator.of(context).push(
                              FastRoute<void>(
                                builder: (_) => UpcomingView(
                                  controller: widget.controller,
                                  folderController: widget.folderController,
                                ),
                              ),
                            ),
                          ),
                          // Separator between smart lists and user folders/lists
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Container(
                              height: 0.5,
                              color: CupertinoColors.separator
                                  .resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Reorderable folders
                    if (rootFolders.isNotEmpty)
                      SliverReorderableList(
                        itemCount: rootFolders.length,
                        onReorder: (oldIndex, newIndex) =>
                            widget.folderController.reorderFolders(
                                null, oldIndex, newIndex),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final f = rootFolders[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('folder_${f.id}'),
                            index: index,
                            child: Dismissible(
                              key: ValueKey(f.id),
                              direction: DismissDirection.endToStart,
                              background: _DeleteBackground(),
                              confirmDismiss: (_) => _confirmDelete(
                                  context, f.name,
                                  isFolder: true),
                              onDismissed: (_) =>
                                  widget.folderController.deleteFolderDeep(
                                f.id,
                                widget.controller.deleteTasksForList,
                              ),
                              child: Column(
                                children: [
                                  _ListItem(
                                    iconAsset: 'assets/icons/folder.png',
                                    iconId: f.iconId,
                                    isFolder: true,
                                    label: f.name,
                                    onTap: () =>
                                        Navigator.of(context).push(
                                      FastRoute<void>(
                                        builder: (_) => FolderView(
                                          folder: f,
                                          folderController:
                                              widget.folderController,
                                          taskController: widget.controller,
                                          activeListId: widget.activeListId,
                                        ),
                                      ),
                                    ),
                                    onExpand: () => _toggle(f.id),
                                    isExpanded:
                                        _expandedIds.contains(f.id),
                                  ),
                                  if (_expandedIds.contains(f.id))
                                    _buildFolderChildren(
                                        context, f.id, 24),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Reorderable lists
                    if (rootLists.isNotEmpty)
                      SliverReorderableList(
                        itemCount: rootLists.length,
                        onReorder: (oldIndex, newIndex) =>
                            widget.folderController.reorderLists(
                                null, oldIndex, newIndex),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final l = rootLists[index];
                          final count =
                              widget.controller.uncompletedCountForList(l.id);
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('list_${l.id}'),
                            index: index,
                            child: Dismissible(
                              key: ValueKey(l.id),
                              direction: DismissDirection.endToStart,
                              background: _DeleteBackground(),
                              confirmDismiss: (_) => _confirmDelete(
                                  context, l.name,
                                  isFolder: false),
                              onDismissed: (_) async {
                                await widget.controller
                                    .deleteTasksForList(l.id);
                                await widget.folderController.deleteList(l.id);
                              },
                              child: _ListItem(
                                iconAsset: 'assets/icons/list.png',
                                iconId: l.iconId,
                                isFolder: false,
                                label: l.name,
                                count: count > 0 ? count : null,
                                onTap: () => Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => ListTaskView(
                                      list: l,
                                      taskController: widget.controller,
                                      folderController:
                                          widget.folderController,
                                      activeListId: widget.activeListId,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // Bottom section: Completed + Trash smart lists
                    if (hasTrash)
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Container(
                                height: 0.5,
                                color: CupertinoColors.separator
                                    .resolveFrom(context),
                              ),
                            ),
                            // KEEP: Completed smart list — hidden for now, will be re-enabled later.
                            // if (completedCount > 0)
                            //   _ListItem(
                            //     iconWidget: const Icon(
                            //       CupertinoIcons.checkmark_circle_fill,
                            //       size: 22,
                            //       color: Color(0xFF34C759),
                            //     ),
                            //     label: 'Completed',
                            //     onTap: () => Navigator.of(context).push(
                            //       FastRoute<void>(
                            //         builder: (_) => CompletedView(
                            //           controller: widget.controller,
                            //           folderController: widget.folderController,
                            //         ),
                            //       ),
                            //     ),
                            //   ),
                            _ListItem(
                              iconWidget: Icon(
                                CupertinoIcons.trash,
                                size: 22,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                              label: 'Trash',
                              onTap: () => Navigator.of(context).push(
                                FastRoute<void>(
                                  builder: (_) => TrashView(
                                    taskController: widget.controller,
                                    folderController: widget.folderController,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                );
              },
            ),
            Positioned(
              left: 20,
              bottom: 16,
              child: _CircleAddButton(
                onPressed: () => showCreateFolderListSheet(
                    context, widget.folderController),
              ),
            ),
          ],
        ),
      ),
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

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.label,
    required this.onTap,
    this.iconAsset,
    this.iconWidget,
    this.iconId,
    this.isFolder = false,
    this.count,
    this.onExpand,
    this.isExpanded = false,
    this.indent = 0,
  });

  final String? iconAsset;
  final Widget? iconWidget;
  final String? iconId;
  final bool isFolder;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final VoidCallback? onExpand;
  final bool isExpanded;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    if (iconWidget != null) {
      icon = iconWidget!;
    } else if (iconId != null) {
      icon = buildFolderItemIcon(iconId, isFolder: isFolder);
    } else {
      icon = Image.asset(iconAsset!, width: 22, height: 22);
    }

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
                        fontWeight: isFolder
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (count != null && count! > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: TextStyle(
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
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context),
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

class _CircleAddButton extends StatelessWidget {
  const _CircleAddButton({required this.onPressed});
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
