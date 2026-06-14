import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter/widgets.dart' show WidgetsBindingObserver, AppLifecycleState;

import '../theme/app_theme.dart';
import '../utils/duration_picker.dart';

import '../folders/folder_controller.dart';
import '../folders/list_picker_sheet.dart';
import '../localization/strings.dart';
import '../models/recurrence.dart';
import '../models/task.dart';
import '../notes/markdown_toolbar.dart';
import '../notes/markdown_view.dart';
import '../spaces/space_manager.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/dropdown_row.dart';
import '../utils/fast_route.dart';
import '../utils/item_info_sheet.dart';
import '../utils/keyboard_insets.dart';
import '../utils/reminder_picker.dart';
import '../utils/selection_menu.dart';
import '../utils/tap_offset.dart';
import '../utils/undo_controller.dart';
import 'calendar_date_picker.dart';
import 'recurrence_picker.dart';
import 'task_field_prefs.dart';
import 'tag_picker_sheet.dart';
import 'task_controller.dart';

class TaskDetailView extends StatefulWidget {
  const TaskDetailView({
    super.key,
    required this.task,
    required this.controller,
    required this.folderController,
  });

  static const routeName = 'task_detail';

  final Task task;
  final TaskController controller;
  final FolderController folderController;

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView>
    with DropdownOverlayMixin, WidgetsBindingObserver {
  late final TextEditingController _title;
  late final TextEditingController _note;
  final FocusNode _noteFocus = FocusNode();
  final TextEditingController _newSubtask = TextEditingController();
  final FocusNode _newSubtaskFocus = FocusNode();
  late DateTime? _dueDate;
  late int? _doTime;
  late int? _duration;
  late List<int> _reminderOffsets;
  late List<String> _tagIds;
  late String? _recurrence;
  late bool _isCompleted;
  late String? _listId;
  late int _priority;
  bool _deleted = false;
  bool _disposed = false;
  bool _isEditingNote = false;
  Timer? _autosaveTimer;

  // Deferred handling for note focus loss, mirroring NoteDetailView. See
  // its block comment for the full reasoning. Three cases:
  //   - User tapped the toolbar's hide-keyboard button → exit immediately.
  //   - KeyboardAppearanceRefresh stole focus → short safety net.
  //   - iOS shake-to-undo dialog stole focus → keep the field mounted (so
  //     Undo can operate on its undo manager) and refocus once the
  //     keyboard reappears (didChangeMetrics).
  Timer? _noteFocusRestoreTimer;
  bool _userHidKeyboard = false;
  bool _waitingForSystemDialog = false;
  double _lastKeyboardInsetBottom = 0;

  // Single-flight guard for the async save: only one write runs at a time,
  // and any change arriving mid-write queues exactly one more pass with the
  // latest text, so writes stay ordered and trailing edits are never dropped.
  bool _saving = false;
  bool _resaveRequested = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _note = TextEditingController(text: widget.task.note ?? '');
    _dueDate = widget.task.dueDate;
    _doTime = widget.task.doTime;
    _duration = widget.task.duration;
    _isCompleted = widget.task.isCompleted;
    _listId = widget.task.listId;
    _priority = widget.task.priority;
    _reminderOffsets = List.of(widget.task.reminderOffsets);
    _tagIds = List.of(widget.task.tagIds);
    _recurrence = widget.task.recurrence;
    _title.addListener(_scheduleAutosave);
    _note.addListener(_scheduleAutosave);
    _noteFocus.addListener(_onNoteFocusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onNoteFocusChanged() {
    if (!mounted) return;
    if (_noteFocus.hasFocus) {
      _noteFocusRestoreTimer?.cancel();
      _noteFocusRestoreTimer = null;
      _userHidKeyboard = false;
      _waitingForSystemDialog = false;
      setState(() {});
      return;
    }
    // Losing note focus (keyboard dismissed, tab switch, tapping elsewhere)
    // must persist immediately — the debounce might not fire before the view
    // is torn down or the process is killed.
    _flushSave();

    // Hide-button tap: exit editing now; no system event will bring focus
    // back.
    if (_userHidKeyboard) {
      _userHidKeyboard = false;
      _noteFocusRestoreTimer?.cancel();
      _noteFocusRestoreTimer = null;
      setState(() => _isEditingNote = false);
      return;
    }

    // Keyboard-appearance refresh window: short safety net.
    if (KeyboardAppearanceRefresh.isActive) {
      _noteFocusRestoreTimer?.cancel();
      _noteFocusRestoreTimer = Timer(const Duration(milliseconds: 1200), () {
        _noteFocusRestoreTimer = null;
        if (!mounted || _noteFocus.hasFocus) return;
        setState(() => _isEditingNote = false);
      });
      return;
    }

    // Probable iOS shake-undo dialog. Keep the field mounted so iOS's undo
    // manager remains usable. didChangeMetrics will refocus when the
    // keyboard returns; a long fallback covers the case where it never does.
    _waitingForSystemDialog = true;
    _noteFocusRestoreTimer?.cancel();
    _noteFocusRestoreTimer = Timer(const Duration(seconds: 8), () {
      _noteFocusRestoreTimer = null;
      if (!mounted) return;
      _waitingForSystemDialog = false;
      if (_noteFocus.hasFocus) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      setState(() => _isEditingNote = false);
    });
  }

  void _hideNoteKeyboardViaToolbar() {
    _userHidKeyboard = true;
    _noteFocus.unfocus();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final bottom = View.of(context).viewInsets.bottom;
    final wasDown = _lastKeyboardInsetBottom == 0;
    final isUp = bottom > 0;
    _lastKeyboardInsetBottom = bottom;
    if (!_waitingForSystemDialog) return;
    if (_noteFocus.hasFocus) return;
    if (!(wasDown && isUp)) return;
    // Keyboard came back without focus → system dialog dismissed. Refocus
    // so the caret + toolbar return.
    _waitingForSystemDialog = false;
    _noteFocusRestoreTimer?.cancel();
    _noteFocusRestoreTimer = null;
    _noteFocus.requestFocus();
  }

  void _startEditingNote({int? cursorOffset}) {
    setState(() => _isEditingNote = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _noteFocus.requestFocus();
      if (cursorOffset != null) {
        final length = _note.text.length;
        final clamped = cursorOffset.clamp(0, length);
        _note.selection = TextSelection.collapsed(offset: clamped);
      }
    });
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), _save);
  }

  /// Cancels any pending debounce and saves now. Awaitable so callers that
  /// can wait (lifecycle/pop) give the write a chance to land first.
  Future<void> _flushSave() {
    _autosaveTimer?.cancel();
    return _save();
  }

  /// Serializes saves so only one write runs at a time and the newest text
  /// always wins, even when several triggers (debounce, focus loss, pop,
  /// lifecycle) fire close together.
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
    // Persist the note body exactly as typed — trimming would silently drop
    // leading indentation (meaningful in markdown) and trailing blank lines.
    // Only a completely empty field maps to "no note". Captured before any
    // await so it stays valid even when the final save fires from dispose().
    final noteText = _note.text;
    final note = noteText.isEmpty ? null : noteText;
    // Don't drop a non-empty note just because the title was momentarily
    // cleared — only skip the write when there's genuinely nothing to save.
    if (title.isEmpty && noteText.trim().isEmpty) return;
    await widget.controller.updateTask(widget.task.copyWith(
      title: title,
      note: note,
      clearNote: note == null,
      dueDate: _dueDate,
      clearDueDate: _dueDate == null,
      doTime: _doTime,
      clearDoTime: _doTime == null,
      duration: _duration,
      clearDuration: _duration == null,
      isCompleted: _isCompleted,
      listId: _listId,
      clearListId: _listId == null,
      priority: _priority,
      reminderOffsets: _reminderOffsets,
      tagIds: _tagIds,
      recurrence: _recurrence,
      clearRecurrence: _recurrence == null,
    ));
  }

  Future<void> _pickRecurrence() async {
    final result = await showRecurrencePicker(
      context,
      Recurrence.parse(_recurrence),
    );
    if (!mounted || result == null) return;
    setState(() => _recurrence = result.value?.toJson());
    _save();
  }

  Future<void> _pickTags() async {
    final result = await showTagPickerSheet(
      context,
      widget.controller,
      initialSelected: _tagIds,
    );
    if (!mounted || result == null) return;
    setState(() => _tagIds = result);
    _save();
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

  @override
  void dispose() {
    _disposed = true;
    _autosaveTimer?.cancel();
    _noteFocusRestoreTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Detach the change/focus listeners first so disposing the controllers
    // and focus node below can't re-enter the save path.
    _title.removeListener(_scheduleAutosave);
    _note.removeListener(_scheduleAutosave);
    _noteFocus.removeListener(_onNoteFocusChanged);
    // Best-effort final save. `_persistOnce` reads the controllers
    // synchronously before its first await, so the in-flight write stays
    // valid even though we dispose them on the next lines.
    _save();
    _noteFocus.dispose();
    _title.dispose();
    _note.dispose();
    _newSubtask.dispose();
    _newSubtaskFocus.dispose();
    super.dispose();
  }

  void _addSubtask() {
    final text = _newSubtask.text.trim();
    if (text.isEmpty) return;
    // Inherit the parent's list so the subtree stays scoped to a single list,
    // but never inherit the date — subtasks default to no due date.
    widget.controller.addTask(Task(
      title: text,
      listId: widget.task.listId,
      parentTaskId: widget.task.id,
    ));
    _newSubtask.clear();
    // Re-focus so the user can chain-enter several subtasks in a row.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _newSubtaskFocus.requestFocus();
    });
  }

  void _openSubtask(Task subtask) {
    Navigator.of(context).push(FastRoute<void>(
      settings: const RouteSettings(name: TaskDetailView.routeName),
      builder: (_) => TaskDetailView(
        task: subtask,
        controller: widget.controller,
        folderController: widget.folderController,
      ),
    ));
  }

  void _showDropdown(BuildContext context) {
    showDropdown(context, (dismiss) {
      return _TaskOptionsDropdown(
        onDismiss: dismiss,
        onMoveTo: () {
          dismiss();
          _pickList();
        },
        onInfo: () {
          dismiss();
          showItemInfoSheet(
            context,
            creationDate: widget.task.creationDate,
            completionDate: widget.task.completionDate,
          );
        },
        onDelete: () {
          dismiss();
          _deleted = true;
          final savedListId = widget.task.listId;
          final undo = UndoScope.maybeOf(context);
          widget.controller.deleteTask(widget.task.id);
          undo?.show(
            label: S.of(context).taskTrashedToast,
            onUndo: () => widget.controller
                .restoreTask(widget.task.id, savedListId),
          );
          Navigator.of(context).pop();
        },
      );
    });
  }

  Future<void> _pickDate() async {
    final result = await showCalendarDatePicker(
      context,
      initial: _dueDate,
      initialDoTime: _doTime,
    );
    if (!mounted || result == null) return;
    setState(() {
      _dueDate = result.$1;
      _doTime = result.$2;
    });
    // Persist immediately so other views (e.g. Calendar) reflect the new date
    // without waiting for the debounced autosave or for this screen to close.
    _save();
  }

  Future<void> _pickList() async {
    final result = await showListPickerSheet(
      context,
      widget.folderController,
      _listId,
    );
    if (!mounted) return;
    setState(() => _listId = result);
    _save();
  }

  Future<void> _pickDuration() async {
    final result = await showDurationPicker(context, _duration);
    if (!mounted) return;
    setState(() => _duration = result);
    _save();
  }

  Future<void> _pickReminders() async {
    final result = await showReminderPicker(context, _reminderOffsets);
    if (!mounted || result == null) return;
    setState(() => _reminderOffsets = result);
    _save();
  }

  Future<void> _showPriorityMenu(BuildContext context) async {
    final s = S.of(context);
    final labels = [
      s.priorityNone,
      s.priorityLow,
      s.priorityMed,
      s.priorityHigh,
    ];
    final result = await showSelectionMenu<int>(
      context: context,
      title: s.priority,
      current: _priority,
      options: [
        for (int i = 0; i < labels.length; i++)
          SelectionMenuOption(value: i, label: labels[i]),
      ],
    );
    if (result != null && mounted) {
      setState(() => _priority = result);
      _save();
    }
  }

  static String _priorityShortLabel(S s, int p) {
    switch (p) {
      case 1:
        return s.priorityLow;
      case 2:
        return s.priorityMed;
      case 3:
        return s.priorityHigh;
      default:
        return s.priorityNone;
    }
  }

  static Color _priorityColor(int p) {
    switch (p) {
      case 1:
        return CupertinoColors.systemBlue;
      case 2:
        return CupertinoColors.systemOrange;
      case 3:
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _listLabel(BuildContext context) {
    final inbox = S.of(context).inbox;
    if (_listId == null) return inbox;
    return widget.folderController.listById(_listId!)?.name ?? inbox;
  }

  Widget _buildNoteArea({required bool useMarkdown}) {
    final notePlaceholder = S.of(context).note;
    if (_isEditingNote || _noteFocus.hasFocus) {
      return CupertinoTextField(
        controller: _note,
        focusNode: _noteFocus,
        placeholder: notePlaceholder,
        style: const TextStyle(fontSize: 16, height: 1.35),
        decoration: const BoxDecoration(),
        padding: EdgeInsets.zero,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
      );
    }
    if (_note.text.trim().isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _startEditingNote(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            notePlaceholder,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.placeholderText.resolveFrom(context),
            ),
          ),
        ),
      );
    }
    if (!useMarkdown) {
      const padding = EdgeInsets.symmetric(vertical: 4);
      return LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final local = details.localPosition - Offset(
                padding.left,
                padding.top,
              );
              final width = constraints.maxWidth -
                  padding.left -
                  padding.right;
              final offset = tapOffsetInText(
                text: _note.text,
                style: const TextStyle(fontSize: 16, height: 1.35),
                maxWidth: width <= 0 ? 1 : width,
                tapPosition: local,
                textScaler: MediaQuery.textScalerOf(context),
              );
              _startEditingNote(cursorOffset: offset);
            },
            child: Padding(
              padding: padding,
              child: Text(
                _note.text,
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            ),
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return MarkdownView(
          data: _note.text,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          // The tap location lands inside MarkdownView's body at this
          // local position — measure against the raw markdown to seed
          // the cursor at the tapped row.
          onTap: (tapPosition) {
            final offset = tapOffsetInText(
              text: _note.text,
              style: const TextStyle(fontSize: 16, height: 1.35),
              maxWidth: constraints.maxWidth <= 0 ? 1 : constraints.maxWidth,
              tapPosition: tapPosition,
              textScaler: MediaQuery.textScalerOf(context),
            );
            _startEditingNote(cursorOffset: offset);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final showToolbar = _noteFocus.hasFocus;
    final settingsCtl = SpaceManagerProvider.maybeOf(context)?.settingsController;
    return ListenableBuilder(
      listenable: settingsCtl ?? const _NoopListenable(),
      builder: (context, _) {
        final fields = settingsCtl?.taskFieldPrefs;
        final showPriority = fields?.showPriority ?? true;
        final showDate = fields?.showDate ?? true;
        final showRepeat = fields?.showRepeat ?? true;
        final showList = fields?.showList ?? true;
        final showDuration = fields?.showDuration ?? true;
        final showTags = fields?.showTags ?? true;
        final showReminders = fields?.showReminders ?? true;
        final useMarkdown = fields?.useMarkdown ?? true;
        return PopScope(
          // The pop completes immediately for iOS swipe-back; unfocusing here
          // commits any in-flight IME composition into the controllers before
          // dispose() runs the final save, so the last typed word isn't lost.
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            // Cancel any pending "restore focus" check so it can't re-open
            // the keyboard against the popped route.
            _noteFocusRestoreTimer?.cancel();
            _noteFocusRestoreTimer = null;
            _noteFocus.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
            _flushSave();
          },
          child: _buildScaffold(
            context,
            s,
            showToolbar && useMarkdown,
            showPriority: showPriority,
            showDate: showDate,
            showRepeat: showRepeat,
            showList: showList,
            showDuration: showDuration,
            showTags: showTags,
            showReminders: showReminders,
            useMarkdown: useMarkdown,
          ),
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    S s,
    bool showToolbar, {
    required bool showPriority,
    required bool showDate,
    required bool showRepeat,
    required bool showList,
    required bool showDuration,
    required bool showTags,
    required bool showReminders,
    required bool useMarkdown,
  }) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        trailing: Semantics(
          label: s.info,
          button: true,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showDropdown(context),
            child: const Icon(CupertinoIcons.ellipsis, size: 26),
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _isCompleted = !_isCompleted),
                          child: _RoundedCheckbox(checked: _isCompleted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _title,
                          placeholder: s.taskName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                          decoration: const BoxDecoration(),
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  // Compact options strip — one row of icons (and short
                  // value chips for date/priority) sitting right below the
                  // title, replacing seven full-width cards.
                  Padding(
                    padding: const EdgeInsets.only(left: 34, top: 8),
                    child: _OptionsStrip(
                      pills: [
                        if (showPriority)
                          _OptionPill(
                            icon: CupertinoIcons.flag_fill,
                            label: _priority > 0
                                ? _priorityShortLabel(s, _priority)
                                : null,
                            color: _priority > 0
                                ? _priorityColor(_priority)
                                : null,
                            onTap: () => _showPriorityMenu(context),
                          ),
                        if (showDate)
                          _OptionPill(
                            icon: CupertinoIcons.calendar,
                            label: _dueDate != null
                                ? formatTaskDate(context, _dueDate!,
                                    doTime: _doTime)
                                : null,
                            onTap: _pickDate,
                          ),
                        if (showRepeat)
                          _OptionPill(
                            icon: CupertinoIcons.repeat,
                            label: _recurrence != null
                                ? formatRecurrence(context,
                                    Recurrence.parse(_recurrence))
                                : null,
                            onTap:
                                _dueDate == null ? null : _pickRecurrence,
                          ),
                        if (showList)
                          _OptionPill(
                            icon: CupertinoIcons.tray,
                            label: _listId != null
                                ? _listLabel(context)
                                : null,
                            onTap: _pickList,
                          ),
                        if (showDuration)
                          _OptionPill(
                            icon: CupertinoIcons.timer,
                            label: _duration != null
                                ? formatDuration(_duration!)
                                : null,
                            onTap: _pickDuration,
                          ),
                        if (showTags)
                          _OptionPill(
                            icon: CupertinoIcons.tag,
                            label: _tagIds.isEmpty
                                ? null
                                : '${_tagIds.length}',
                            onTap: _pickTags,
                          ),
                        if (showReminders)
                          _OptionPill(
                            icon: CupertinoIcons.bell,
                            label: _reminderOffsets.isEmpty
                                ? null
                                : '${_reminderOffsets.length}',
                            onTap: _pickReminders,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: _buildNoteArea(useMarkdown: useMarkdown),
                  ),
                  const SizedBox(height: 24),

                  // Subtasks — only on top-level tasks; nesting beyond one
                  // level adds tree-management cost for little user value.
                  if (widget.task.parentTaskId == null)
                    ListenableBuilder(
                      listenable: widget.controller,
                      builder: (context, _) {
                        final subs = widget.controller
                            .subtasksOf(widget.task.id);
                        return _SubtasksSection(
                          subtasks: subs,
                          newCtrl: _newSubtask,
                          newFocus: _newSubtaskFocus,
                          onAdd: _addSubtask,
                          onToggle: (id) =>
                              widget.controller.toggleCompleted(id),
                          onOpen: _openSubtask,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          if (showToolbar)
            MarkdownToolbar(
              controller: _note,
              focusNode: _noteFocus,
              onHideKeyboard: _hideNoteKeyboardViaToolbar,
              onPromptLink: (selected) =>
                  showLinkPromptDialog(context, initialText: selected),
            ),
        ],
      ),
    );
  }
}

/// Stand-in [Listenable] for [ListenableBuilder] when no real notifier is
/// available, so the call site can keep the same widget shape either way.
class _NoopListenable extends Listenable {
  const _NoopListenable();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _SubtasksSection extends StatelessWidget {
  const _SubtasksSection({
    required this.subtasks,
    required this.newCtrl,
    required this.newFocus,
    required this.onAdd,
    required this.onToggle,
    required this.onOpen,
  });

  final List<Task> subtasks;
  final TextEditingController newCtrl;
  final FocusNode newFocus;
  final VoidCallback onAdd;
  final ValueChanged<String> onToggle;
  final ValueChanged<Task> onOpen;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final done = subtasks.where((t) => t.isCompleted).length;
    final headerLabel = subtasks.isEmpty
        ? s.subtasks.toUpperCase()
        : '${s.subtasks.toUpperCase()}  $done/${subtasks.length}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            headerLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (int i = 0; i < subtasks.length; i++) ...[
                _SubtaskRow(
                  task: subtasks[i],
                  onToggle: () => onToggle(subtasks[i].id),
                  onOpen: () => onOpen(subtasks[i]),
                ),
                if (i < subtasks.length)
                  Container(
                    height: 0.5,
                    margin: const EdgeInsets.only(left: 44),
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.add_circled,
                      size: 20,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoTextField(
                        controller: newCtrl,
                        focusNode: newFocus,
                        placeholder: s.addSubtask,
                        style: const TextStyle(fontSize: 15),
                        decoration: const BoxDecoration(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => onAdd(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.task,
    required this.onToggle,
    required this.onOpen,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: task.title,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 2, vertical: 2),
                  child: _RoundedCheckbox(checked: task.isCompleted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    color: task.isCompleted
                        ? CupertinoColors.secondaryLabel.resolveFrom(context)
                        : CupertinoColors.label.resolveFrom(context),
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color:
                    CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrollable strip of [_OptionPill] buttons sitting under the
/// task title. Compact alternative to the old stack of full-width cards.
class _OptionsStrip extends StatelessWidget {
  const _OptionsStrip({required this.pills});

  final List<_OptionPill> pills;

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => pills[i],
      ),
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.icon,
    required this.onTap,
    this.label,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final hasValue = label != null;
    final disabled = onTap == null;
    final accent = color ?? AppColors.accent;
    final fg = disabled
        ? CupertinoColors.tertiaryLabel.resolveFrom(context)
        : hasValue
            ? accent
            : CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = hasValue && !disabled
        ? accent.withOpacity(0.12)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            if (hasValue) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskOptionsDropdown extends StatelessWidget {
  const _TaskOptionsDropdown({
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
            decoration: AppColors.menuDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownRow(
                  label: S.of(context).moveTo,
                  icon: CupertinoIcons.folder,
                  onTap: onMoveTo,
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                DropdownRow(
                  label: S.of(context).info,
                  icon: CupertinoIcons.info,
                  onTap: onInfo,
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
                DropdownRow(
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

class _RoundedCheckbox extends StatelessWidget {
  const _RoundedCheckbox({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final style = TaskCheckboxAppearance.current;
    final borderColor = CupertinoColors.tertiaryLabel.resolveFrom(context);
    final BoxDecoration deco;
    switch (style) {
      case TaskCheckboxStyle.sharpRect:
        deco = BoxDecoration(
          color: checked ? AppColors.accent : null,
          border: checked ? null : Border.all(color: borderColor, width: 1.5),
        );
      case TaskCheckboxStyle.circle:
        deco = BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? AppColors.accent : null,
          border: checked ? null : Border.all(color: borderColor, width: 1.5),
        );
      case TaskCheckboxStyle.roundedRect:
        deco = BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: checked ? AppColors.accent : null,
          border: checked ? null : Border.all(color: borderColor, width: 1.5),
        );
    }
    final size = 22 * AppScale.factor;
    return Container(
      width: size,
      height: size,
      decoration: deco,
      child: checked
          ? Icon(CupertinoIcons.checkmark,
              size: 13 * AppScale.factor,
              color: CupertinoColors.white)
          : null,
    );
  }
}

