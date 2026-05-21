import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../models/app_folder.dart';
import '../models/app_list.dart';
import '../models/task.dart';
import 'task_controller.dart';
import 'task_row.dart' show RoundedCheckbox;

class TrashView extends StatelessWidget {
  const TrashView({
    super.key,
    required this.taskController,
    required this.folderController,
  });

  final TaskController taskController;
  final FolderController folderController;

  String _taskDestination(BuildContext context, Task task) {
    final inbox = S.of(context).inbox;
    if (task.listId == null) return inbox;
    final list = folderController.listById(task.listId!);
    return list?.name ?? inbox;
  }

  String? _taskTargetListId(Task task) {
    if (task.listId == null) return null;
    return folderController.listById(task.listId!)?.id;
  }

  String _listDestination(BuildContext context, AppList list) {
    final tasks = S.of(context).tabTasks;
    if (list.folderId == null) return tasks;
    return folderController.folderById(list.folderId!)?.name ?? tasks;
  }

  String? _listTargetFolderId(AppList list) {
    if (list.folderId == null) return null;
    return folderController.folderById(list.folderId!)?.id;
  }

  String _folderDestination(BuildContext context, AppFolder folder) {
    final tasks = S.of(context).tabTasks;
    if (folder.parentFolderId == null) return tasks;
    return folderController.folderById(folder.parentFolderId!)?.name ?? tasks;
  }

  String? _folderTargetParentId(AppFolder folder) {
    if (folder.parentFolderId == null) return null;
    return folderController.folderById(folder.parentFolderId!)?.id;
  }

  Future<bool> _confirmRestore(
      BuildContext context, String label, String destination) async {
    final s = S.of(context);
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.restoreQuestion(label)),
        content: Text(s.restoreBody(destination)),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.putBack),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmPermanentDelete(
      BuildContext context, String label) async {
    final s = S.of(context);
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.deletePermanentlyQuestion(label)),
        content: Text(s.cannotBeUndone),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmDismiss(
      BuildContext context, DismissDirection direction, _TrashEntry entry) {
    if (direction == DismissDirection.startToEnd) {
      final dest = entry.task != null
          ? _taskDestination(context, entry.task!)
          : entry.list != null
              ? _listDestination(context, entry.list!)
              : _folderDestination(context, entry.folder!);
      return _confirmRestore(context, entry.label, dest);
    }
    return _confirmPermanentDelete(context, entry.label);
  }

  void _handleDismissed(DismissDirection direction, _TrashEntry entry) {
    if (direction == DismissDirection.startToEnd) {
      if (entry.task != null) {
        taskController.restoreTask(
            entry.task!.id, _taskTargetListId(entry.task!));
      } else if (entry.list != null) {
        folderController.restoreList(
            entry.list!.id, _listTargetFolderId(entry.list!));
      } else if (entry.folder != null) {
        folderController.restoreFolder(
            entry.folder!.id, _folderTargetParentId(entry.folder!));
      }
    } else {
      if (entry.task != null) {
        taskController.permanentlyDeleteTask(entry.task!.id);
      } else if (entry.list != null) {
        folderController.permanentlyDeleteList(entry.list!.id);
      } else if (entry.folder != null) {
        folderController.permanentlyDeleteFolder(entry.folder!.id);
      }
    }
  }

  void _showMenu(BuildContext context) {
    final s = S.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmEmptyTrash(context);
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(s.emptyTrash, textAlign: TextAlign.left),
                ),
                const Icon(CupertinoIcons.trash,
                    size: 18, color: CupertinoColors.destructiveRed),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.cancel),
        ),
      ),
    );
  }

  Future<void> _confirmEmptyTrash(BuildContext context) async {
    final s = S.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.emptyTrashQuestion),
        content: Text(s.emptyTrashBody),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.deleteAll),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await taskController.permanentlyDeleteAllTrashed();
    await folderController.permanentlyDeleteAllTrashed();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([taskController, folderController]),
      builder: (context, _) {
        final tasks = taskController.trashedTasks;
        final lists = folderController.trashedLists;
        final folders = folderController.trashedFolders;
        final isEmpty = tasks.isEmpty && lists.isEmpty && folders.isEmpty;

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            border: null,
            middle: Text(s.trash),
            trailing: isEmpty
                ? null
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: () => _showMenu(context),
                    child: const Icon(CupertinoIcons.ellipsis_circle),
                  ),
          ),
          child: SafeArea(
            child: isEmpty
                ? Center(
                    child: Text(
                      s.trashIsEmpty,
                      style: const TextStyle(
                          color: CupertinoColors.secondaryLabel),
                    ),
                  )
                : Builder(builder: (context) {
                    final entries = <_TrashEntry>[
                      for (final t in tasks) _TrashEntry.task(t),
                      for (final l in lists) _TrashEntry.list(l),
                      for (final f in folders) _TrashEntry.folder(f),
                    ]..sort((a, b) {
                        final da = a.deletedDate ?? DateTime(0);
                        final db = b.deletedDate ?? DateTime(0);
                        return db.compareTo(da);
                      });
                    return CustomScrollView(
                      slivers: [
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final entry = entries[i];
                              return Dismissible(
                                key: ValueKey(entry.id),
                                direction: DismissDirection.horizontal,
                                background: const _PutBackBackground(),
                                secondaryBackground: const _DeleteBackground(),
                                confirmDismiss: (direction) =>
                                    _confirmDismiss(context, direction, entry),
                                onDismissed: (direction) =>
                                    _handleDismissed(direction, entry),
                                child: _TrashRow(entry: entry),
                              );
                            },
                            childCount: entries.length,
                          ),
                        ),
                      ],
                    );
                  }),
          ),
        );
      },
    );
  }
}

class _TrashEntry {
  _TrashEntry.task(Task t)
      : task = t,
        list = null,
        folder = null,
        id = 'task_${t.id}',
        label = t.title,
        deletedDate = t.deletedDate,
        icon = null;

  _TrashEntry.list(AppList l)
      : task = null,
        list = l,
        folder = null,
        id = 'list_${l.id}',
        label = l.name,
        deletedDate = l.deletedDate,
        icon = CupertinoIcons.list_bullet;

  _TrashEntry.folder(AppFolder f)
      : task = null,
        list = null,
        folder = f,
        id = 'folder_${f.id}',
        label = f.name,
        deletedDate = f.deletedDate,
        icon = CupertinoIcons.folder;

  final Task? task;
  final AppList? list;
  final AppFolder? folder;
  final String id;
  final String label;
  final DateTime? deletedDate;
  final IconData? icon;
}

class _PutBackBackground extends StatelessWidget {
  const _PutBackBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20),
      color: CupertinoColors.activeBlue,
      child: const Icon(CupertinoIcons.arrow_uturn_left,
          color: CupertinoColors.white),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

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

class _TrashRow extends StatelessWidget {
  const _TrashRow({required this.entry});
  final _TrashEntry entry;

  @override
  Widget build(BuildContext context) {
    final task = entry.task;
    final Widget leadingIcon = task != null
        ? RoundedCheckbox(
            checked: task.isCompleted,
            priority: task.priority,
          )
        : Icon(
            entry.icon,
            size: 20,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          leadingIcon,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.label,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
