import 'package:flutter/cupertino.dart';

import '../calendar/event_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../home_shell.dart';
import '../localization/strings.dart';
import '../models/note.dart';
import '../search/search_pull_scope.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
import '../tasks/task_controller.dart';
import '../theme/app_theme.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/dropdown_row.dart';
import '../utils/fast_route.dart';
import '../utils/undo_controller.dart';
import 'create_note_folder_sheet.dart';
import 'note_controller.dart';
import 'note_detail_view.dart';
import 'note_folder_view.dart';
import 'note_trash_view.dart';
import 'note_widgets.dart';

class NotesView extends StatefulWidget {
  const NotesView({
    super.key,
    required this.controller,
    required this.collapseSignal,
    this.settingsController,
    this.backupService,
    this.db,
    this.taskController,
    this.folderController,
    this.eventController,
  });

  final NoteController controller;
  final ValueNotifier<int> collapseSignal;
  final SettingsController? settingsController;
  final BackupService? backupService;
  final DatabaseService? db;
  final TaskController? taskController;
  final FolderController? folderController;
  final EventController? eventController;

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> with DropdownOverlayMixin {
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    widget.collapseSignal.addListener(_collapseAll);
  }

  @override
  void dispose() {
    widget.collapseSignal.removeListener(_collapseAll);
    super.dispose();
  }

