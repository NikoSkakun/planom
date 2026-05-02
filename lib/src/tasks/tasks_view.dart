import 'package:flutter/cupertino.dart';

import '../folders/create_folder_list_sheet.dart';
import '../folders/folder_controller.dart';
import '../folders/folder_view.dart';
import '../folders/list_task_view.dart';
import '../utils/fast_route.dart';
import 'inbox_view.dart';
import 'task_controller.dart';
import 'today_view.dart';

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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Tasks'),
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

                return ListView(
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
                    // Separator below Today
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        height: 0.5,
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                    ),
                    // Root folders
                    ...rootFolders.map((f) => Dismissible(
                          key: ValueKey(f.id),
                          direction: DismissDirection.endToStart,
                          background: _DeleteBackground(),
                          onDismissed: (_) => folderController.deleteFolderDeep(
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
                        )),
                    // Root lists
                    ...rootLists.map((l) {
                      final count = controller.uncompletedCountForList(l.id);
                      return Dismissible(
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
                      );
                    }),
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
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
