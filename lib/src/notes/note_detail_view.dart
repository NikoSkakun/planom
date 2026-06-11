import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter/widgets.dart' show WidgetsBindingObserver, AppLifecycleState;

import '../folders/move_to_sheet.dart';
import '../localization/strings.dart';
import '../spaces/space_manager.dart';
import '../theme/app_theme.dart';
import '../models/note.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/dropdown_row.dart';
import '../utils/emoji_text.dart';
import '../utils/item_info_sheet.dart';
import '../utils/keyboard_insets.dart';
import '../utils/tap_offset.dart';
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
  // Stable snapshot of the note this editor was opened with (see initState).
  // All persistence + menu actions key off this, never the live widget.note,
  // whose id can change if the route rebuilds the new-note placeholder.
  late final Note _note;
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
  bool _disposed = false;
  bool _persistedNew = false;
  bool _isEditing = false;
  Timer? _autosaveTimer;

  // Tracks whether this editor is the active (onstage) tab. When hosted inside
  // a CupertinoTabScaffold, switching to another tab keeps this subtree alive
  // but moves it offstage (TickerMode disabled). A focused text field that
  // goes offstage holds a stale text-input connection: text typed after the
  // user returns to this tab can fail to reach the controller and is then
  // silently dropped on the next save. See [_handleTabActiveChange].
  bool _tabActive = true;

  // Single-flight guard for the async save. `_saving` is true while a write
  // is in flight; `_resaveRequested` records that the text changed again
  // during that write so we loop and persist the newest text once it lands.
  // This keeps writes ordered (newest wins) without overlapping DB calls.
  bool _saving = false;
  bool _resaveRequested = false;

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

  // Two-mode deferred handling for content focus loss.
  //
  // The CupertinoTextField is unmounted when [_isEditing] flips to false
  // (the body re-renders as a preview / placeholder), and tearing it down
  // destroys the underlying iOS UITextField — which would take its undo
  // manager with it. We therefore CANNOT exit editing mode on every focus
  // drop; we have to recognise the cases where focus will (or might) come
  // back and keep the field mounted across the gap.
  //
  // Cases:
  // 1. User tapped the toolbar's hide-keyboard button → [_userHidKeyboard]
  //    is set true around the focusNode.unfocus() call. The listener sees
  //    the flag and exits editing immediately — no field needed afterwards.
  // 2. _KeyboardBrightnessReactor refresh → handled by
  //    KeyboardAppearanceRefresh.isActive + the safety net timer below.
  // 3. iOS shake-to-undo dialog → the system resigns the field's first
  //    responder; tapping Cancel/Undo restores the keyboard, but the
  //    Flutter focus has been lost. We keep the field mounted so iOS's
  //    Undo can still operate on its undo manager, then refocus when
  //    didChangeMetrics reports the keyboard coming back.
  Timer? _focusRestoreTimer;
  bool _userHidKeyboard = false;
  bool _waitingForSystemDialog = false;
  double _lastKeyboardInsetBottom = 0;

  @override
  void initState() {
    super.initState();
    // Snapshot the note ONCE. The new-note placeholder is built inside the
    // route's builder closure, so a route rebuild (e.g. the offstage→onstage
    // flip when switching tabs) mints a fresh Note with a new id and swaps it
    // into widget.note. Persisting against the live widget.note would then
    // write to a never-inserted id (updateNote matches 0 rows) and silently
    // drop the edit. Pinning the id here keeps every save aimed at the row we
    // actually created.
    _note = widget.note;
    _isEditing = widget.isNew;
    _title = TextEditingController(text: _note.title);
    _content = TextEditingController(text: _note.content);
    _folderId = _note.folderId;
    _savedTitle = _note.title;
    _savedContent = _note.content;
    _savedFolderId = _note.folderId;
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
      _cancelFocusRestore();
      _userHidKeyboard = false;
      _waitingForSystemDialog = false;
      setState(() => _isEditing = true);
      return;
    }
    // Losing content focus (e.g. dismissing the keyboard, switching tabs,
    // tapping the title) must persist immediately — the debounce timer might
    // not fire before the app is killed or this view is torn down.
    _flushSave();

    // Case 1: user tapped the toolbar's hide-keyboard button. Exit editing
    // immediately; no system event will bring focus back.
    if (_userHidKeyboard) {
      _userHidKeyboard = false;
      _cancelFocusRestore();
      setState(() => _isEditing = false);
      return;
    }

    // Case 2: the app's own keyboard-appearance refresh stole the focus and
    // will refocus very soon. Keep the editor mounted across that gap with
    // a short safety net.
    if (KeyboardAppearanceRefresh.isActive) {
      _armRefreshSafetyNet();
      return;
    }

    // Case 3: iOS likely just resigned the field's first responder to show
    // the shake-to-undo dialog (or some other system overlay). Keep the
    // field mounted so iOS's undo manager remains operative on Undo, and
    // wait for the keyboard to come back (signalling the dialog has
    // dismissed) — at that point we refocus so the caret + toolbar return.
    // Fallback timer covers the case where the keyboard never returns
    // (e.g. shake-to-undo is disabled and the focus drop happened for some
    // other reason).
    _waitingForSystemDialog = true;
    _focusRestoreTimer?.cancel();
    _focusRestoreTimer = Timer(const Duration(seconds: 8), () {
      _focusRestoreTimer = null;
      if (!mounted) return;
      _waitingForSystemDialog = false;
      if (_contentFocus.hasFocus || _titleFocus.hasFocus) return;
      // Force-dismiss any lingering keyboard so the resting state matches
      // editing being off (no caret + no toolbar shouldn't share the screen
      // with an open keyboard).
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      setState(() => _isEditing = false);
    });
  }

  void _onTitleFocusChanged() {
    if (!mounted) return;
    if (_titleFocus.hasFocus) {
      // The user explicitly moved focus to the title — any pending
      // post-focus-drop check on the content field is moot.
      _cancelFocusRestore();
      _waitingForSystemDialog = false;
      return;
    }
    _flushSave();
  }

  void _hideKeyboardViaToolbar() {
    _userHidKeyboard = true;
    _contentFocus.unfocus();
  }

  void _cancelFocusRestore() {
    _focusRestoreTimer?.cancel();
    _focusRestoreTimer = null;
  }

  /// Keeps `_isEditing` latched while the keyboard-appearance refresh
  /// round-trips, then exits editing mode if no field regained focus —
  /// the refresh either failed or focus went elsewhere.
  void _armRefreshSafetyNet() {
    _focusRestoreTimer?.cancel();
    _focusRestoreTimer = Timer(const Duration(milliseconds: 1200), () {
      _focusRestoreTimer = null;
      if (!mounted) return;
      if (_contentFocus.hasFocus || _titleFocus.hasFocus) return;
      setState(() => _isEditing = false);
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final bottom = View.of(context).viewInsets.bottom;
    final wasDown = _lastKeyboardInsetBottom == 0;
    final isUp = bottom > 0;
    _lastKeyboardInsetBottom = bottom;

    if (!_waitingForSystemDialog) return;
    if (_contentFocus.hasFocus || _titleFocus.hasFocus) return;
    if (!(wasDown && isUp)) return;

    // The keyboard reappeared without us regaining focus — that's the
    // system shake-undo dialog dismissing (Cancel or Undo). Restore focus
    // so the caret + markdown toolbar come back and the user can continue
    // typing where they left off.
    _waitingForSystemDialog = false;
    _focusRestoreTimer?.cancel();
    _focusRestoreTimer = null;
    _contentFocus.requestFocus();
  }

  /// Called from [build] whenever the hosting tab's active state flips. When
  /// the tab goes offstage (the user switched to another tab), commit any
  /// pending text and drop focus, so the keyboard's input connection is torn
  /// down cleanly. Returning to the tab then re-opens the editor with a fresh
  /// connection (via a tap → [_startEditing]) instead of typing into a stale
  /// one whose characters never reach the controller — the root cause of
  /// edits being lost after a tab switch.
  void _handleTabActiveChange(bool active) {
    if (active == _tabActive) return;
    _tabActive = active;
    if (active) return;
    // Defer to a post-frame callback: we can't call unfocus()/setState while
    // the offstage transition is mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Mark the focus drops as deliberate so the listener takes the
      // immediate-exit path, skipping the system-dialog wait.
      _userHidKeyboard = true;
      _titleFocus.unfocus();
      _contentFocus.unfocus();
      _flushSave();
      // The listener may not fire if focus was already false — force the
      // exit transition so the body re-renders as preview and a fresh
      // editor is reopened on the user's next tap.
      _waitingForSystemDialog = false;
      _focusRestoreTimer?.cancel();
      _focusRestoreTimer = null;
      _userHidKeyboard = false;
      if (_isEditing) setState(() => _isEditing = false);
    });
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 1), _save);
  }

  /// Cancels any pending debounce and saves the current text right now.
  /// Awaitable so callers that can wait (lifecycle/pop) give the write a
  /// chance to finish before the process is suspended.
  Future<void> _flushSave() {
    _autosaveTimer?.cancel();
    return _save();
  }

  /// Serializes saves: only one write runs at a time, and any text change
  /// that arrives mid-write triggers exactly one more pass with the latest
  /// text. This prevents out-of-order writes and lost trailing edits.
  Future<void> _save() async {
    if (_deleted) return;
    if (_saving) {
      _resaveRequested = true;
      return;
    }
    _saving = true;
    try {
      do {
        _resaveRequested = false;
        await _persistOnce();
      } while (_resaveRequested && !_deleted && !_disposed);
    } finally {
      _saving = false;
    }
  }

  Future<void> _persistOnce() async {
    if (_deleted) return;
    final title = _title.text.trim();
    // Persist the body exactly as typed — trimming would silently drop leading
    // indentation (meaningful in markdown) and trailing blank lines. Captured
    // before any await so it stays valid even if the controllers are disposed
    // mid-flight (the final save fires from dispose()).
    final content = _content.text;
    final folderId = _folderId;
    if (widget.isNew && !_persistedNew) {
      if (title.isEmpty && content.trim().isEmpty) return;
      await widget.controller.addNote(
        _note.copyWith(
          title: title,
          content: content,
          folderId: folderId,
          clearFolderId: folderId == null,
        ),
      );
      // Advance the baseline only after the write lands (see below).
      _persistedNew = true;
      _savedTitle = title;
      _savedContent = content;
      _savedFolderId = folderId;
      return;
    }
    // Skip the write when nothing actually changed — otherwise copyWith bumps
    // modifiedDate and the note jumps to the top of its list on next sort.
    // Compared against the last-saved values (not the stale initial note) so a
    // genuine edit is never mistaken for "unchanged".
    if (title == _savedTitle &&
        content == _savedContent &&
        folderId == _savedFolderId) {
      return;
    }
    await widget.controller.updateNote(
      _note.copyWith(
        title: title,
        content: content,
        folderId: folderId,
        clearFolderId: folderId == null,
      ),
    );
    // Only advance the baseline once the write has actually completed. If the
    // write throws or is interrupted, the baseline stays behind so the next
    // save retries instead of being masked into a no-op (which would silently
    // drop the edit forever).
    _savedTitle = title;
    _savedContent = content;
    _savedFolderId = folderId;
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

  /// Entry point for the ⋯ menu. For a not-yet-persisted new note, commit it
  /// first so the menu's actions (Move / Info / Delete) operate on a real
  /// stored note rather than the empty placeholder.
  Future<void> _onMenuPressed() async {
    if (widget.isNew && !_persistedNew) {
      await _flushSave();
    }
    if (!mounted) return;
    _showDropdown(context);
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
          // Prefer the persisted copy so the timestamps reflect the latest
          // save (widget.note is the stale placeholder for a new note).
          final latest =
              widget.controller.noteById(_note.id) ?? _note;
          showItemInfoSheet(
            context,
            creationDate: latest.creationDate,
            modifiedDate: latest.modifiedDate,
          );
        },
        onDelete: () {
          dismiss();
          _deleted = true;
          final savedFolderId = _note.folderId;
          final undo = UndoScope.maybeOf(context);
          widget.controller.deleteNote(_note.id);
          undo?.show(
            label: S.of(context).noteTrashedToast,
            onUndo: () => widget.controller
                .restoreNote(_note.id, savedFolderId),
          );
          Navigator.of(context).pop();
        },
      );
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _autosaveTimer?.cancel();
    _focusRestoreTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Detach the change/focus listeners first so disposing the controllers
    // and focus nodes below can't re-enter the save path.
    _title.removeListener(_scheduleAutosave);
    _content.removeListener(_scheduleAutosave);
    _content.removeListener(_onContentSelectionChanged);
    _contentFocus.removeListener(_onContentFocusChanged);
    _titleFocus.removeListener(_onTitleFocusChanged);
    // Best-effort final save. `_persistOnce` reads the controllers
    // synchronously before its first await, so the in-flight write stays
    // valid even though we dispose them on the next lines.
    _save();
    _contentFocus.dispose();
    _titleFocus.dispose();
    _title.dispose();
    _content.dispose();
    _contentScroll.dispose();
    super.dispose();
  }

  void _startEditing({int? cursorOffset}) {
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _contentFocus.requestFocus();
      if (cursorOffset != null) {
        // Clamp against the live text length in case it changed between
        // the tap and the post-frame callback (autosave/race with edits).
        final length = _content.text.length;
        final clamped = cursorOffset.clamp(0, length);
        _content.selection = TextSelection.collapsed(offset: clamped);
      }
    });
  }

  /// Wraps [child] so a tap inside it switches into edit mode AND seeds
  /// the cursor at the position the user tapped. [textForOffset] is the
  /// source body text used to compute the offset; in markdown preview
  /// that's the raw markdown, so headings and bullets still resolve to
  /// somewhere reasonable. [contentPadding] is subtracted from the tap
  /// before measuring so the offset matches the rendered text geometry.
  Widget _wrapWithTapToEdit({
    required Widget child,
    required String textForOffset,
    required EdgeInsets contentPadding,
    TextStyle? measureStyle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final local = details.localPosition - Offset(
              contentPadding.left,
              contentPadding.top,
            );
            final width = constraints.maxWidth -
                contentPadding.left -
                contentPadding.right;
            final offset = tapOffsetInText(
              text: textForOffset,
              style: measureStyle ?? const TextStyle(fontSize: 16, height: 1.35),
              maxWidth: width <= 0 ? 1 : width,
              tapPosition: local,
              textScaler: MediaQuery.textScalerOf(context),
            );
            _startEditing(cursorOffset: offset);
          },
          child: child,
        );
      },
    );
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
            onTap: () => _startEditing(),
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
          // body verbatim. Tap-to-edit lands the cursor where the tap fell.
          const padding = EdgeInsets.fromLTRB(20, 16, 20, 24);
          child = _wrapWithTapToEdit(
            textForOffset: _content.text,
            contentPadding: padding,
            child: Padding(
              padding: padding,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text.rich(
                  TextSpan(
                    children: buildEmojiSpans(
                      _content.text,
                      const TextStyle(fontSize: 16, height: 1.35),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          const padding = EdgeInsets.fromLTRB(20, 16, 20, 24);
          // Markdown preview: the rendered text doesn't match the source
          // character-for-character (markers, list bullets, headings), so
          // we measure against the raw markdown with the body's paragraph
          // style — accurate for plain paragraphs and close enough for
          // bulleted lines to land the cursor on the tapped row.
          child = LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth - padding.left - padding.right;
              return MarkdownView(
                data: _content.text,
                shrinkWrap: true,
                padding: padding,
                onTap: (tapPosition) {
                  final local = tapPosition - Offset(padding.left, padding.top);
                  final offset = tapOffsetInText(
                    text: _content.text,
                    style: const TextStyle(fontSize: 16, height: 1.35),
                    maxWidth: width <= 0 ? 1 : width,
                    tapPosition: local,
                    textScaler: MediaQuery.textScalerOf(context),
                  );
                  _startEditing(cursorOffset: offset);
                },
              );
            },
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
    // Detect onstage/offstage transitions of the hosting tab (see
    // [_handleTabActiveChange]). Reading TickerMode here registers the
    // dependency so build re-runs when the tab is switched.
    _handleTabActiveChange(TickerMode.of(context));
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
            // Cancel any pending "restore focus" check so a focus drop
            // racing with the pop doesn't re-open the keyboard against
            // a half-disposed view.
            _cancelFocusRestore();
            _titleFocus.unfocus();
            _contentFocus.unfocus();
            // Forcibly close the keyboard at the platform layer. If our
            // FocusNode tracking ever diverges from the IME state (iOS
            // shake-undo + Cancel can leave the keyboard up with no Flutter
            // focus owner), unfocus() above is a no-op — explicitly hiding
            // guarantees the keyboard goes away when leaving the note.
            SystemChannels.textInput.invokeMethod('TextInput.hide');
            _flushSave();
          },
          child: CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              border: null,
              trailing: ListenableBuilder(
                // Rebuild only this button as the user types so its
                // enabled/grayed state tracks whether the note has any text.
                listenable: Listenable.merge([_title, _content]),
                builder: (context, _) {
                  // For an existing note the menu is always available; for a
                  // brand-new note it stays grayed out and inert until the
                  // user has entered a title or some body text.
                  final hasText = _title.text.trim().isNotEmpty ||
                      _content.text.trim().isNotEmpty;
                  final enabled = !widget.isNew || hasText;
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: enabled ? _onMenuPressed : null,
                    // When active, leave the color unset so the icon inherits
                    // the nav bar's action tint — matching every other ⋯ menu
                    // across the app. Only the inert (empty new-note) state
                    // gets the grayed-out tertiary color.
                    child: Icon(
                      CupertinoIcons.ellipsis,
                      size: 26,
                      color: enabled
                          ? null
                          : CupertinoColors.tertiaryLabel.resolveFrom(context),
                    ),
                  );
                },
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
                    onHideKeyboard: _hideKeyboardViaToolbar,
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
