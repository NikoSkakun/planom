import 'package:flutter/cupertino.dart';

import '../folders/create_folder_list_sheet.dart';
import '../folders/folder_controller.dart';
import '../folders/folder_view.dart';
import '../folders/list_task_view.dart';
import '../utils/fast_route.dart';
import 'inbox_view.dart';
import 'task_controller.dart';
import 'today_view.dart';
import 'upcoming_view.dart';

class TasksView extends StatelessWidget {
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

  void _showSortSheet(BuildContext context) {
    final current = controller.sortOrder;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Sort Tasks'),
        actions: TaskSortOrder.values.map((order) {
          final label = _sortLabel(order);
          final isSelected = order == current;
          return CupertinoActionSheetAction(
            onPressed: () {
              controller.setSortOrder(order);
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(border: null,
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
              listenable: Listenable.merge([controller, folderController]),
              builder: (context, _) {
                final rootFolders = folderController.foldersIn(null);
                final rootLists = folderController.listsIn(null);
                final todayCount = controller.todayUncompletedCount;
                final upcomingCount = controller.upcomingUncompletedCount;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _ListItem(
                            iconAsset: 'assets/icons/inbox.png',
                            label: 'Inbox',
                            count: controller.inboxUncompletedCount,
                            onTap: () => Navigator.of(context).push(
                              FastRoute<void>(
                                builder: (_) => InboxView(
                                  controller: controller,
                                  folderController: folderController,
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
                                  controller: controller,
                                  folderController: folderController,
                                  activeDueDate: activeDueDate,
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
                                  controller: controller,
                                  folderController: folderController,
                                ),
                              ),
                            ),
                          ),
                          // Separator
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
                            folderController.reorderFolders(
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
                              onDismissed: (_) =>
                                  folderController.deleteFolderDeep(
                                f.id,
                                controller.deleteTasksForList,
                              ),
                              child: _ListItem(
                                iconAsset: 'assets/icons/folder.png',
                                label: f.name,
                                onTap: () => Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => FolderView(
                                      folder: f,
                                      folderController: folderController,
                                      taskController: controller,
                                      activeListId: activeListId,
                                    ),
                                  ),
                                ),
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
                            folderController.reorderLists(
                                null, oldIndex, newIndex),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final l = rootLists[index];
                          final count =
                              controller.uncompletedCountForList(l.id);
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('list_${l.id}'),
                            index: index,
                            child: Dismissible(
                              key: ValueKey(l.id),
                              direction: DismissDirection.endToStart,
                              background: _DeleteBackground(),
                              onDismissed: (_) async {
                                await controller.deleteTasksForList(l.id);
                                await folderController.deleteList(l.id);
                              },
                              child: _ListItem(
                                iconAsset: 'assets/icons/list.png',
                                label: l.name,
                                count: count > 0 ? count : null,
                                onTap: () => Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => ListTaskView(
                                      list: l,
                                      taskController: controller,
                                      folderController: folderController,
                                      activeListId: activeListId,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
                onPressed: () =>
                    showCreateFolderListSheet(context, folderController),
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
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.count,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;
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
            Image.asset(iconAsset, width: 22, height: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 17)),
            ),
            if (count != null && count! > 0)
              Text(
                '$count',
                style: TextStyle(
                  color:
                      CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
          ],
        ),
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          CupertinoIcons.plus,
          size: 20,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }
}
