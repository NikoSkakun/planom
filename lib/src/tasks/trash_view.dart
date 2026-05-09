import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../models/app_folder.dart';
import '../models/app_list.dart';
import '../models/task.dart';
import 'task_controller.dart';

class TrashView extends StatelessWidget {
  const TrashView({
    super.key,
    required this.taskController,
    required this.folderController,
  });

  final TaskController taskController;
  final FolderController folderController;

  // ── Restore destination helpers ──────────────────────────────────────────

  String _taskDestination(Task task) {
    if (task.listId == null) return 'Inbox';
    final list = folderController.listById(task.listId!);
    return list?.name ?? 'Inbox';
  }

  String? _taskTargetListId(Task task) {
    if (task.listId == null) return null;
    return folderController.listById(task.listId!)?.id;
  }

  String _listDestination(AppList list) {
    if (list.folderId == null) return 'Tasks';
    return folderController.folderById(list.folderId!)?.name ?? 'Tasks';
  }

  String? _listTargetFolderId(AppList list) {
    if (list.folderId == null) return null;
    return folderController.folderById(list.folderId!)?.id;
  }

  String _folderDestination(AppFolder folder) {
    if (folder.parentFolderId == null) return 'Tasks';
    return folderController.folderById(folder.parentFolderId!)?.name ?? 'Tasks';
  }

  String? _folderTargetParentId(AppFolder folder) {
    if (folder.parentFolderId == null) return null;
    return folderController.folderById(folder.parentFolderId!)?.id;
  }

  // ── Confirmation dialogs ─────────────────────────────────────────────────

  Future<bool> _confirmRestore(
      BuildContext context, String label, String destination) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Restore "$label"?'),
        content: Text('This will be moved back to $destination.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Put Back'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmPermanentDelete(
      BuildContext context, String label) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete "$label" permanently?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
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

  Future<bool> _confirmDismiss(
      BuildContext context, DismissDirection direction, _TrashEntry entry) {
    if (direction == DismissDirection.startToEnd) {
      final dest = entry.task != null
          ? _taskDestination(entry.task!)
          : entry.list != null
              ? _listDestination(entry.list!)
              : _folderDestination(entry.folder!);
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

  // ── Menu ─────────────────────────────────────────────────────────────────

  void _showMenu(BuildContext context) {
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
            child: const Text('Empty Trash'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _confirmEmptyTrash(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text(
          'All items in Trash will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await taskController.permanentlyDeleteAllTrashed();
    await folderController.permanentlyDeleteAllTrashed();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
            middle: const Text('Trash'),
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
                ? const Center(
                    child: Text(
                      'Trash is empty',
                      style:
                          TextStyle(color: CupertinoColors.secondaryLabel),
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

// ── Data model ───────────────────────────────────────────────────────────────

class _TrashEntry {
  _TrashEntry.task(Task t)
      : task = t,
        list = null,
        folder = null,
        id = 'task_${t.id}',
        label = t.title,
        deletedDate = t.deletedDate,
        icon = CupertinoIcons.checkmark_square;

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
  final IconData icon;
}

// ── Widgets ──────────────────────────────────────────────────────────────────

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Icon(
            entry.icon,
            size: 20,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
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
