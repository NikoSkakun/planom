import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart' show WidgetsBindingObserver, AppLifecycleState;

import '../folders/move_to_sheet.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../models/note.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/item_info_sheet.dart';
import 'markdown_toolbar.dart';
import 'markdown_view.dart';
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
  final FocusNode _contentFocus = FocusNode();
  String? _folderId;
  bool _deleted = false;
  bool _persistedNew = false;
  bool _isEditing = false;
  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isNew;
    _title = TextEditingController(text: widget.note.title);
    _content = TextEditingController(text: widget.note.content);
    _folderId = widget.note.folderId;
    _title.addListener(_scheduleAutosave);
    _content.addListener(_scheduleAutosave);
    _contentFocus.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {
      if (!_contentFocus.hasFocus) _isEditing = false;
    });
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
      return;
    }
    // Skip the write when nothing actually changed — otherwise copyWith bumps
    // modifiedDate and the note jumps to the top of its list on next sort.
    final changed = title != widget.note.title ||
        content != widget.note.content ||
        _folderId != widget.note.folderId;
    if (!changed) return;
    widget.controller.updateNote(
      widget.note.copyWith(
        title: title,
        content: content,
        folderId: _folderId,
        clearFolderId: _folderId == null,
      ),
    );
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
    _contentFocus.removeListener(_onFocusChanged);
    _contentFocus.dispose();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentFocus.requestFocus();
    });
  }

  Widget _buildContentArea() {
    if (_isEditing || _contentFocus.hasFocus) {
      return CupertinoTextField(
        controller: _content,
        focusNode: _contentFocus,
        placeholder: S.of(context).note,
        style: const TextStyle(fontSize: 16),
        decoration: const BoxDecoration(),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        textCapitalization: TextCapitalization.sentences,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      );
    }
    if (_content.text.trim().isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _startEditing,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              S.of(context).note,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.placeholderText.resolveFrom(context),
              ),
            ),
          ),
        ),
      );
    }
    // Use shrinkWrap + an explicit scroll view so the user can drag-scroll
    // long notes without competing with the tap-to-edit gesture detector
    // that wraps the rendered markdown.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: MarkdownView(
        data: _content.text,
        onTap: _startEditing,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showToolbar = _contentFocus.hasFocus;
    return PopScope(
      // The pop completes immediately for iOS swipe-back, but unfocusing
      // here forces the IME to commit any in-flight composition into
      // _content.text before dispose() runs _save(), so the user's last
      // typed word isn't lost.
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _contentFocus.unfocus();
        _autosaveTimer?.cancel();
        _save();
      },
      child: CupertinoPageScaffold(
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
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: CupertinoTextField(
                        controller: _title,
                        placeholder: S.of(context).title,
                        autofocus: widget.isNew,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const BoxDecoration(),
                        padding: EdgeInsets.zero,
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
                    Expanded(child: _buildContentArea()),
                  ],
                ),
              ),
            ),
            if (showToolbar)
              MarkdownToolbar(
                controller: _content,
                focusNode: _contentFocus,
                onPromptLink: (selected) =>
                    showLinkPromptDialog(context, initialText: selected),
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
                _DropdownRow(
                  label: S.of(context).moveTo,
                  icon: CupertinoIcons.folder,
                  onTap: onMoveTo,
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                _DropdownRow(
                  label: S.of(context).info,
                  icon: CupertinoIcons.info,
                  onTap: onInfo,
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                _DropdownRow(
                  label: S.of(context).delete,
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
