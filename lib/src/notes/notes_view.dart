import 'package:flutter/cupertino.dart';

import '../models/note.dart';
import '../utils/fast_route.dart';
import 'create_note_folder_sheet.dart';
import 'note_controller.dart';
import 'note_detail_view.dart';
import 'note_folder_view.dart';
import 'note_widgets.dart';

class NotesView extends StatelessWidget {
  const NotesView({super.key, required this.controller});

  final NoteController controller;

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
      navigationBar: const CupertinoNavigationBar(border: null,
        middle: Text('Notes'),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final folders = controller.foldersIn(null);
                final notes = controller.notesIn(null);
                if (folders.isEmpty && notes.isEmpty) {
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
                            controller.reorderNoteFolders(
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
                                  controller.deleteFolderDeep(f.id),
                              child: NoteFolderRow(
                                folder: f,
                                onTap: () =>
                                    Navigator.of(context).push(
                                  FastRoute<void>(
                                    builder: (_) => NoteFolderView(
                                      folder: f,
                                      controller: controller,
                                    ),
                                  ),
                                ),
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
                            controller.reorderNotes(null, old, neo),
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
                                  controller.deleteNote(n.id),
                              child: NoteRow(
                                note: n,
                                onTap: () =>
                                    Navigator.of(context).push(
                                  FastRoute<void>(
                                    settings: const RouteSettings(
                                        name: NoteDetailView.routeName),
                                    builder: (_) => NoteDetailView(
                                      note: n,
                                      controller: controller,
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
              child: NoteFolderCircleButton(
                onPressed: () =>
                    showCreateNoteFolderSheet(context, controller),
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
                      controller: controller,
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
