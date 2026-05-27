import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../folders/list_picker_sheet.dart';
import '../localization/strings.dart';
import '../models/task.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/dropdown_row.dart';
import '../utils/fast_route.dart';
import '../utils/plus_button_inset_scope.dart';
import '../utils/selection_checkbox.dart';
import '../utils/selection_controller.dart';
import '../utils/selection_menu.dart';
import '../utils/selection_toolbar.dart';
import '../utils/undo_controller.dart';
import '../theme/app_theme.dart';
import 'calendar_date_picker.dart';
import 'task_controller.dart';
import 'task_detail_view.dart';
import 'task_row.dart';

/// Selection-aware shell shared by all smart-list task views (Inbox,
/// Today, Tomorrow, Upcoming, All Tasks, Completed). Renders a scrollable
/// list of [tasks] and, when the user picks "Select" from the nav-bar
/// ⋯ menu, switches into multi-select mode with a bottom batch-action
/// toolbar.
class SelectableTaskListShell extends StatefulWidget {
  const SelectableTaskListShell({
    super.key,
    required this.title,
    required this.taskController,
    required this.folderController,
    required this.tasks,
    this.emptyText,
    this.beforeContent,
  });

  /// Title shown in the navigation bar.
  final String title;
  final TaskController taskController;
  final FolderController folderController;

  /// Live snapshot of the tasks to render. The shell rebuilds whenever
  /// the controller fires, so callers can pass an unmodifiable view.
  final List<Task> Function() tasks;

  /// Text shown when [tasks] is empty. Defaults to "No tasks".
  final String? emptyText;

  /// Optional widget inserted before the task list — used by views that
  /// want to render extra context (e.g. a date header).
  final Widget? beforeContent;

  @override
  State<SelectableTaskListShell> createState() =>
      _SelectableTaskListShellState();
}

