import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../settings/settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import '../utils/item_info_sheet.dart';
import '../utils/reorder_drag.dart';
import '../utils/selection_checkbox.dart';
import '../utils/selection_controller.dart';
import '../utils/selection_toolbar.dart';
import '../utils/undo_controller.dart';
import '../folders/create_folder_list_sheet.dart'
    show EditItemArgs, showEditItemSheet;
import '../folders/move_to_sheet.dart';
import 'create_note_folder_sheet.dart';
import 'note_controller.dart';
import 'note_detail_view.dart';
import 'note_widgets.dart';

class NoteFolderView extends StatefulWidget {
  const NoteFolderView({
    super.key,
    required this.folder,
    required this.controller,
    this.settingsController,
  });

  final NoteFolder folder;
  final NoteController controller;
  final SettingsController? settingsController;

  @override
  State<NoteFolderView> createState() => _NoteFolderViewState();
}

class _NoteFolderViewState extends State<NoteFolderView>
    with DropdownOverlayMixin {
  late NoteFolder _currentFolder;
  final Set<String> _expandedIds = {};
  final _selection = SelectionController();

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  // ── Batch actions ────────────────────────────────────────────────────────

  Future<void> _batchDeleteNotes() async {
    for (final id in _selection.selectedIds.toList()) {
      await widget.controller.deleteNote(id);
    }
    _selection.cancel();
  }

  Future<void> _batchDeleteFolders() async {
    for (final id in _selection.selectedIds.toList()) {
      await widget.controller.deleteFolderDeep(id);
    }
    _selection.cancel();
  }

  Future<void> _batchDuplicateNotes() async {
    for (final id in _selection.selectedIds.toList()) {
      final n = widget.controller.noteById(id);
      if (n == null) continue;
      await widget.controller.addNote(Note(
        title: n.title,
        content: n.content,
        folderId: n.folderId,
      ));
    }
    _selection.cancel();
  }

  /// Wraps a NoteRow in selection mode so taps toggle selection.
  Widget _wrapNoteForSelection(Note n, Widget child) {
    if (!_selection.active) return child;
    final selected = _selection.isSelected(n.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selection.toggle(n.id, SelectionItemKind.note),
      child: Container(
        color: selected ? AppColors.accent.withOpacity(0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SelectionCheckbox(checked: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                n.title.isEmpty ? S.of(context).untitled : n.title,
                style: const TextStyle(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapFolderForSelection(NoteFolder f, Widget child) {
    if (!_selection.active) return child;
    final selected = _selection.isSelected(f.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selection.toggle(f.id, SelectionItemKind.folder),
      child: Container(
        color: selected ? AppColors.accent.withOpacity(0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SelectionCheckbox(checked: selected),
            const SizedBox(width: 12),
            Icon(
              CupertinoIcons.folder,
              size: 22,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                f.name,
                style: const TextStyle(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SelectionAction> _buildBatchActions(S s) {
    final empty = _selection.isEmpty;
    final kind = _selection.kind;
    if (kind == SelectionItemKind.folder) {
      return [
        SelectionAction(
          label: s.delete,
          icon: CupertinoIcons.trash,
          onTap: empty ? () {} : _batchDeleteFolders,
          isDestructive: true,
        ),
      ];
    }
    return [
      SelectionAction(
        label: s.duplicate,
        icon: CupertinoIcons.doc_on_doc,
        onTap: empty ? () {} : _batchDuplicateNotes,
      ),
      SelectionAction(
        label: s.delete,
        icon: CupertinoIcons.trash,
        onTap: empty ? () {} : _batchDeleteNotes,
        isDestructive: true,
      ),
    ];
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
    final s = S.of(context);
    final subFolders = widget.controller.foldersIn(folderId);
    final notes = widget.controller.notesIn(folderId);
    return Column(
      children: [
        for (final f in subFolders) ...[
          Dismissible(
            key: ValueKey('exp_nf_${f.id}'),
            direction: DismissDirection.endToStart,
            background: const NoteDeleteBackground(),
            onDismissed: (_) async {
              final undo = UndoScope.maybeOf(context);
              final ts = await widget.controller.deleteFolderDeep(f.id);
              undo?.show(
                label: s.noteFolderTrashedToast,
                onUndo: () => widget.controller.restoreAt(ts),
              );
            },
            child: DragTarget<NoteDragData>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (d) =>
                  widget.controller.moveNote(d.data.noteId, f.id),
              builder: (ctx, cand, __) {
                final hl = cand.isNotEmpty;
                return Container(
                  decoration: hl
                      ? BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: NoteFolderRow(
                    folder: f,
                    noteCount: widget.controller.notesIn(f.id).length,
                    indent: indent,
                    onTap: () => Navigator.of(context).push(
                      FastRoute<void>(
                        builder: (_) => NoteFolderView(
                          folder: f,
                          controller: widget.controller,
                          settingsController: widget.settingsController,
                        ),
                      ),
                    ),
                    onExpand: () => _toggle(f.id),
                    isExpanded: _expandedIds.contains(f.id),
                  ),
                );
              },
            ),
          ),
          if (_expandedIds.contains(f.id))
            _buildFolderChildren(context, f.id, indent + 24),
        ],
        for (final n in notes)
          Dismissible(
            key: ValueKey('exp_note_${n.id}'),
            direction: DismissDirection.endToStart,
            background: const NoteDeleteBackground(),
            onDismissed: (_) {
              final savedFolderId = n.folderId;
              widget.controller.deleteNote(n.id);
              UndoScope.maybeOf(context)?.show(
                label: s.noteTrashedToast,
                onUndo: () =>
                    widget.controller.restoreNote(n.id, savedFolderId),
              );
            },
            child: NoteRow(
              note: n,
              indent: indent,
              onTap: () => Navigator.of(context).push(
                FastRoute<void>(
                  settings:
                      const RouteSettings(name: NoteDetailView.routeName),
                  builder: (_) => NoteDetailView(
                    note: n,
                    controller: widget.controller,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openEditSheet() async {
    final result = await showEditItemSheet(
      context,
      args: EditItemArgs(
        name: _currentFolder.name,
        iconId: _currentFolder.iconId,
        iconColor: null,
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
    );
    await widget.controller.updateFolder(updated);
    if (mounted) setState(() => _currentFolder = updated);
  }

  void _showDropdown(BuildContext context) {
    showDropdown(context, (dismiss) {
      return _NoteFolderOptionsDropdown(
        onDismiss: dismiss,
        onSelect: () {
          dismiss();
          _selection.start();
        },
        onAddNote: () {
          dismiss();
          Navigator.of(context).push(
            FastRoute<void>(
              settings:
                  const RouteSettings(name: NoteDetailView.routeName),
              builder: (_) => NoteDetailView(
                note: Note(
                    title: '', content: '', folderId: _currentFolder.id),
                controller: widget.controller,
                isNew: true,
              ),
            ),
          );
        },
        onAddFolder: () {
          dismiss();
          showCreateNoteFolderSheet(
            context,
            widget.controller,
            parentFolderId: _currentFolder.id,
          );
        },
        onEdit: () {
          dismiss();
          _openEditSheet();
        },
        onMoveTo: () {
          dismiss();
          showNoteMoveToSheet(
            context,
            noteController: widget.controller,
            currentParentId: _currentFolder.parentFolderId,
            excludeFolderId: _currentFolder.id,
            onMove: (folderId) async {
              final updated = folderId == null
                  ? _currentFolder.copyWith(clearParent: true)
                  : _currentFolder.copyWith(parentFolderId: folderId);
              await widget.controller.updateFolder(updated);
              if (mounted) setState(() => _currentFolder = updated);
            },
          );
        },
        onInfo: () {
          dismiss();
          showItemInfoSheet(context, creationDate: _currentFolder.creationDate);
        },
        onDelete: () async {
          dismiss();
          final undo = UndoScope.maybeOf(context);
          final ts = await widget.controller
              .deleteFolderDeep(_currentFolder.id);
          undo?.show(
            label: S.of(context).noteFolderTrashedToast,
            onUndo: () => widget.controller.restoreAt(ts),
          );
          if (mounted) Navigator.of(context).pop();
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        final selecting = _selection.active;
        final s = S.of(context);
        final subFolders =
            widget.controller.foldersIn(_currentFolder.id);
        final notes = widget.controller.notesIn(_currentFolder.id);
        final hasMixed = subFolders.isNotEmpty && notes.isNotEmpty;
        final selectKind = _selection.kind;
        Iterable<String>? selectAllIds;
        if (selectKind == SelectionItemKind.note) {
          selectAllIds = notes.map((n) => n.id);
        } else if (selectKind == SelectionItemKind.folder) {
          selectAllIds = subFolders.map((f) => f.id);
        } else if (!hasMixed) {
          if (notes.isNotEmpty) {
            selectAllIds = notes.map((n) => n.id);
          } else if (subFolders.isNotEmpty) {
            selectAllIds = subFolders.map((f) => f.id);
          }
        }
        final allIds = selectAllIds?.toSet() ?? <String>{};
        final allSelected = allIds.isNotEmpty &&
            _selection.selectedIds.containsAll(allIds) &&
            _selection.count >= allIds.length;
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            border: null,
            leading: selecting
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _selection.cancel,
                    child: Text(s.cancel),
                  )
                : null,
            automaticallyImplyLeading: !selecting,
            middle: Text(selecting
                ? (_selection.count == 0
                    ? s.selectItems
                    : s.selectedCount(_selection.count))
                : _currentFolder.name),
            trailing: selecting
                ? (selectAllIds != null
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          if (allSelected) {
                            _selection.replaceAll(
                                const [],
                                selectKind ?? SelectionItemKind.note);
                          } else {
                            _selection.replaceAll(
                                allIds,
                                selectKind ??
                                    (notes.isNotEmpty
                                        ? SelectionItemKind.note
                                        : SelectionItemKind.folder));
                          }
                        },
                        child: Text(
                            allSelected ? s.deselectAll : s.selectAll),
                      )
                    : null)
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showDropdown(context),
                    child: const Icon(CupertinoIcons.ellipsis, size: 26),
                  ),
          ),
          child: SafeArea(
            bottom: !selecting,
            child: Column(
              children: [
                Expanded(child: _buildBody(context)),
                if (selecting)
                  SelectionToolbar(
                    bottomInset: MediaQuery.paddingOf(context).bottom,
                    actions: _buildBatchActions(s),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return Stack(
          children: [
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final subFolders =
                    widget.controller.foldersIn(_currentFolder.id);
                final notes = widget.controller.notesIn(_currentFolder.id);
                if (subFolders.isEmpty && notes.isEmpty) {
                  return Center(
                    child: Text(
                      S.of(context).noNotes,
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
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final f = subFolders[index];
                            return Column(
                              key: ValueKey('sf_${f.id}'),
                              children: [
                                ReorderableDropZone(
                                  kind: ReorderKind.noteFolder,
                                  beforeId: f.id,
                                  onReorder: (movedId, beforeId) => widget
                                      .controller
                                      .reorderNoteFolderBefore(
                                    movedId: movedId,
                                    beforeId: beforeId,
                                    parentFolderId: _currentFolder.id,
                                  ),
                                  child: ReorderableRow(
                                    id: f.id,
                                    kind: ReorderKind.noteFolder,
                                    label: f.name,
                                    child: Dismissible(
                                      key: ValueKey(f.id),
                                      direction: DismissDirection.endToStart,
                                      background:
                                          const NoteDeleteBackground(),
                                      onDismissed: (_) async {
                                        final undo =
                                            UndoScope.maybeOf(context);
                                        final ts = await widget.controller
                                            .deleteFolderDeep(f.id);
                                        undo?.show(
                                          label: S
                                              .of(context)
                                              .noteFolderTrashedToast,
                                          onUndo: () => widget.controller
                                              .restoreAt(ts),
                                        );
                                      },
                                      child: DragTarget<NoteDragData>(
                                        onWillAcceptWithDetails: (_) => true,
                                        onAcceptWithDetails: (d) => widget
                                            .controller
                                            .moveNote(d.data.noteId, f.id),
                                        builder: (ctx, cand, __) {
                                          final hl = cand.isNotEmpty;
                                          return Container(
                                            decoration: hl
                                                ? BoxDecoration(
                                                    color: AppColors.accent
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(8),
                                                  )
                                                : null,
                                            child: _wrapFolderForSelection(
                                              f,
                                              NoteFolderRow(
                                                folder: f,
                                                noteCount: widget.controller
                                                    .notesIn(f.id)
                                                    .length,
                                                onTap: () =>
                                                    Navigator.of(context)
                                                        .push(
                                                  FastRoute<void>(
                                                    builder: (_) =>
                                                        NoteFolderView(
                                                      folder: f,
                                                      controller: widget
                                                          .controller,
                                                      settingsController: widget
                                                          .settingsController,
                                                    ),
                                                  ),
                                                ),
                                                onExpand: () =>
                                                    _toggle(f.id),
                                                isExpanded: _expandedIds
                                                    .contains(f.id),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                if (_expandedIds.contains(f.id))
                                  _buildFolderChildren(context, f.id, 24),
                              ],
                            );
                          },
                          childCount: subFolders.length,
                        ),
                      ),
                    if (subFolders.isNotEmpty)
                      SliverToBoxAdapter(
                        child: ReorderableTrailingSlot(
                          kind: ReorderKind.noteFolder,
                          onReorder: (movedId) => widget.controller
                              .reorderNoteFolderBefore(
                            movedId: movedId,
                            beforeId: null,
                            parentFolderId: _currentFolder.id,
                          ),
                        ),
                      ),

                    if (notes.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final n = notes[index];
                            return DragTarget<NoteDragData>(
                              key: ValueKey('fn_${n.id}'),
                              onWillAcceptWithDetails: (d) =>
                                  d.data.noteId != n.id,
                              onAcceptWithDetails: (d) {
                                final moved = widget.controller.allNotes
                                    .where((x) => x.id == d.data.noteId)
                                    .firstOrNull;
                                if (moved == null) return;
                                if (moved.folderId == n.folderId) {
                                  widget.controller.reorderNoteBefore(
                                    movedId: d.data.noteId,
                                    beforeId: n.id,
                                    folderId: n.folderId,
                                  );
                                } else {
                                  widget.controller
                                      .moveNote(d.data.noteId, n.folderId);
                                }
                              },
                              builder: (context, candidates, _) {
                                return AnimatedBuilder(
                                  animation: ReorderDragNotifier.instance,
                                  builder: (context, _) {
                                    final hovering = candidates.isNotEmpty;
                                    final placeholder = hovering
                                        ? ReorderDragNotifier
                                            .instance.draggingHeight
                                        : 0.0;
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedSize(
                                          duration: const Duration(
                                              milliseconds: 160),
                                          curve: Curves.easeOut,
                                          alignment: Alignment.topCenter,
                                          child: SizedBox(
                                            height: placeholder,
                                            width: double.infinity,
                                          ),
                                        ),
                                        Dismissible(
                                          key: ValueKey(n.id),
                                          direction:
                                              DismissDirection.endToStart,
                                          background:
                                              const NoteDeleteBackground(),
                                          onDismissed: (_) {
                                            final savedFolderId = n.folderId;
                                            widget.controller
                                                .deleteNote(n.id);
                                            UndoScope.maybeOf(context)?.show(
                                              label: S
                                                  .of(context)
                                                  .noteTrashedToast,
                                              onUndo: () => widget.controller
                                                  .restoreNote(
                                                      n.id, savedFolderId),
                                            );
                                          },
                                          child: _wrapNoteForSelection(
                                            n,
                                            NoteRow(
                                              note: n,
                                              onTap: () =>
                                                  Navigator.of(context).push(
                                                FastRoute<void>(
                                                  settings:
                                                      const RouteSettings(
                                                          name:
                                                              NoteDetailView
                                                                  .routeName),
                                                  builder: (_) =>
                                                      NoteDetailView(
                                                    note: n,
                                                    controller:
                                                        widget.controller,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                          childCount: notes.length,
                        ),
                      ),

                    const SliverToBoxAdapter(
                        child: SizedBox(height: 80)),
                  ],
                );
              },
            ),
            if (widget.settingsController == null ||
                widget.settingsController!
                    .smartListPrefs.showNotesAddFolderButton)
              Positioned(
                left: 20,
                bottom: 16,
                child: NoteFolderCircleButton(
                  onPressed: () => showCreateNoteFolderSheet(
                    context,
                    widget.controller,
                    parentFolderId: _currentFolder.id,
                  ),
                  // Dropping the Plus button opens the create-note-folder
                  // sheet scoped to this folder.
                  onAcceptPlus: () => showCreateNoteFolderSheet(
                    context,
                    widget.controller,
                    parentFolderId: _currentFolder.id,
                  ),
                ),
              ),
            Positioned(
              right: 20,
              bottom: 16,
              child: NoteOrangeAddButton(
                onPressed: () => Navigator.of(context).push(
                  FastRoute<void>(
                    settings: const RouteSettings(
                        name: NoteDetailView.routeName),
                    builder: (_) => NoteDetailView(
                      note: Note(
                          title: '', content: '', folderId: _currentFolder.id),
                      controller: widget.controller,
                      isNew: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
  }
}

class _NoteFolderOptionsDropdown extends StatelessWidget {
  const _NoteFolderOptionsDropdown({
    required this.onDismiss,
    required this.onSelect,
    required this.onAddNote,
    required this.onAddFolder,
    required this.onEdit,
    required this.onMoveTo,
    required this.onInfo,
    required this.onDelete,
  });

  final VoidCallback onDismiss;
  final VoidCallback onSelect;
  final VoidCallback onAddNote;
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
                  label: S.of(context).select,
                  icon: CupertinoIcons.checkmark_circle,
                  onTap: onSelect),
              _DropdownItem(
                  label: S.of(context).addNote,
                  icon: CupertinoIcons.add_circled,
                  onTap: onAddNote),
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
