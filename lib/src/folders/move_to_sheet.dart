import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

import '../localization/strings.dart';
import '../models/app_folder.dart';
import '../models/note_folder.dart';
import '../notes/note_controller.dart';
import 'folder_controller.dart';
import 'folder_icon_picker.dart';

Future<void> showMoveToSheet(
  BuildContext context, {
  required FolderController folderController,
  required String? currentParentId,
  required Future<void> Function(String? folderId) onMove,
  String? excludeFolderId,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _MoveToSheet(
      folderController: folderController,
      currentParentId: currentParentId,
      onMove: onMove,
      excludeFolderId: excludeFolderId,
    ),
  );
}

class _MoveToSheet extends StatefulWidget {
  const _MoveToSheet({
    required this.folderController,
    required this.currentParentId,
    required this.onMove,
    this.excludeFolderId,
  });

  final FolderController folderController;
  final String? currentParentId;
  final Future<void> Function(String? folderId) onMove;
  final String? excludeFolderId;

  @override
  State<_MoveToSheet> createState() => _MoveToSheetState();
}

class _MoveToSheetState extends State<_MoveToSheet> {
  late String? _selectedId;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentParentId;
  }

  Set<String> _getExcludedIds() {
    if (widget.excludeFolderId == null) return {};
    final result = <String>{widget.excludeFolderId!};
    _collectDescendants(widget.excludeFolderId!, result);
    return result;
  }

  void _collectDescendants(String folderId, Set<String> result) {
    for (final f in widget.folderController.foldersIn(folderId)) {
      result.add(f.id);
      _collectDescendants(f.id, result);
    }
  }

  List<({AppFolder folder, int depth})> _buildFlatList() {
    final excluded = _getExcludedIds();
    final result = <({AppFolder folder, int depth})>[];
    _buildRecursive(null, 0, excluded, result);
    return result;
  }

  void _buildRecursive(
    String? parentId,
    int depth,
    Set<String> excluded,
    List<({AppFolder folder, int depth})> result,
  ) {
    for (final f in widget.folderController.foldersIn(parentId)) {
      if (excluded.contains(f.id)) continue;
      result.add((folder: f, depth: depth));
      _buildRecursive(f.id, depth + 1, excluded, result);
    }
  }

  bool get _canMove => _selectedId != widget.currentParentId;

  Future<void> _confirm() async {
    if (!_canMove) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _moving = true);
    await widget.onMove(_selectedId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildFlatList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.6,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Container(
            height: 0.5,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          Expanded(
            child: CupertinoScrollbar(
              child: ListView.builder(
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _DestinationRow(
                      icon: Icon(
                        CupertinoIcons.folder,
                        size: 20,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                      label: S.of(context).noFolder,
                      depth: 0,
                      isSelected: _selectedId == null,
                      isCurrent: widget.currentParentId == null,
                      onTap: () => setState(() => _selectedId = null),
                    );
                  }
                  final item = items[index - 1];
                  return _DestinationRow(
                    icon: buildFolderItemIcon(item.folder.iconId, isFolder: true),
                    label: item.folder.name,
                    depth: item.depth,
                    isSelected: _selectedId == item.folder.id,
                    isCurrent: widget.currentParentId == item.folder.id,
                    onTap: () => setState(() => _selectedId = item.folder.id),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          CupertinoButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.of(context).cancel),
          ),
          Expanded(
            child: Text(
              S.of(context).moveTo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            onPressed: (_moving || !_canMove) ? null : _confirm,
            child: _moving
                ? const CupertinoActivityIndicator()
                : Text(
                    S.of(context).move,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Note-folder variant ───────────────────────────────────────────────────────

Future<void> showNoteMoveToSheet(
  BuildContext context, {
  required NoteController noteController,
  required String? currentParentId,
  required Future<void> Function(String? folderId) onMove,
  String? excludeFolderId,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _NoteMoveToSheet(
      noteController: noteController,
      currentParentId: currentParentId,
      onMove: onMove,
      excludeFolderId: excludeFolderId,
    ),
  );
}

class _NoteMoveToSheet extends StatefulWidget {
  const _NoteMoveToSheet({
    required this.noteController,
    required this.currentParentId,
    required this.onMove,
    this.excludeFolderId,
  });

  final NoteController noteController;
  final String? currentParentId;
  final Future<void> Function(String? folderId) onMove;
  final String? excludeFolderId;

  @override
  State<_NoteMoveToSheet> createState() => _NoteMoveToSheetState();
}

class _NoteMoveToSheetState extends State<_NoteMoveToSheet> {
  late String? _selectedId;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentParentId;
  }

  Set<String> _getExcludedIds() {
    if (widget.excludeFolderId == null) return {};
    final result = <String>{widget.excludeFolderId!};
    _collectDescendants(widget.excludeFolderId!, result);
    return result;
  }

  void _collectDescendants(String folderId, Set<String> result) {
    for (final f in widget.noteController.foldersIn(folderId)) {
      result.add(f.id);
      _collectDescendants(f.id, result);
    }
  }

  List<({NoteFolder folder, int depth})> _buildFlatList() {
    final excluded = _getExcludedIds();
    final result = <({NoteFolder folder, int depth})>[];
    _buildRecursive(null, 0, excluded, result);
    return result;
  }

  void _buildRecursive(
    String? parentId,
    int depth,
    Set<String> excluded,
    List<({NoteFolder folder, int depth})> result,
  ) {
    for (final f in widget.noteController.foldersIn(parentId)) {
      if (excluded.contains(f.id)) continue;
      result.add((folder: f, depth: depth));
      _buildRecursive(f.id, depth + 1, excluded, result);
    }
  }

  bool get _canMove => _selectedId != widget.currentParentId;

  Future<void> _confirm() async {
    if (!_canMove) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _moving = true);
    await widget.onMove(_selectedId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildFlatList();
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.6,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Container(
            height: 0.5,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          Expanded(
            child: CupertinoScrollbar(
              child: ListView.builder(
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _DestinationRow(
                      icon: Icon(
                        CupertinoIcons.folder,
                        size: 20,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                      label: S.of(context).noFolder,
                      depth: 0,
                      isSelected: _selectedId == null,
                      isCurrent: widget.currentParentId == null,
                      onTap: () => setState(() => _selectedId = null),
                    );
                  }
                  final item = items[index - 1];
                  return _DestinationRow(
                    icon: buildFolderItemIcon(item.folder.iconId,
                        isFolder: true),
                    label: item.folder.name,
                    depth: item.depth,
                    isSelected: _selectedId == item.folder.id,
                    isCurrent: widget.currentParentId == item.folder.id,
                    onTap: () =>
                        setState(() => _selectedId = item.folder.id),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          CupertinoButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.of(context).cancel),
          ),
          Expanded(
            child: Text(
              S.of(context).moveTo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            onPressed: (_moving || !_canMove) ? null : _confirm,
            child: _moving
                ? const CupertinoActivityIndicator()
                : Text(
                    S.of(context).move,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Shared destination row ────────────────────────────────────────────────────

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
    this.depth = 0,
  });

  final Widget icon;
  final String label;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16.0 + depth * 20.0,
              right: 16,
              top: 12,
              bottom: 12,
            ),
            child: Row(
              children: [
                SizedBox(width: 24, height: 24, child: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                if (isCurrent)
                  Text(
                    S.of(context).current,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  )
                else if (isSelected)
                  const Icon(
                    CupertinoIcons.checkmark,
                    size: 16,
                    color: AppColors.accent,
                  ),
              ],
            ),
          ),
        ),
        Container(
          height: 0.5,
          margin: EdgeInsets.only(left: 16.0 + depth * 20.0 + 36),
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ],
    );
  }
}