class _SelectableTaskListShellState extends State<SelectableTaskListShell>
    with DropdownOverlayMixin {
  final _selection = SelectionController();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _showOptionsDropdown(BuildContext context) {
    showDropdown(context, (dismiss) {
      return _ShellOptionsDropdown(
        onDismiss: dismiss,
        onSelect: () {
          dismiss();
          _selection.start();
        },
      );
    });
  }

  // ── Batch actions ────────────────────────────────────────────────────────

  Future<void> _batchDelete() async {
    for (final id in _selection.selectedIds.toList()) {
      await widget.taskController.deleteTask(id);
    }
    _selection.cancel();
  }

  Future<void> _batchToggleCompleted() async {
    final ids = _selection.selectedIds.toList();
    final tasks =
        ids.map(widget.taskController.taskById).whereType<Task>().toList();
    final allCompleted =
        tasks.isNotEmpty && tasks.every((t) => t.isCompleted);
    for (final t in tasks) {
      if (allCompleted && !t.isCompleted) continue;
      if (!allCompleted && t.isCompleted) continue;
      await widget.taskController.toggleCompleted(t.id);
    }
    _selection.cancel();
  }

  Future<void> _batchSetDate() async {
    final result = await showCalendarDatePicker(context);
    if (result == null || !mounted) return;
    for (final id in _selection.selectedIds.toList()) {
      final t = widget.taskController.taskById(id);
      if (t == null) continue;
      await widget.taskController.updateTask(t.copyWith(
        dueDate: result.$1,
        clearDueDate: result.$1 == null,
        doTime: result.$2,
        clearDoTime: result.$2 == null,
      ));
    }
    _selection.cancel();
  }

  Future<void> _batchSetPriority() async {
    final s = S.of(context);
    final picked = await showSelectionMenu<int>(
      context: context,
      title: s.priority,
      options: [
        SelectionMenuOption(value: 0, label: s.priorityNone),
        SelectionMenuOption(value: 1, label: s.priorityLow),
        SelectionMenuOption(value: 2, label: s.priorityMed),
        SelectionMenuOption(value: 3, label: s.priorityHigh),
      ],
    );
    if (picked == null) return;
    for (final id in _selection.selectedIds.toList()) {
      final t = widget.taskController.taskById(id);
      if (t == null) continue;
      await widget.taskController.updateTask(t.copyWith(priority: picked));
    }
    _selection.cancel();
  }

  Future<void> _batchMoveToList() async {
    final picked = await showListPickerSheet(
      context,
      widget.folderController,
      null,
    );
    if (!mounted) return;
    for (final id in _selection.selectedIds.toList()) {
      final t = widget.taskController.taskById(id);
      if (t == null) continue;
      await widget.taskController.updateTask(t.copyWith(
        listId: picked,
        clearListId: picked == null,
        clearSectionId: true,
      ));
    }
    _selection.cancel();
  }

  Future<void> _batchDuplicate() async {
    for (final id in _selection.selectedIds.toList()) {
      final t = widget.taskController.taskById(id);
      if (t == null) continue;
      await widget.taskController.addTask(Task(
        title: t.title,
        note: t.note,
        dueDate: t.dueDate,
        doTime: t.doTime,
        duration: t.duration,
        listId: t.listId,
        priority: t.priority,
        reminderOffsets: List.of(t.reminderOffsets),
        tagIds: List.of(t.tagIds),
        recurrence: t.recurrence,
        sectionId: t.sectionId,
      ));
    }
    _selection.cancel();
  }

  void _toggleSelectAll(List<Task> tasks) {
    final allIds = tasks.map((t) => t.id).toSet();
    final allSelected = allIds.isNotEmpty &&
        _selection.selectedIds.containsAll(allIds) &&
        _selection.count >= allIds.length;
    if (allSelected) {
      _selection.replaceAll(const [], SelectionItemKind.task);
    } else {
      _selection.replaceAll(allIds, SelectionItemKind.task);
    }
  }

  List<SelectionAction> _batchActions(S s) {
    final empty = _selection.isEmpty;
    return [
      SelectionAction(
        label: s.done,
        icon: CupertinoIcons.checkmark_circle,
        onTap: empty ? () {} : _batchToggleCompleted,
      ),
      SelectionAction(
        label: s.dateLabel,
        icon: CupertinoIcons.calendar,
        onTap: empty ? () {} : _batchSetDate,
      ),
      SelectionAction(
        label: s.priority,
        icon: CupertinoIcons.flag,
        onTap: empty ? () {} : _batchSetPriority,
      ),
      SelectionAction(
        label: s.moveTo,
        icon: CupertinoIcons.tray,
        onTap: empty ? () {} : _batchMoveToList,
      ),
      SelectionAction(
        label: s.duplicate,
        icon: CupertinoIcons.doc_on_doc,
        onTap: empty ? () {} : _batchDuplicate,
      ),
      SelectionAction(
        label: s.delete,
        icon: CupertinoIcons.trash,
        onTap: empty ? () {} : _batchDelete,
        isDestructive: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable:
          Listenable.merge([widget.taskController, _selection]),
      builder: (context, _) {
        final tasks = widget.tasks();
        final selecting = _selection.active;
        final allIds = tasks.map((t) => t.id).toSet();
        final allSelected = allIds.isNotEmpty &&
            _selection.selectedIds.containsAll(allIds) &&
            _selection.count >= allIds.length;
        return PlusButtonLift(
          lift: selecting ? kSelectionToolbarLift : 0,
          child: CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              border: null,
              leading: selecting
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _selection.cancel,
                      child: Text(s.cancel),
                    )
                  : null,
              automaticallyImplyLeading: !selecting,
              middle: Text(selecting
                  ? (_selection.count == 0
                      ? s.selectItems
                      : s.selectedCount(_selection.count))
                  : widget.title),
              trailing: selecting
                  ? (tasks.isEmpty
                      ? null
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _toggleSelectAll(tasks),
                          child:
                              Text(allSelected ? s.deselectAll : s.selectAll),
                        ))
                  : Semantics(
                      label: s.settings,
                      button: true,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showOptionsDropdown(context),
                        child:
                            const Icon(CupertinoIcons.ellipsis, size: 26),
                      ),
                    ),
            ),
            child: SafeArea(
              bottom: !selecting,
              child: Column(
                children: [
                  if (widget.beforeContent != null) widget.beforeContent!,
                  Expanded(
                    child: tasks.isEmpty
                        ? Center(
                            child: Text(
                              widget.emptyText ?? s.noTasks,
                              style: const TextStyle(
                                  color: CupertinoColors.secondaryLabel),
                            ),
                          )
                        : ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (context, i) {
                              final task = tasks[i];
                              return _buildTaskItem(context, task);
                            },
                          ),
                  ),
                  if (selecting)
                    SelectionToolbar(
                      bottomInset: MediaQuery.paddingOf(context).bottom,
                      actions: _batchActions(s),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(BuildContext context, Task task) {
    if (_selection.active) {
      final selected = _selection.isSelected(task.id);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            _selection.toggle(task.id, SelectionItemKind.task),
        child: Container(
          color: selected ? AppColors.accent.withOpacity(0.10) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              SelectionCheckbox(checked: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    color: task.isCompleted
                        ? CupertinoColors.secondaryLabel
                            .resolveFrom(context)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: const TaskDeleteBackground(),
      onDismissed: (_) {
        final savedListId = task.listId;
        widget.taskController.deleteTask(task.id);
        UndoScope.maybeOf(context)?.show(
          label: S.of(context).taskTrashedToast,
          onUndo: () =>
              widget.taskController.restoreTask(task.id, savedListId),
        );
      },
      child: TaskRow(
        task: task,
        onToggle: () => widget.taskController.toggleCompleted(task.id),
        onTap: () => Navigator.of(context).push(
          FastRoute<void>(
            settings: const RouteSettings(name: TaskDetailView.routeName),
            builder: (_) => TaskDetailView(
              task: task,
              controller: widget.taskController,
              folderController: widget.folderController,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellOptionsDropdown extends StatelessWidget {
  const _ShellOptionsDropdown({
    required this.onDismiss,
    required this.onSelect,
  });

  final VoidCallback onDismiss;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.paddingOf(context).top + 44.0 + 4.0;
    final s = S.of(context);
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
            child: DropdownRow(
              label: s.select,
              icon: CupertinoIcons.checkmark_circle,
              onTap: onSelect,
            ),
          ),
        ),
      ],
    );
  }
}
