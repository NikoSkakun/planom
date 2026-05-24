import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart' show WidgetsBindingObserver, AppLifecycleState;

import '../theme/app_theme.dart';
import '../utils/duration_picker.dart';

import '../folders/folder_controller.dart';
import '../folders/list_picker_sheet.dart';
import '../localization/strings.dart';
import '../models/recurrence.dart';
import '../models/tag.dart';
import '../models/task.dart';
import '../notes/markdown_toolbar.dart';
import '../notes/markdown_view.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/dropdown_row.dart';
import '../utils/fast_route.dart';
import '../utils/item_info_sheet.dart';
import '../utils/reminder_picker.dart';
import 'calendar_date_picker.dart';
import 'recurrence_picker.dart';
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
  bool _isEditingNote = false;
  Timer? _autosaveTimer;

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
    setState(() {
      if (!_noteFocus.hasFocus) _isEditingNote = false;
    });
  }

  void _startEditingNote() {
    setState(() => _isEditingNote = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _noteFocus.requestFocus();
    });
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), _save);
  }

  void _save() {
    if (_deleted) return;
    final title = _title.text.trim();
    if (title.isEmpty) return;
    widget.controller.updateTask(widget.task.copyWith(
      title: title,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
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
      _autosaveTimer?.cancel();
      _save();
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _save();
    _noteFocus.removeListener(_onNoteFocusChanged);
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
          widget.controller.deleteTask(widget.task.id);
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
  }

  Future<void> _pickList() async {
    final result = await showListPickerSheet(
      context,
      widget.folderController,
      _listId,
    );
    if (!mounted) return;
    setState(() => _listId = result);
  }

  Future<void> _pickDuration() async {
    final result = await showDurationPicker(context, _duration);
    if (!mounted) return;
    setState(() => _duration = result);
  }

  Future<void> _pickReminders() async {
    final result = await showReminderPicker(context, _reminderOffsets);
    if (!mounted || result == null) return;
    setState(() => _reminderOffsets = result);
    _save();
  }

  String _listLabel(BuildContext context) {
    final inbox = S.of(context).inbox;
    if (_listId == null) return inbox;
    return widget.folderController.listById(_listId!)?.name ?? inbox;
  }

  Widget _buildNoteArea() {
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
        onTap: _startEditingNote,
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
    return MarkdownView(
      data: _note.text,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      onTap: _startEditingNote,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final showToolbar = _noteFocus.hasFocus;
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
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: _buildNoteArea(),
                  ),
                  const SizedBox(height: 24),

                  // Priority picker
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(CupertinoIcons.flag_fill,
                                size: 16,
                                color: CupertinoColors.secondaryLabel),
                            const SizedBox(width: 10),
                            Text(s.priority,
                                style: const TextStyle(fontSize: 15)),
                            const Spacer(),
                            _PriorityPicker(
                              value: _priority,
                              onChanged: (v) =>
                                  setState(() => _priority = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date picker row
                  _SectionCard(
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 18,
                          color: _dueDate != null
                              ? AppColors.accent
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _dueDate != null
                              ? formatTaskDate(context, _dueDate!,
                                  doTime: _doTime)
                              : s.noDate,
                          style: TextStyle(
                            fontSize: 15,
                            color: _dueDate != null
                                ? AppColors.accent
                                : CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Repeat row — only meaningful when a date is set; the
                  // recurrence advance fires off the due date.
                  _SectionCard(
                    onTap: _dueDate == null ? null : _pickRecurrence,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.repeat,
                          size: 18,
                          color: _recurrence != null
                              ? AppColors.accent
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          formatRecurrence(
                              context, Recurrence.parse(_recurrence)),
                          style: TextStyle(
                            fontSize: 15,
                            color: _recurrence != null
                                ? AppColors.accent
                                : CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // List picker row
                  _SectionCard(
                    onTap: _pickList,
                    child: Row(
                      children: [
                        Image.asset(
                          _listId == null
                              ? 'assets/icons/inbox.png'
                              : 'assets/icons/list.png',
                          width: 18,
                          height: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _listLabel(context),
                          style: TextStyle(
                            fontSize: 15,
                            color:
                                CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Duration picker row
                  _SectionCard(
                    onTap: _pickDuration,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.timer,
                          size: 18,
                          color: _duration != null
                              ? AppColors.accent
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _duration != null
                              ? formatDuration(_duration!)
                              : s.noDuration,
                          style: TextStyle(
                            fontSize: 15,
                            color: _duration != null
                                ? AppColors.accent
                                : CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tag picker row — chips for selected tags + chevron
                  _SectionCard(
                    onTap: _pickTags,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.tag,
                          size: 18,
                          color: _tagIds.isNotEmpty
                              ? AppColors.accent
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _tagIds.isEmpty
                              ? Text(
                                  s.addTag,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                  ),
                                )
                              : ListenableBuilder(
                                  listenable: widget.controller,
                                  builder: (context, _) {
                                    final tags = _tagIds
                                        .map(widget.controller.tagById)
                                        .whereType<Tag>()
                                        .toList();
                                    return Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        for (final tag in tags)
                                          _TagChip(tag: tag),
                                      ],
                                    );
                                  },
                                ),
                        ),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Reminder row
                  _SectionCard(
                    onTap: _pickReminders,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.bell,
                          size: 18,
                          color: _reminderOffsets.isNotEmpty
                              ? AppColors.accent
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          formatReminderOffsets(_reminderOffsets, s),
                          style: TextStyle(
                            fontSize: 15,
                            color: _reminderOffsets.isNotEmpty
                                ? AppColors.accent
                                : CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
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
              onPromptLink: (selected) =>
                  showLinkPromptDialog(context, initialText: selected),
            ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context) {
    final accent = tag.color != null
        ? Color(tag.color!)
        : CupertinoColors.systemGrey.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 12,
          color: accent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static List<String> _labelsFor(BuildContext context) {
    final s = S.of(context);
    return [s.priorityNone, s.priorityLow, s.priorityMed, s.priorityHigh];
  }
  static const _colors = [
    CupertinoColors.systemGrey,
    CupertinoColors.systemBlue,
    CupertinoColors.systemOrange,
    CupertinoColors.systemRed,
  ];

  @override
  Widget build(BuildContext context) {
    final labels = _labelsFor(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final selected = value == i;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(left: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? _colors[i].withOpacity(0.15)
                  : CupertinoColors.systemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
              border: selected
                  ? Border.all(color: _colors[i], width: 1.5)
                  : null,
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 13,
                color: selected
                    ? _colors[i]
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
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
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: checked ? AppColors.accent : null,
        border: checked
            ? null
            : Border.all(
                color:
                    CupertinoColors.tertiaryLabel.resolveFrom(context),
                width: 1.5,
              ),
      ),
      child: checked
          ? const Icon(CupertinoIcons.checkmark,
              size: 13, color: CupertinoColors.white)
          : null,
    );
  }
}

