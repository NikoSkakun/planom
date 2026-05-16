import 'package:flutter/cupertino.dart';

import '../folders/folder_icon_picker.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../utils/fast_route.dart';
import '../utils/item_info_sheet.dart';
import '../folders/create_folder_list_sheet.dart' show showRenameSheet;
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
  });

  final NoteFolder folder;
  final NoteController controller;

  @override
  State<NoteFolderView> createState() => _NoteFolderViewState();
}

class _NoteFolderViewState extends State<NoteFolderView> {
  late NoteFolder _currentFolder;
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
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

  void _showDropdown(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _NoteFolderOptionsDropdown(
        onDismiss: () => entry.remove(),
        onRename: () {
          entry.remove();
          showRenameSheet(
            context,
            currentName: _currentFolder.name,
            onRename: (name) async {
              final updated = _currentFolder.copyWith(name: name);
              await widget.controller.updateFolder(updated);
              if (mounted) setState(() => _currentFolder = updated);
            },
          );
        },
        onChangeIcon: () {
          entry.remove();
          showFolderIconPickerSheet(
            context,
            currentIconId: _currentFolder.iconId,
            isFolder: true,
            onSelected: (id) {
              final updated = _currentFolder.copyWith(
                iconId: id,
                clearIconId: id == null,
              );
              widget.controller.updateFolder(updated);
              if (mounted) setState(() => _currentFolder = updated);
            },
          );
        },
        onMoveTo: () {
          entry.remove();
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
          entry.remove();
          showItemInfoSheet(context, creationDate: _currentFolder.creationDate);
        },
        onDelete: () {
          entry.remove();
          widget.controller.deleteFolderDeep(_currentFolder.id);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(_currentFolder.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showDropdown(context),
          child: const Icon(CupertinoIcons.ellipsis, size: 26),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final subFolders =
                    widget.controller.foldersIn(_currentFolder.id);
                final notes = widget.controller.notesIn(_currentFolder.id);
                if (subFolders.isEmpty && notes.isEmpty) {
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
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 8)),

                    if (subFolders.isNotEmpty)
                      SliverReorderableList(
                        itemCount: subFolders.length,
                        onReorder: (old, neo) =>
                            widget.controller.reorderNoteFolders(
                                _currentFolder.id, old, neo),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final f = subFolders[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('sf_${f.id}'),
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
                                    noteCount:
                                        widget.controller.notesIn(f.id).length,
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
                                    _buildFolderChildren(context, f.id, 24),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    if (notes.isNotEmpty)
                      SliverReorderableList(
                        itemCount: notes.length,
                        onReorder: (old, neo) =>
                            widget.controller.reorderNotes(
                                _currentFolder.id, old, neo),
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          final n = notes[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('fn_${n.id}'),
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
                onPressed: () => showCreateNoteFolderSheet(
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
        ),
      ),
    );
  }
}

class _NoteFolderOptionsDropdown extends StatelessWidget {
  const _NoteFolderOptionsDropdown({
    required this.onDismiss,
    required this.onRename,
    required this.onChangeIcon,
    required this.onMoveTo,
    required this.onInfo,
    required this.onDelete,
  });

  final VoidCallback onDismiss;
  final VoidCallback onRename;
  final VoidCallback onChangeIcon;
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
                  label: 'Rename',
                  icon: CupertinoIcons.pencil,
                  onTap: onRename),
              _DropdownItem(
                  label: 'Change Icon',
                  icon: CupertinoIcons.photo,
                  onTap: onChangeIcon),
              _DropdownItem(
                  label: 'Move to',
                  icon: CupertinoIcons.folder,
                  onTap: onMoveTo),
              _DropdownItem(
                  label: 'Info',
                  icon: CupertinoIcons.info,
                  onTap: onInfo),
              _DropdownItem(
                  label: 'Delete',
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: effectiveColor),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 17, color: effectiveColor),
          ],
        ),
      ),
    );
  }
}
