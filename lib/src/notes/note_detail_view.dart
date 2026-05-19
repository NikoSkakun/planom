import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart' show WidgetsBindingObserver, AppLifecycleState;

import '../folders/move_to_sheet.dart';
import '../models/note.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/item_info_sheet.dart';
import 'note_controller.dart';

class NoteDetailView extends StatefulWidget {
  const NoteDetailView({
    super.key,
    required this.note,
    required this.controller,
    this.isNew = false,
  });

  static const routeName = 'note_detail';

  final Note note;
  final NoteController controller;
  final bool isNew;

  @override
  State<NoteDetailView> createState() => _NoteDetailViewState();
}

class _NoteDetailViewState extends State<NoteDetailView>
    with DropdownOverlayMixin, WidgetsBindingObserver {
  late final TextEditingController _title;
  late final TextEditingController _content;
  String? _folderId;
  bool _deleted = false;
  bool _persistedNew = false;
  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note.title);
    _content = TextEditingController(text: widget.note.content);
    _folderId = widget.note.folderId;
    _title.addListener(_scheduleAutosave);
    _content.addListener(_scheduleAutosave);
    WidgetsBinding.instance.addObserver(this);
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), _save);
  }

  void _save() {
    if (_deleted) return;
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (widget.isNew && !_persistedNew) {
      if (title.isEmpty && content.isEmpty) return;
      widget.controller.addNote(
        widget.note.copyWith(
          title: title,
          content: content,
          folderId: _folderId,
          clearFolderId: _folderId == null,
        ),
      );
      _persistedNew = true;
    } else {
      widget.controller.updateNote(
        widget.note.copyWith(
          title: title,
          content: content,
          folderId: _folderId,
          clearFolderId: _folderId == null,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _autosaveTimer?.cancel();
      _save();
    }
  }

  void _showDropdown(BuildContext context) {
    showDropdown(context, (dismiss) {
      return _NoteOptionsDropdown(
        onDismiss: dismiss,
        onMoveTo: () {
          dismiss();
          showNoteMoveToSheet(
            context,
            noteController: widget.controller,
            currentParentId: _folderId,
            onMove: (folderId) async {
              if (mounted) setState(() => _folderId = folderId);
            },
          );
        },
        onInfo: () {
          dismiss();
          showItemInfoSheet(
            context,
            creationDate: widget.note.creationDate,
            modifiedDate: widget.note.modifiedDate,
          );
        },
        onDelete: () {
          dismiss();
          _deleted = true;
          widget.controller.deleteNote(widget.note.id);
          Navigator.of(context).pop();
        },
      );
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _save();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        trailing: widget.isNew
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showDropdown(context),
                child: const Icon(CupertinoIcons.ellipsis, size: 26),
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: CupertinoTextField(
                controller: _title,
                placeholder: 'Title',
                autofocus: widget.isNew,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const BoxDecoration(),
                maxLines: null,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 0.5,
                color: CupertinoColors.separator,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: CupertinoTextField(
                  controller: _content,
                  placeholder: 'Note',
                  style: const TextStyle(fontSize: 16),
                  decoration: const BoxDecoration(),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteOptionsDropdown extends StatelessWidget {
  const _NoteOptionsDropdown({
    required this.onDismiss,
    required this.onMoveTo,
    required this.onInfo,
    required this.onDelete,
  });

  final VoidCallback onDismiss;
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
          child: Container(
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
                _DropdownRow(
                  label: 'Move to',
                  icon: CupertinoIcons.folder,
                  onTap: onMoveTo,
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                _DropdownRow(
                  label: 'Info',
                  icon: CupertinoIcons.info,
                  onTap: onInfo,
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                _DropdownRow(
                  label: 'Delete',
                  icon: CupertinoIcons.trash,
                  onTap: onDelete,
                  color: CupertinoColors.destructiveRed,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
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
