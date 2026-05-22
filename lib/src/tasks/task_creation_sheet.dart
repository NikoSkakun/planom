import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../folders/folder_controller.dart';
import '../folders/list_picker_sheet.dart';
import '../localization/strings.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';
import 'calendar_date_picker.dart';
import 'task_controller.dart';

void showTaskCreationSheet(
  BuildContext context,
  TaskController controller,
  FolderController folderController, {
  String? initialListId,
  DateTime? initialDueDate,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => TaskCreationSheet(
      controller: controller,
      folderController: folderController,
      initialListId: initialListId,
      initialDueDate: initialDueDate,
    ),
  );
}

class TaskCreationSheet extends StatefulWidget {
  const TaskCreationSheet({
    super.key,
    required this.controller,
    required this.folderController,
    this.initialListId,
    this.initialDueDate,
  });

  final TaskController controller;
  final FolderController folderController;
  final String? initialListId;
  final DateTime? initialDueDate;

  @override
  State<TaskCreationSheet> createState() => _TaskCreationSheetState();
}

class _TaskCreationSheetState extends State<TaskCreationSheet> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final _noteFocus = FocusNode();
  FocusNode? _activeFocus;
  DateTime? _dueDate;
  int? _doTime;
  int? _duration;
  late String? _listId;
  int _priority = 0;
  bool _titleEmpty = true;

  @override
  void initState() {
    super.initState();
    _listId = widget.initialListId;
    _dueDate = widget.initialDueDate;
    _titleCtrl.addListener(() {
      final empty = _titleCtrl.text.trim().isEmpty;
      if (empty != _titleEmpty) setState(() => _titleEmpty = empty);
    });
    _titleFocus.addListener(_onFocusChange);
    _noteFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_titleFocus.hasFocus) _activeFocus = _titleFocus;
    if (_noteFocus.hasFocus) _activeFocus = _noteFocus;
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onFocusChange);
    _noteFocus.removeListener(_onFocusChange);
    _titleFocus.dispose();
    _noteFocus.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    await widget.controller.addTask(Task(
      title: title,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      dueDate: _dueDate,
      doTime: _doTime,
      duration: _duration,
      listId: _listId,
      priority: _priority,
    ));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _pickDate() async {
    final saved = _activeFocus;
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
    saved?.requestFocus();
  }

  Future<void> _pickList() async {
    final saved = _activeFocus;
    final result = await showListPickerSheet(
      context,
      widget.folderController,
      _listId,
    );
    if (!mounted) return;
    setState(() => _listId = result);
    saved?.requestFocus();
  }

  Future<void> _pickDuration() async {
    final saved = _activeFocus;
    final result = await _showDurationPicker(context, _duration);
    if (!mounted) return;
    setState(() => _duration = result);
    saved?.requestFocus();
  }

  String _listLabel(BuildContext context) {
    final inbox = S.of(context).inbox;
    if (_listId == null) return inbox;
    return widget.folderController.listById(_listId!)?.name ?? inbox;
  }

  String get _listIcon =>
      _listId == null ? 'assets/icons/inbox.png' : 'assets/icons/list.png';

  // Cycles None→Low→Med→High→None on tap
  void _cyclePriority() =>
      setState(() => _priority = (_priority + 1) % 4);

  List<String> _priorityLabels(BuildContext context) {
    final s = S.of(context);
    return ['', s.priorityLow, s.priorityMed, s.priorityHigh];
  }
  static const _priorityColors = [
    CupertinoColors.systemGrey,
    CupertinoColors.systemBlue,
    CupertinoColors.systemOrange,
    CupertinoColors.systemRed,
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bg = CupertinoColors.systemBackground.resolveFrom(context);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding:
          EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.separator.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          CupertinoTextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            placeholder: s.taskName,
            autofocus: true,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w500),
            decoration: const BoxDecoration(),
          ),
          Container(
            height: 0.5,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _noteCtrl,
            focusNode: _noteFocus,
            placeholder: s.note,
            style: const TextStyle(fontSize: 15),
            decoration: const BoxDecoration(),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // List picker
                  GestureDetector(
                    onTap: _pickList,
                    child: Row(
                      children: [
                        ImageIcon(
                          AssetImage(_listIcon),
                          size: 18,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _listLabel(context),
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Date picker
                  GestureDetector(
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 16,
                          color: _dueDate != null
                              ? AppColors.accent
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _dueDate != null
                              ? formatTaskDate(context, _dueDate!,
                                  doTime: _doTime)
                              : s.dateLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: _dueDate != null
                                ? AppColors.accent
                                : CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Priority toggle
                  GestureDetector(
                    onTap: _cyclePriority,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.flag_fill,
                          size: 15,
                          color: _priority == 0
                              ? CupertinoColors.secondaryLabel
                                  .resolveFrom(context)
                              : _priorityColors[_priority],
                        ),
                        if (_priority > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            _priorityLabels(context)[_priority],
                            style: TextStyle(
                              fontSize: 13,
                              color: _priorityColors[_priority],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Duration picker
                  GestureDetector(
                    onTap: _pickDuration,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.timer,
                          size: 16,
                          color: _duration != null
                              ? AppColors.accent
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                        if (_duration != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(_duration!),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                color: _titleEmpty
                    ? CupertinoColors.tertiarySystemFill
                        .resolveFrom(context)
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(22),
                onPressed: _titleEmpty ? null : _submit,
                child: Text(
                  s.add,
                  style: TextStyle(
                    color: _titleEmpty
                        ? CupertinoColors.tertiaryLabel
                            .resolveFrom(context)
                        : CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

Future<int?> _showDurationPicker(BuildContext context, int? current) async {
  const presets = [15, 30, 45, 60, 90, 120, 180, 240];
  final s = S.of(context);
  final result = await showSelectionMenu<int>(
    context: context,
    title: s.duration,
    current: current,
    options: [
      for (final m in presets)
        SelectionMenuOption(value: m, label: _formatDuration(m)),
      if (current != null)
        SelectionMenuOption(value: -1, label: s.clear, isDestructive: true),
    ],
  );
  if (result == null) return current;
  if (result == -1) return null;
  return result;
}
