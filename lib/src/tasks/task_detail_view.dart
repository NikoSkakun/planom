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
  late bool _isCompleted;
  late String? _listId;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _note = TextEditingController(text: widget.task.note ?? '');
    _dueDate = widget.task.dueDate;
    _isCompleted = widget.task.isCompleted;
    _listId = widget.task.listId;
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
      isCompleted: _isCompleted,
      listId: _listId,
      clearListId: _listId == null,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final result = await showCalendarDatePicker(context, initial: _dueDate);
    // null means "No Date" was tapped, which returns null from dialog
    // If user dismissed by tapping barrier, result is also null — treat same way
    if (!mounted) return;
    setState(() => _dueDate = result);
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            // Date picker row
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
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
                          ? formatTaskDate(_dueDate!)
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
            ),
            const SizedBox(height: 12),
            // List picker row
            GestureDetector(
              onTap: _pickList,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
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
                        color: CupertinoColors.label.resolveFrom(context),
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
            ),
          ],
        ),
      ),
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
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
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
