import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../folders/folder_controller.dart';
import '../folders/list_picker_sheet.dart';
import '../models/task.dart';
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
  DateTime? _dueDate;
  int? _doTime;
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
  }

  @override
  void dispose() {
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
      listId: _listId,
      priority: _priority,
    ));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
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

  String get _listLabel {
    if (_listId == null) return 'Inbox';
    return widget.folderController.listById(_listId!)?.name ?? 'Inbox';
  }

  String get _listIcon =>
      _listId == null ? 'assets/icons/inbox.png' : 'assets/icons/list.png';

  // Cycles None→Low→Med→High→None on tap
  void _cyclePriority() =>
      setState(() => _priority = (_priority + 1) % 4);

  static const _priorityLabels = ['', 'Low', 'Med', 'High'];
  static const _priorityColors = [
    CupertinoColors.systemGrey,
    CupertinoColors.systemBlue,
    CupertinoColors.systemOrange,
    CupertinoColors.systemRed,
  ];

  @override
  Widget build(BuildContext context) {
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
            placeholder: 'Task name',
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
            placeholder: 'Note',
            style: const TextStyle(fontSize: 15),
            decoration: const BoxDecoration(),
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
                          _listLabel,
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
                              ? const Color(0xFFFF4D00)
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _dueDate != null
                              ? formatTaskDate(_dueDate!, doTime: _doTime)
                              : 'Date',
                          style: TextStyle(
                            fontSize: 14,
                            color: _dueDate != null
                                ? const Color(0xFFFF4D00)
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
                            _priorityLabels[_priority],
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
                ],
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                color: _titleEmpty
                    ? CupertinoColors.tertiarySystemFill
                        .resolveFrom(context)
                    : const Color(0xFFFF4D00),
                borderRadius: BorderRadius.circular(22),
                onPressed: _titleEmpty ? null : _submit,
                child: Text(
                  'Add',
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
