import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart' show WidgetsBindingObserver, AppLifecycleState;

import '../folders/move_to_sheet.dart';
import '../localization/strings.dart';
import '../spaces/space_manager.dart';
import '../theme/app_theme.dart';
import '../models/note.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/dropdown_row.dart';
import '../utils/item_info_sheet.dart';
import '../utils/undo_controller.dart';
import 'markdown_toolbar.dart';
import 'markdown_view.dart';
import 'note_controller.dart';
import 'note_share.dart';

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
  final FocusNode _titleFocus = FocusNode();
  // Owned by the content area's scroll view and kept alive across the
  // preview↔edit switch, so the scroll position is preserved instead of
  // snapping back to the top each time the body widget is rebuilt.
  final ScrollController _contentScroll = ScrollController();
  String? _folderId;
  bool _deleted = false;
  bool _persistedNew = false;
  bool _isEditing = false;
  Timer? _autosaveTimer;

  // Baseline of what is currently persisted, so the change check stays
  // accurate after each save (widget.note is captured once and never updated).
  late String _savedTitle;
  late String _savedContent;
  String? _savedFolderId;

  // Latest EditableTextState the body's contextMenuBuilder handed us. We
  // need it to re-show the selection toolbar after the user taps "Select
  // All" — the system hides the toolbar in that handoff and Flutter doesn't
  // re-show it automatically.
  EditableTextState? _contentEditableState;
  TextSelection? _lastContentSelection;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isNew;
    _title = TextEditingController(text: widget.note.title);
    _content = TextEditingController(text: widget.note.content);
    _folderId = widget.note.folderId;
    _savedTitle = widget.note.title;
    _savedContent = widget.note.content;
    _savedFolderId = widget.note.folderId;
    _title.addListener(_scheduleAutosave);
    _content.addListener(_scheduleAutosave);
    _content.addListener(_onContentSelectionChanged);
    _contentFocus.addListener(_onContentFocusChanged);
    _titleFocus.addListener(_onTitleFocusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Detects the "Select All" gesture (tap empty space → toolbar with the
  /// single Select-All button → tap it) and re-shows the selection toolbar
  /// so the user immediately sees Copy / Cut / Paste / Look Up without
  /// needing a second tap to bring the toolbar back.
  void _onContentSelectionChanged() {
    final selection = _content.selection;
    final text = _content.text;
    final previous = _lastContentSelection;
    _lastContentSelection = selection;
    if (text.isEmpty) return;
    if (!selection.isValid || selection.isCollapsed) return;
    final isSelectAll =
        selection.start == 0 && selection.end == text.length;
    if (!isSelectAll) return;
    // Avoid re-showing the toolbar on every keystroke that happens to leave
    // the whole document selected — only react when the selection just
    // changed shape (it was collapsed, or it covered a different range).
    if (previous != null &&
        !previous.isCollapsed &&
        previous.start == 0 &&
        previous.end == text.length) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentEditableState?.showToolbar();
    });
  }

  void _onContentFocusChanged() {
    if (!mounted) return;
    if (_contentFocus.hasFocus) {
      // Gaining focus (e.g. via the title's "Next" key, tapping the body, or
      // a programmatic requestFocus). The toolbar's visibility is tied to
      // hasFocus, so we need a rebuild to render it.
      setState(() => _isEditing = true);
      return;
    }
    // Losing content focus (e.g. dismissing the keyboard, switching tabs,
    // tapping the title) must persist immediately — the debounce timer might
    // not fire before the app is killed or this view is torn down.
    _flushSave();
    setState(() => _isEditing = false);
  }

  void _onTitleFocusChanged() {
    if (!_titleFocus.hasFocus) _flushSave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 1), _save);
  }

  /// Cancels any pending debounce and saves the current text right now.
  void _flushSave() {
    _autosaveTimer?.cancel();
    _save();
  }

  void _save() {
    if (_deleted) return;
    final title = _title.text.trim();
    // Persist the body exactly as typed — trimming would silently drop leading
    // indentation (meaningful in markdown) and trailing blank lines.
    final content = _content.text;
    if (widget.isNew && !_persistedNew) {
      if (title.isEmpty && content.trim().isEmpty) return;
      widget.controller.addNote(
        widget.note.copyWith(
          title: title,
          content: content,
          folderId: _folderId,
          clearFolderId: _folderId == null,
        ),
      );
      _persistedNew = true;
      _savedTitle = title;
      _savedContent = content;
      _savedFolderId = _folderId;
      return;
    }
    // Skip the write when nothing actually changed — otherwise copyWith bumps
    // modifiedDate and the note jumps to the top of its list on next sort.
    // Compared against the last-saved values (not the stale initial note) so a
    // genuine edit is never mistaken for "unchanged".
    if (title == _savedTitle &&
        content == _savedContent &&
        _folderId == _savedFolderId) {
      return;
    }
    widget.controller.updateNote(
      widget.note.copyWith(
        title: title,
        content: content,
        folderId: _folderId,
        clearFolderId: _folderId == null,
      ),
    );
    _savedTitle = title;
    _savedContent = content;
    _savedFolderId = _folderId;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _flushSave();
    }
  }

  void _showDropdown(BuildContext context) {
    showDropdown(context, (dismiss) {
      return _NoteOptionsDropdown(
        onDismiss: dismiss,
        onShare: () {
          dismiss();
          // Persist the latest edit first so the on-disk note matches what
          // the user just exported — saves accidental drift between the
          // share payload and the stored copy.
          _flushSave();
          showNoteShareMenu(
            context,
            title: _title.text,
            content: _content.text,
          );
        },
        onMoveTo: () {
          dismiss();
          showNoteMoveToSheet(
            context,
            noteController: widget.controller,
            currentParentId: _folderId,
            onMove: (folderId) async {
              if (mounted) setState(() => _folderId = folderId);
              _flushSave();
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
          final savedFolderId = widget.note.folderId;
          final undo = UndoScope.maybeOf(context);
          widget.controller.deleteNote(widget.note.id);
          undo?.show(
            label: S.of(context).noteTrashedToast,
            onUndo: () => widget.controller
                .restoreNote(widget.note.id, savedFolderId),
          );
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
    _content.removeListener(_onContentSelectionChanged);
    _contentFocus.removeListener(_onContentFocusChanged);
    _contentFocus.dispose();
    _titleFocus.removeListener(_onTitleFocusChanged);
    _titleFocus.dispose();
    _title.dispose();
    _content.dispose();
    _contentScroll.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentFocus.requestFocus();
    });
  }

  Widget _buildContentArea({required bool useMarkdown}) {
    // A single scroll view hosts every mode (edit / preview / placeholder) so
    // its scroll offset survives the mode switch. The inner child is forced to
    // at least the viewport height so the whole area is tappable-to-edit and
    // short notes still fill the screen. The text field grows with its content
    // (no `expands`) and the surrounding scroll view keeps the caret in view.
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight;
        final Widget child;
        if (_isEditing || _contentFocus.hasFocus) {
          child = CupertinoTextField(
            controller: _content,
            focusNode: _contentFocus,
            placeholder: S.of(context).note,
            style: const TextStyle(fontSize: 16, height: 1.35),
            decoration: const BoxDecoration(),
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            textCapitalization: TextCapitalization.sentences,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            contextMenuBuilder: (context, editableTextState) {
              // Cache the state so the selection listener can re-show the
              // toolbar after a "Select All" gesture (see
              // _onContentSelectionChanged). Returning the adaptive toolbar
              // keeps the platform-native look.
              _contentEditableState = editableTextState;
              return CupertinoAdaptiveTextSelectionToolbar.editableText(
                editableTextState: editableTextState,
              );
            },
          );
        } else if (_content.text.trim().isEmpty) {
          child = GestureDetector(
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
                    color:
                        CupertinoColors.placeholderText.resolveFrom(context),
                  ),
                ),
              ),
            ),
          );
        } else if (!useMarkdown) {
          // Plain-text mode: skip the markdown parser entirely and show the
          // body verbatim. Tap-to-edit still triggers via the GestureDetector.
          child = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startEditing,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  _content.text,
                  style: const TextStyle(fontSize: 16, height: 1.35),
                ),
              ),
            ),
          );
        } else {
          child = MarkdownView(
            data: _content.text,
            onTap: _startEditing,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          );
        }
        return SingleChildScrollView(
          controller: _contentScroll,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsCtl =
        SpaceManagerProvider.maybeOf(context)?.settingsController;
    return ListenableBuilder(
      listenable: settingsCtl ?? const _NoopListenable(),
      builder: (context, _) {
        final useMarkdown =
            settingsCtl?.smartListPrefs.notesUseMarkdown ?? true;
        final showToolbar = _contentFocus.hasFocus && useMarkdown;
        return PopScope(
          // The pop completes immediately for iOS swipe-back, but unfocusing
          // here forces the IME to commit any in-flight composition into
          // _content.text before dispose() runs _save(), so the user's last
          // typed word isn't lost.
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            _titleFocus.unfocus();
            _contentFocus.unfocus();
            _flushSave();
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
                    // When the keyboard is open, the markdown toolbar sits
                    // below the content and consumes the bottom inset
                    // itself. When the keyboard is closed, the tab bar
                    // overlays the page — so we need the bottom safe area
                    // (CupertinoTabScaffold includes the tab bar height in
                    // MediaQuery.padding.bottom) to keep the last lines of
                    // text off the tab bar.
                    bottom: !showToolbar,
                    child: Column(
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: CupertinoTextField(
                            controller: _title,
                            focusNode: _titleFocus,
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
                            onSubmitted: (_) =>
                                _contentFocus.requestFocus(),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            height: 0.5,
                            color: CupertinoColors.separator,
                          ),
                        ),
                        Expanded(
                          child: _buildContentArea(useMarkdown: useMarkdown),
                        ),
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
      },
    );
  }
}

/// Stand-in [Listenable] for when no SettingsController is available
/// in the widget tree — keeps the build shape identical.
class _NoopListenable extends Listenable {
  const _NoopListenable();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _NoteOptionsDropdown extends StatelessWidget {
  const _NoteOptionsDropdown({
    required this.onDismiss,
    required this.onShare,
    required this.onMoveTo,
    required this.onInfo,
    required this.onDelete,
  });

  final VoidCallback onDismiss;
  final VoidCallback onShare;
  final VoidCallback onMoveTo;
  final VoidCallback onInfo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final topOffset = MediaQuery.paddingOf(context).top + 44.0 + 4.0;
    final separator = Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
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
                DropdownRow(
                  label: s.share,
                  icon: CupertinoIcons.share,
                  onTap: onShare,
                ),
                separator,
                DropdownRow(
                  label: s.moveTo,
                  icon: CupertinoIcons.folder,
                  onTap: onMoveTo,
                ),
                separator,
                DropdownRow(
                  label: s.info,
                  icon: CupertinoIcons.info,
                  onTap: onInfo,
                ),
                separator,
                DropdownRow(
                  label: s.delete,
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
