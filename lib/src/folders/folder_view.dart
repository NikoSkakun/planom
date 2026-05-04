import 'package:flutter/cupertino.dart';

import '../models/app_folder.dart';
import '../tasks/task_controller.dart';
import '../utils/fast_route.dart';
import 'create_folder_list_sheet.dart';
import 'folder_controller.dart';
import 'list_task_view.dart';

class FolderView extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(folder.name),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListenableBuilder(
              listenable:
                  Listenable.merge([folderController, taskController]),
              builder: (context, _) {
                final subFolders =
                    folderController.foldersIn(folder.id);
                final lists =
                    folderController.listsIn(folder.id);

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
                            folderController.reorderFolders(
                                folder.id, old, neo),
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
                              onDismissed: (_) =>
                                  folderController.deleteFolderDeep(
                                f.id,
                                taskController.deleteTasksForList,
                              ),
                              child: _FolderListItem(
                                iconAsset: 'assets/icons/folder.png',
                                label: f.name,
                                onTap: () =>
                                    Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => FolderView(
                                      folder: f,
                                      folderController: folderController,
                                      taskController: taskController,
                                      activeListId: activeListId,
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
                            folderController.reorderLists(
                                folder.id, old, neo),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final l = lists[index];
                          final count = taskController
                              .uncompletedCountForList(l.id);
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('fl_${l.id}'),
                            index: index,
                            child: Dismissible(
                              key: ValueKey(l.id),
                              direction: DismissDirection.endToStart,
                              background: _DeleteBackground(),
                              onDismissed: (_) async {
                                await taskController
                                    .deleteTasksForList(l.id);
                                await folderController.deleteList(l.id);
                              },
                              child: _FolderListItem(
                                iconAsset: 'assets/icons/list.png',
                                label: l.name,
                                count: count > 0 ? count : null,
                                onTap: () =>
                                    Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => ListTaskView(
                                      list: l,
                                      taskController: taskController,
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
                  folderController,
                  parentFolderId: folder.id,
                ),
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

class _FolderListItem extends StatelessWidget {
  const _FolderListItem({
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
          CupertinoIcons.plus,
          size: 20,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }
}
