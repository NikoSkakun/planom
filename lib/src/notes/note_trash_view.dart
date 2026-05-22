import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../utils/selection_menu.dart';
import 'note_controller.dart';

class NoteTrashView extends StatelessWidget {
  const NoteTrashView({super.key, required this.controller});

  final NoteController controller;

  String _noteDestination(BuildContext context, Note note) {
    final notes = S.of(context).tabNotes;
    if (note.folderId == null) return notes;
    return controller.folderById(note.folderId!)?.name ?? notes;
  }

  String? _noteTargetFolderId(Note note) {
    if (note.folderId == null) return null;
    return controller.folderById(note.folderId!)?.id;
  }

  String _folderDestination(BuildContext context, NoteFolder folder) {
    final notes = S.of(context).tabNotes;
    if (folder.parentFolderId == null) return notes;
    return controller.folderById(folder.parentFolderId!)?.name ?? notes;
  }

  String? _folderTargetParentId(NoteFolder folder) {
    if (folder.parentFolderId == null) return null;
    return controller.folderById(folder.parentFolderId!)?.id;
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
      final dest = entry.note != null
          ? _noteDestination(context, entry.note!)
          : _folderDestination(context, entry.folder!);
      return _confirmRestore(context, entry.label, dest);
    }
    return _confirmPermanentDelete(context, entry.label);
  }

  void _handleDismissed(DismissDirection direction, _TrashEntry entry) {
    if (direction == DismissDirection.startToEnd) {
      if (entry.note != null) {
        controller.restoreNote(
            entry.note!.id, _noteTargetFolderId(entry.note!));
      } else if (entry.folder != null) {
        controller.restoreFolder(
            entry.folder!.id, _folderTargetParentId(entry.folder!));
      }
    } else {
      if (entry.note != null) {
        controller.permanentlyDeleteNote(entry.note!.id);
      } else if (entry.folder != null) {
        controller.permanentlyDeleteFolder(entry.folder!.id);
      }
    }
  }

  Future<void> _showMenu(BuildContext context) async {
    final s = S.of(context);
    final choice = await showSelectionMenu<String>(
      context: context,
      options: [
        SelectionMenuOption(
          value: 'empty',
          label: s.emptyTrash,
          icon: CupertinoIcons.trash,
          isDestructive: true,
        ),
      ],
    );
    if (choice == 'empty') _confirmEmptyTrash(context);
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
    await controller.permanentlyDeleteAllTrashed();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final notes = controller.trashedNotes;
        final folders = controller.trashedFolders;
        final isEmpty = notes.isEmpty && folders.isEmpty;

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
                      for (final n in notes)
                        _TrashEntry.note(
                            n, n.title.isNotEmpty ? n.title : s.untitled),
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
                                secondaryBackground:
                                    const _DeleteBackground(),
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
  _TrashEntry.note(Note n, String displayLabel)
      : note = n,
        folder = null,
        id = 'note_${n.id}',
        label = displayLabel,
        deletedDate = n.deletedDate,
        icon = CupertinoIcons.doc_text;

  _TrashEntry.folder(NoteFolder f)
      : note = null,
        folder = f,
        id = 'folder_${f.id}',
        label = f.name,
        deletedDate = f.deletedDate,
        icon = CupertinoIcons.folder;

  final Note? note;
  final NoteFolder? folder;
  final String id;
  final String label;
  final DateTime? deletedDate;
  final IconData icon;
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
                color:
                    CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
