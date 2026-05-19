import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

import '../folders/folder_controller.dart';
import '../folders/list_picker_sheet.dart';
import '../models/task.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/item_info_sheet.dart';
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

class _TaskDetailViewState extends State<TaskDetailView>
    with DropdownOverlayMixin {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime? _dueDate;
  late int? _doTime;
  late int? _duration;
  late bool _isCompleted;
  late String? _listId;
  late int _priority;
  bool _deleted = false;

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
  }

  @override
  void dispose() {
    if (!_deleted) {
    final title = _title.text.trim();
    if (title.isNotEmpty) {
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
      ));
    }
    }
    _title.dispose();
    _note.dispose();
    super.dispose();
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
    final result = await _showDurationPicker(context, _duration);
    if (!mounted) return;
    setState(() => _duration = result);
  }

  String get _listLabel {
    if (_listId == null) return 'Inbox';
    return widget.folderController.listById(_listId!)?.name ?? 'Inbox';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showDropdown(context),
          child: const Icon(CupertinoIcons.ellipsis, size: 26),
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
                textCapitalization: TextCapitalization.sentences,
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
                        ? AppColors.accent
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
                        ? _formatDuration(_duration!)
                        : 'No Duration',
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
            constraints: const BoxConstraints(minWidth: 160),
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

String _formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

Future<int?> _showDurationPicker(BuildContext context, int? current) async {
  const presets = [15, 30, 45, 60, 90, 120, 180, 240];
  return showCupertinoModalPopup<int?>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('Duration'),
      actions: [
        for (final m in presets)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(m),
            child: Text(_formatDuration(m)),
          ),
        if (current != null)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(-1),
            child: const Text('Clear'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('Cancel'),
      ),
    ),
  ).then((v) {
    if (v == null) return current;
    if (v == -1) return null;
    return v;
  });
}
