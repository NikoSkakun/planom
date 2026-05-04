import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../folders/list_picker_sheet.dart';
import '../models/task.dart';
import 'calendar_date_picker.dart';
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

class _TaskDetailViewState extends State<TaskDetailView> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime? _dueDate;
  late int? _doTime;
  late bool _isCompleted;
  late String? _listId;
  late int _priority;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _note = TextEditingController(text: widget.task.note ?? '');
    _dueDate = widget.task.dueDate;
    _doTime = widget.task.doTime;
    _isCompleted = widget.task.isCompleted;
    _listId = widget.task.listId;
    _priority = widget.task.priority;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    await widget.controller.updateTask(widget.task.copyWith(
      title: title,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      dueDate: _dueDate,
      clearDueDate: _dueDate == null,
      doTime: _doTime,
      clearDoTime: _doTime == null,
      isCompleted: _isCompleted,
      listId: _listId,
      clearListId: _listId == null,
      priority: _priority,
    ));
    if (mounted) Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: SafeArea(
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
                    placeholder: 'Task name',
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
              child: CupertinoTextField(
                controller: _note,
                placeholder: 'Note',
                style: const TextStyle(fontSize: 15),
                decoration: const BoxDecoration(),
                maxLines: null,
              ),
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
                      const Text('Priority',
                          style: TextStyle(fontSize: 15)),
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
                        ? const Color(0xFFFF4D00)
                        : CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _dueDate != null
                        ? formatTaskDate(_dueDate!, doTime: _doTime)
                        : 'No Date',
                    style: TextStyle(
                      fontSize: 15,
                      color: _dueDate != null
                          ? const Color(0xFFFF4D00)
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
                    _listLabel,
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
          ],
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

  static const _labels = ['None', 'Low', 'Med', 'High'];
  static const _colors = [
    CupertinoColors.systemGrey,
    CupertinoColors.systemBlue,
    CupertinoColors.systemOrange,
    CupertinoColors.systemRed,
  ];

  @override
  Widget build(BuildContext context) {
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
              _labels[i],
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
        color: checked ? const Color(0xFFFF4D00) : null,
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
