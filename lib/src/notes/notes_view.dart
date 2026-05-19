import 'package:flutter/cupertino.dart';

import '../models/note.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_view.dart';
import '../utils/fast_route.dart';
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
  });

  final NoteController controller;
  final ValueNotifier<int> collapseSignal;
  final SettingsController? settingsController;
  final BackupService? backupService;

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
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
    final subFolders = widget.controller.foldersIn(folderId);
    final notes = widget.controller.notesIn(folderId);

    return Column(
      children: [
        for (final f in subFolders) ...[
          NoteFolderRow(
            folder: f,
            noteCount: widget.controller.notesIn(f.id).length,
            indent: indent,
            onTap: () => Navigator.of(context).push(
              FastRoute<void>(
                builder: (_) => NoteFolderView(
                  folder: f,
                  controller: widget.controller,
                ),
              ),
            ),
            onExpand: () => _toggle(f.id),
            isExpanded: _expandedIds.contains(f.id),
          ),
          if (_expandedIds.contains(f.id))
            _buildFolderChildren(context, f.id, indent + 24),
        ],
        for (final n in notes)
          NoteRow(
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
      ],
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
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => SettingsView(
          controller: widget.settingsController!,
          backupService: widget.backupService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.settingsController;
    final settingsHidden = sc != null && !sc.isTabVisible(4);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: const Text('Notes'),
        trailing: settingsHidden
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _openSettings(context),
                child: const Icon(CupertinoIcons.ellipsis, size: 26),
              )
            : null,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final folders = widget.controller.foldersIn(null);
                  final notes = widget.controller.notesIn(null);
                  final hasTrash =
                      widget.controller.trashedNotes.isNotEmpty ||
                          widget.controller.trashedFolders.isNotEmpty;
                  if (folders.isEmpty && notes.isEmpty && !hasTrash) {
                    return const Center(
                      child: Text(
                        'No notes',
                        style: TextStyle(
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
                              child: Dismissible(
                                key: ValueKey(f.id),
                                direction: DismissDirection.endToStart,
                                background: const NoteDeleteBackground(),
                                onDismissed: (_) =>
                                    widget.controller.deleteFolderDeep(f.id),
                                child: Column(
                                  children: [
                                    NoteFolderRow(
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
                                          ),
                                        ),
                                      ),
                                      onExpand: () => _toggle(f.id),
                                      isExpanded: _expandedIds.contains(f.id),
                                    ),
                                    if (_expandedIds.contains(f.id))
                                      _buildFolderChildren(context, f.id, 24),
                                  ],
                                ),
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
                                onDismissed: (_) =>
                                    widget.controller.deleteNote(n.id),
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
                                      const Expanded(
                                        child: Text(
                                          'Trash',
                                          style: TextStyle(fontSize: 17),
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
          ),
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
    );
  }
}