  void _collapseAll() {
    if (_expandedIds.isNotEmpty) setState(() => _expandedIds.clear());
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

  Widget _maybeWrapWithSearchPull({required Widget child}) {
    if (widget.db == null ||
        widget.taskController == null ||
        widget.folderController == null ||
        widget.eventController == null) {
      return child;
    }
    return SearchPullScope(
      db: widget.db!,
      taskController: widget.taskController!,
      folderController: widget.folderController!,
      noteController: widget.controller,
      eventController: widget.eventController!,
      child: child,
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

  void _openSettings(BuildContext context) {
    HomeShell.openGlobalSettings(context);
  }

  void _showSettingsMenu(BuildContext context) {
    final sc = widget.settingsController;
    final settingsHidden = sc != null && !sc.isTabVisible(4);
    showDropdown(context, (dismiss) {
      return _NotesOptionsDropdown(
        onDismiss: dismiss,
        onAddNote: () {
          dismiss();
          Navigator.of(context).push(
            FastRoute<void>(
              settings:
                  const RouteSettings(name: NoteDetailView.routeName),
              builder: (_) => NoteDetailView(
                note: Note(title: '', content: ''),
                controller: widget.controller,
                isNew: true,
              ),
            ),
          );
        },
        onAddFolder: () {
          dismiss();
          showCreateNoteFolderSheet(context, widget.controller);
        },
        showSettings: settingsHidden,
        onSettings: settingsHidden
            ? () {
                dismiss();
                _openSettings(context);
              }
            : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sc = widget.settingsController;
    final showFloatingAddFolder =
        sc == null || sc.smartListPrefs.showNotesAddFolderButton;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabNotes),
        trailing: Semantics(
          label: s.settings,
          button: true,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showSettingsMenu(context),
            child: const Icon(CupertinoIcons.ellipsis, size: 26),
          ),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            _maybeWrapWithSearchPull(
              child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final folders = widget.controller.foldersIn(null);
                final notes = widget.controller.notesIn(null);
                final hasTrash =
                    widget.controller.trashedNotes.isNotEmpty ||
                        widget.controller.trashedFolders.isNotEmpty;
                if (folders.isEmpty && notes.isEmpty && !hasTrash) {
                  return Center(
                    child: Text(
                      s.noNotes,
                      style: const TextStyle(
                          color: CupertinoColors.secondaryLabel),
                    ),
                  );
                }
                return CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // Reorderable note folders
                    if (folders.isNotEmpty)
                      SliverReorderableList(
                        itemCount: folders.length,
                        onReorder: (old, neo) =>
                            widget.controller.reorderNoteFolders(
                                null, old, neo),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final f = folders[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('nf_${f.id}'),
                            index: index,
                            child: Column(
                              children: [
                                Dismissible(
                                  key: ValueKey(f.id),
                                  direction: DismissDirection.endToStart,
                                  background: const NoteDeleteBackground(),
                                  onDismissed: (_) async {
                                    final undo =
                                        UndoScope.maybeOf(context);
                                    final ts = await widget.controller
                                        .deleteFolderDeep(f.id);
                                    undo?.show(
                                      label: S
                                          .of(context)
                                          .noteFolderTrashedToast,
                                      onUndo: () =>
                                          widget.controller.restoreAt(ts),
                                    );
                                  },
                                  child: NoteFolderRow(
                                    folder: f,
                                    noteCount: widget.controller
                                        .notesIn(f.id)
                                        .length,
                                    onTap: () =>
                                        Navigator.of(context).push(
                                      FastRoute<void>(
                                        builder: (_) => NoteFolderView(
                                          folder: f,
                                          controller: widget.controller,
                                          settingsController:
                                              widget.settingsController,
                                        ),
                                      ),
                                    ),
                                    onExpand: () => _toggle(f.id),
                                    isExpanded: _expandedIds.contains(f.id),
                                  ),
                                ),
                                if (_expandedIds.contains(f.id))
                                  _buildFolderChildren(context, f.id, 24),
                              ],
                            ),
                          );
                        },
                      ),

                    // Reorderable notes
                    if (notes.isNotEmpty)
                      SliverReorderableList(
                        itemCount: notes.length,
                        onReorder: (old, neo) =>
                            widget.controller.reorderNotes(null, old, neo),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final n = notes[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('note_${n.id}'),
                            index: index,
                            child: Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              background: const NoteDeleteBackground(),
                              onDismissed: (_) {
                                final savedFolderId = n.folderId;
                                widget.controller.deleteNote(n.id);
                                UndoScope.maybeOf(context)?.show(
                                  label: S.of(context).noteTrashedToast,
                                  onUndo: () => widget.controller
                                      .restoreNote(n.id, savedFolderId),
                                );
                              },
                              child: NoteRow(
                                note: n,
                                onTap: () =>
                                    Navigator.of(context).push(
                                  FastRoute<void>(
                                    settings: const RouteSettings(
                                        name: NoteDetailView.routeName),
                                    builder: (_) => NoteDetailView(
                                      note: n,
                                      controller: widget.controller,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

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
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).push(
                                FastRoute<void>(
                                  builder: (_) => NoteTrashView(
                                      controller: widget.controller),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 9),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Icon(
                                        CupertinoIcons.trash,
                                        size: 22,
                                        color: CupertinoColors.secondaryLabel
                                            .resolveFrom(context),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        s.trash,
                                        style: const TextStyle(fontSize: 17),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SliverToBoxAdapter(
                        child: SizedBox(height: 80)),
                  ],
                );
              },
            ),
            ),
            if (showFloatingAddFolder)
              Positioned(
                left: 20,
                bottom: 16,
                child: NoteFolderCircleButton(
                  onPressed: () =>
                      showCreateNoteFolderSheet(context, widget.controller),
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
                      note: Note(title: '', content: ''),
                      controller: widget.controller,
                      isNew: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesOptionsDropdown extends StatelessWidget {
  const _NotesOptionsDropdown({
    required this.onDismiss,
    required this.onAddNote,
    required this.onAddFolder,
    this.showSettings = false,
    this.onSettings,
  });

  final VoidCallback onDismiss;
  final VoidCallback onAddNote;
  final VoidCallback onAddFolder;
  final bool showSettings;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.paddingOf(context).top + 44.0 + 4.0;
    final s = S.of(context);
    final separator = Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
    final items = <Widget>[
      DropdownRow(
        label: s.addNote,
        icon: CupertinoIcons.add_circled,
        onTap: onAddNote,
      ),
      separator,
      DropdownRow(
        label: s.addFolder,
        icon: CupertinoIcons.folder_badge_plus,
        onTap: onAddFolder,
      ),
    ];
    if (showSettings) {
      items.add(separator);
      items.add(DropdownRow(
        label: s.settings,
        icon: CupertinoIcons.gear_alt,
        onTap: onSettings ?? () {},
      ));
    }
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
          child: Container(
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
              children: items,
            ),
          ),
        ),
      ],
    );
  }
}
