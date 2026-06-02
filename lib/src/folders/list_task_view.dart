import 'package:flutter/cupertino.dart';

import '../contacts/contact_controller.dart';
import '../contacts/contact_list_view.dart';
import '../localization/strings.dart';
import '../models/app_list.dart';
import '../models/list_section.dart';
import '../models/list_type.dart';
import '../models/task.dart';
import '../tasks/calendar_date_picker.dart';
import '../tasks/complete_with_undo.dart';
import '../tasks/completed_section_header.dart';
import '../tasks/task_controller.dart';
import '../tasks/task_detail_view.dart';
import '../tasks/task_row.dart';
import '../theme/app_theme.dart';
import '../utils/animated_task_list.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import '../utils/item_info_sheet.dart';
import '../utils/plus_button_inset_scope.dart';
import '../utils/plus_drag_controller.dart';
import '../utils/plus_drag_payload.dart';
import '../utils/reorder_drag.dart';
import '../utils/selection_checkbox.dart';
import '../utils/selection_controller.dart';
import '../utils/selection_menu.dart';
import '../utils/selection_toolbar.dart';
import '../utils/undo_controller.dart';
import 'create_folder_list_sheet.dart';
import 'folder_controller.dart';
import 'item_description_block.dart';
import 'kanban_board.dart';
import 'list_picker_sheet.dart';
import 'move_to_sheet.dart';
import 'section_name_sheet.dart';

/// Sentinel column id for the implicit "no section" group in the list Kanban
/// board (maps to a null sectionId).
const String _kTopColumnId = '__top__';

enum _ListViewMode { list, kanban }

class ListTaskView extends StatefulWidget {
  const ListTaskView({
    super.key,
    required this.list,
    required this.taskController,
    required this.folderController,
    required this.contactController,
    required this.activeListId,
  });

  final AppList list;
  final TaskController taskController;
  final FolderController folderController;
  final ContactController contactController;
  final ValueNotifier<String?> activeListId;

  @override
  State<ListTaskView> createState() => _ListTaskViewState();
}

class _ListTaskViewState extends State<ListTaskView>
    with DropdownOverlayMixin {
  late AppList _currentList;
  final _selection = SelectionController();
  _ListViewMode _viewMode = _ListViewMode.list;

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.activeListId.value = widget.list.id;
    });
  }

  @override
  void dispose() {
    widget.activeListId.value = null;
    _selection.dispose();
    super.dispose();
  }

  void _showDropdown(BuildContext context) {
    showDropdown(context, (dismiss) {
      return _ListOptionsDropdown(
        onDismiss: dismiss,
        isKanban: _viewMode == _ListViewMode.kanban,
        onView: _currentList.listType == ListType.birthdays
            ? null
            : () {
                dismiss();
                _pickViewMode();
              },
        onSelect: _currentList.listType == ListType.birthdays
            ? null
            : () {
                dismiss();
                _selection.start();
              },
        onEdit: () {
          dismiss();
          _openEditSheet();
        },
        onMoveTo: () {
          dismiss();
          showMoveToSheet(
            context,
            folderController: widget.folderController,
            currentParentId: _currentList.folderId,
            onMove: (folderId) async {
              final updated = folderId == null
                  ? _currentList.copyWith(clearFolder: true)
                  : _currentList.copyWith(folderId: folderId);
              await widget.folderController.updateList(updated);
              if (mounted) setState(() => _currentList = updated);
            },
          );
        },
        onAddSection: _currentList.listType == ListType.birthdays
            ? null
            : () {
                dismiss();
                _addSection();
              },
        onInfo: () {
          dismiss();
          showItemInfoSheet(context, creationDate: _currentList.creationDate);
        },
        onDelete: () {
          dismiss();
          _deleteThisList(context);
        },
      );
    });
  }

  // ── Batch actions ────────────────────────────────────────────────────────

  Future<void> _batchDelete() async {
    final ids = _selection.selectedIds.toList();
    if (ids.isEmpty) return;
    for (final id in ids) {
      await widget.taskController.deleteTask(id);
    }
    _selection.cancel();
  }

  Future<void> _batchToggleCompleted() async {
    final ids = _selection.selectedIds.toList();
    if (ids.isEmpty) return;
    // If every selected task is already completed, uncomplete them all;
    // otherwise complete the ones that aren't.
    final tasks = ids
        .map(widget.taskController.taskById)
        .whereType<Task>()
        .toList();
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
    final ids = _selection.selectedIds.toList();
    for (final id in ids) {
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
    final ids = _selection.selectedIds.toList();
    for (final id in ids) {
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
      _currentList.id,
    );
    if (!mounted) return;
    final ids = _selection.selectedIds.toList();
    for (final id in ids) {
      final t = widget.taskController.taskById(id);
      if (t == null) continue;
      await widget.taskController.updateTask(t.copyWith(
        listId: picked,
        clearListId: picked == null,
        // Moving to a different list clears the section assignment.
        clearSectionId: picked != _currentList.id,
      ));
    }
    _selection.cancel();
  }

  Future<void> _batchDuplicate() async {
    final ids = _selection.selectedIds.toList();
    for (final id in ids) {
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

  Future<void> _addSection() async {
    final name = await showSectionNameSheet(context);
    if (name == null || !mounted) return;
    final order = widget.folderController
            .sectionsForList(_currentList.id)
            .length +
        1;
    await widget.folderController.addSection(ListSection(
      listId: _currentList.id,
      name: name,
      sortOrder: order,
    ));
  }

  Future<void> _pickViewMode() async {
    final s = S.of(context);
    final picked = await showSelectionMenu<_ListViewMode>(
      context: context,
      title: s.viewLabel,
      current: _viewMode,
      options: [
        SelectionMenuOption(
          value: _ListViewMode.list,
          label: s.viewAsList,
          icon: CupertinoIcons.list_bullet,
        ),
        SelectionMenuOption(
          value: _ListViewMode.kanban,
          label: s.viewAsKanban,
          icon: CupertinoIcons.square_split_2x1,
        ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _viewMode = picked);
  }

  /// Moves a task into the section identified by [toColumnId] when a Kanban
  /// card is dropped onto another column. The sentinel id maps to the implicit
  /// "no section" group (null sectionId).
  void _moveTaskToColumn(String taskId, String toColumnId) {
    final sectionId = toColumnId == _kTopColumnId ? null : toColumnId;
    final task = widget.taskController.taskById(taskId);
    if (task == null || task.sectionId == sectionId) return;
    widget.taskController.moveTaskToSection(taskId, sectionId);
  }

  Widget _buildKanbanBody(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.taskController,
        widget.folderController,
      ]),
      builder: (context, _) {
        final s = S.of(context);
        final sections =
            widget.folderController.sectionsForList(_currentList.id);
        final completed =
            widget.taskController.completedTasksForList(_currentList.id);

        List<Task> tasksFor(String? sectionId) => [
              ...widget.taskController
                  .tasksForListSection(_currentList.id, sectionId),
              ...completed.where((t) => t.sectionId == sectionId),
            ];

        final columns = <KanbanColumnData>[
          KanbanColumnData(
            id: _kTopColumnId,
            title: s.noSectionTitle,
            accentColor: _currentList.color != null
                ? Color(_currentList.color!)
                : null,
            tasks: tasksFor(null),
          ),
          for (final section in sections)
            KanbanColumnData(
              id: section.id,
              title: section.name,
              tasks: tasksFor(section.id),
            ),
        ];

        return KanbanBoard(
          columns: columns,
          emptyLabel: s.noTasks,
          onMoveTask: _moveTaskToColumn,
          onToggleTask: (task) => toggleTaskCompletedWithUndo(
              context, widget.taskController, task),
          onTapTask: (task) => Navigator.of(context).push(
            FastRoute<void>(
              settings: const RouteSettings(name: TaskDetailView.routeName),
              builder: (_) => TaskDetailView(
                task: task,
                controller: widget.taskController,
                folderController: widget.folderController,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditSheet() async {
    final result = await showEditItemSheet(
      context,
      args: EditItemArgs(
        name: _currentList.name,
        iconId: _currentList.iconId,
        iconColor: _currentList.iconColor,
        color: _currentList.color,
        isFolder: false,
        supportsColor: true,
        description: _currentList.description,
      ),
    );
    if (result == null || !mounted) return;
    final updated = _currentList.copyWith(
      name: result.name,
      iconId: result.iconId,
      clearIconId: result.iconId == null,
      iconColor: result.iconColor,
      clearIconColor: result.iconColor == null,
      color: result.color,
      clearColor: result.color == null,
      description: result.description,
      clearDescription: result.description == null,
    );
    await widget.folderController.updateList(updated);
    if (mounted) setState(() => _currentList = updated);
  }

  Future<void> _deleteThisList(BuildContext context) async {
    final s = S.of(context);
    final confirmed = await confirmMoveToTrash(
      context,
      name: _currentList.name,
      body: s.moveToTrashListBody,
    );
    if (!confirmed || !mounted) return;
    final ts = DateTime.now();
    final undo = UndoScope.maybeOf(context);
    await widget.taskController.deleteTasksForList(_currentList.id, ts);
    await widget.contactController
        .deleteContactsForList(_currentList.id, ts);
    await widget.folderController.deleteList(_currentList.id);
    undo?.show(
      label: s.listTrashedToast,
      onUndo: () async {
        await widget.folderController
            .restoreList(_currentList.id, _currentList.folderId);
        await widget.taskController.restoreAt(ts);
        await widget.contactController.restoreAt(ts);
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        final selecting = _selection.active;
        final s = S.of(context);
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
                  : _currentList.name),
              trailing: selecting
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _toggleSelectAll,
                      child: Text(_areAllSelected()
                          ? s.deselectAll
                          : s.selectAll),
                    )
                  : CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _showDropdown(context),
                      child: const Icon(CupertinoIcons.ellipsis, size: 26),
                    ),
            ),
            child: SafeArea(
              bottom: !selecting,
              child: Column(
                children: [
                  if (!selecting &&
                      (_currentList.description ?? '').trim().isNotEmpty)
                    ItemDescriptionBlock(
                      description: _currentList.description!.trim(),
                    ),
                  Expanded(
                    child: _currentList.listType == ListType.birthdays
                        ? ContactListView(
                            listId: _currentList.id,
                            controller: widget.contactController,
                          )
                        : (_viewMode == _ListViewMode.kanban && !selecting)
                            ? _buildKanbanBody(context)
                            : _SectionedListBody(
                                list: _currentList,
                                taskController: widget.taskController,
                                folderController: widget.folderController,
                                selection: _selection,
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

  /// Returns every (non-completed) task id in the active list — used by
  /// the "Select All" button.
  Iterable<String> _allTaskIds() sync* {
    final sections =
        widget.folderController.sectionsForList(_currentList.id);
    for (final t in widget.taskController
        .tasksForListSection(_currentList.id, null)) {
      yield t.id;
    }
    for (final section in sections) {
      for (final t in widget.taskController
          .tasksForListSection(_currentList.id, section.id)) {
        yield t.id;
      }
    }
  }

  bool _areAllSelected() {
    final all = _allTaskIds().toSet();
    if (all.isEmpty) return false;
    return _selection.selectedIds.containsAll(all) &&
        _selection.count >= all.length;
  }

  void _toggleSelectAll() {
    if (_areAllSelected()) {
      _selection.replaceAll(const [], SelectionItemKind.task);
    } else {
      _selection.replaceAll(_allTaskIds(), SelectionItemKind.task);
    }
  }
}

/// Sectioned body for a regular Tasks/Shopping list. Renders:
///   1. The implicit "top" section — tasks with no sectionId
///   2. Each user-defined section (collapsible)
///   3. The implicit "Completed" section at the bottom (always present
///      when at least one completed task exists)
///
/// Tasks can be dragged between sections by long-pressing and dropping
/// onto a section header.
class _SectionedListBody extends StatefulWidget {
  const _SectionedListBody({
    required this.list,
    required this.taskController,
    required this.folderController,
    required this.selection,
  });

  final AppList list;
  final TaskController taskController;
  final FolderController folderController;
  final SelectionController selection;

  @override
  State<_SectionedListBody> createState() => _SectionedListBodyState();
}

class _SectionedListBodyState extends State<_SectionedListBody> {
  bool _completedExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.taskController,
        widget.folderController,
        widget.selection,
      ]),
      builder: (context, _) {
        final sections =
            widget.folderController.sectionsForList(widget.list.id);
        final topTasks = widget.taskController
            .tasksForListSection(widget.list.id, null);
        final completed = widget.taskController
            .completedTasksForList(widget.list.id);

        final hasAny = topTasks.isNotEmpty ||
            sections.isNotEmpty ||
            completed.isNotEmpty;
        if (!hasAny) {
          return Center(
            child: Text(
              S.of(context).noTasks,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          );
        }

        final children = <Widget>[];

        // Top "no section" group — no header; tasks render directly.
        // Each task is wrapped in a DragTarget that, on drop, inserts the
        // dragged task immediately before it (within the same list+section).
        if (topTasks.isNotEmpty) {
          children.add(AnimatedItemList<Task>(
            key: const ValueKey('top-tasks'),
            items: topTasks,
            idOf: (t) => t.id,
            itemBuilder: (ctx, task) => _buildDraggableTask(
              ctx,
              task,
              sectionId: null,
              beforeId: task.id,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ));
        }
        // Trailing slot to drop at the end of the top group.
        children.add(_buildTaskDropSlot(context, null, null));

        for (final section in sections) {
          final secTasks = widget.taskController
              .tasksForListSection(widget.list.id, section.id);
          children.add(_SectionHeader(
            section: section,
            onToggleCollapsed: () => widget.folderController
                .toggleSectionCollapsed(section.id),
            onRename: () async {
              final name = await showSectionNameSheet(
                context,
                initial: section.name,
                title: S.of(context).rename,
              );
              if (name == null) return;
              await widget.folderController
                  .updateSection(section.copyWith(name: name));
            },
            onDelete: () async {
              await widget.folderController.deleteSection(section.id);
              // Tasks in this section fall back to the "no section" top group.
              for (final t in secTasks) {
                await widget.taskController
                    .moveTaskToSection(t.id, null);
              }
            },
            onAcceptTask: (taskId) =>
                widget.taskController.moveTaskToSection(taskId, section.id),
          ));
          if (!section.isCollapsed) {
            if (secTasks.isNotEmpty) {
              children.add(AnimatedItemList<Task>(
                key: ValueKey('section-${section.id}'),
                items: secTasks,
                idOf: (t) => t.id,
                itemBuilder: (ctx, task) => _buildDraggableTask(
                  ctx,
                  task,
                  sectionId: section.id,
                  beforeId: task.id,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
              ));
            }
            // Trailing slot inside this section.
            children.add(_buildTaskDropSlot(context, null, section.id));
          }
        }

        // Implicit "Completed" virtual section — always shown when there's
        // at least one completed task; cannot be edited or deleted.
        if (completed.isNotEmpty) {
          children.add(CompletedSectionHeader(
            count: completed.length,
            expanded: _completedExpanded,
            onToggle: () =>
                setState(() => _completedExpanded = !_completedExpanded),
          ));
          if (_completedExpanded) {
            children.add(AnimatedItemList<Task>(
              key: const ValueKey('completed-tasks'),
              items: completed,
              idOf: (t) => t.id,
              itemBuilder: (ctx, task) => _buildTaskRow(ctx, task),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ));
          }
        }

        return ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 80),
          children: children,
        );
      },
    );
  }

  /// Wraps a task row so:
  ///   • Long-pressing starts a drag with the task id.
  ///   • Hovering another task triggers a reorder-insert-before drop target.
  /// When the selection controller is active, drag/reorder is suppressed and
  /// tapping the row toggles selection instead of opening the detail view.
  Widget _buildDraggableTask(
    BuildContext context,
    Task task, {
    required String? sectionId,
    required String beforeId,
  }) {
    if (widget.selection.active) {
      return _buildTaskRow(context, task);
    }
    return _TaskReorderRow(
      task: task,
      beforeId: beforeId,
      sectionId: sectionId,
      listId: widget.list.id,
      taskController: widget.taskController,
      child: _buildTaskRow(context, task),
    );
  }

  /// Trailing drop zone after the last task in a section so the user can
  /// drop a task at the very end of that section.
  Widget _buildTaskDropSlot(
      BuildContext context, String? beforeId, String? sectionId) {
    return _TaskReorderTrailingSlot(
      listId: widget.list.id,
      sectionId: sectionId,
      taskController: widget.taskController,
    );
  }

  Widget _buildTaskRow(BuildContext context, Task task) {
    if (widget.selection.active) {
      final selected = widget.selection.isSelected(task.id);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            widget.selection.toggle(task.id, SelectionItemKind.task),
        child: Container(
          color: selected
              ? AppColors.accent.withOpacity(0.10)
              : null,
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
        onToggle: () => toggleTaskCompletedWithUndo(
            context, widget.taskController, task),
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

/// Long-press-to-drag wrapper for a task row. Collapses the source slot to
/// zero (animated) while the drag is in flight and reports the row's height
/// to [ReorderDragNotifier] so the matching drop zones can render an empty
/// placeholder of the right size.
class _TaskReorderRow extends StatefulWidget {
  const _TaskReorderRow({
    required this.task,
    required this.beforeId,
    required this.sectionId,
    required this.listId,
    required this.taskController,
    required this.child,
  });

  final Task task;
  final String beforeId;
  final String? sectionId;
  final String listId;
  final TaskController taskController;
  final Widget child;

  @override
  State<_TaskReorderRow> createState() => _TaskReorderRowState();
}

class _TaskReorderRowState extends State<_TaskReorderRow> {
  final GlobalKey _measureKey = GlobalKey();

  double _measureHeight() {
    final ctx = _measureKey.currentContext;
    final renderObject = ctx?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size.height;
    }
    return 44;
  }

  void _onDragStarted() {
    ReorderDragNotifier.instance
        .start(widget.task.id, 'task', _measureHeight());
  }

  void _onDragEnded() {
    ReorderDragNotifier.instance.end();
  }

  @override
  void dispose() {
    if (ReorderDragNotifier.instance.draggingId == widget.task.id) {
      ReorderDragNotifier.instance.end();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedbackWidth = MediaQuery.sizeOf(context).width;
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: LongPressDraggable<String>(
        data: widget.task.id,
        delay: const Duration(milliseconds: 400),
        onDragStarted: _onDragStarted,
        onDragEnd: (_) => _onDragEnded(),
        onDraggableCanceled: (_, __) => _onDragEnded(),
        onDragCompleted: _onDragEnded,
        // Render the actual row as the drag feedback so the lifted
        // card matches the source row exactly (checkbox, date, list
        // chip, multi-line wrapping, …) instead of a stripped-down
        // title-only placeholder.
        feedback: buildReorderDragFeedback(context, feedbackWidth, widget.child),
        childWhenDragging: const SizedBox.shrink(),
        child: DragTarget<String>(
          onWillAcceptWithDetails: (d) => d.data != widget.task.id,
          onAcceptWithDetails: (d) =>
              widget.taskController.reorderTaskBefore(
            movedTaskId: d.data,
            beforeTaskId: widget.beforeId,
            listId: widget.listId,
            sectionId: widget.sectionId,
          ),
          builder: (context, candidates, _) {
            final highlighted = candidates.isNotEmpty;
            return AnimatedBuilder(
              animation: ReorderDragNotifier.instance,
              builder: (context, _) {
                final placeholder = highlighted
                    ? ReorderDragNotifier.instance.draggingHeight
                    : 0.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                          height: placeholder, width: double.infinity),
                    ),
                    KeyedSubtree(
                      key: _measureKey,
                      child: widget.child,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Trailing slot after the last task in a section. Stays at a tiny constant
/// height when idle (so the user has somewhere to aim for an end-of-list
/// drop) and grows to the dragged row's height while hovering.
class _TaskReorderTrailingSlot extends StatelessWidget {
  const _TaskReorderTrailingSlot({
    required this.listId,
    required this.sectionId,
    required this.taskController,
  });

  final String listId;
  final String? sectionId;
  final TaskController taskController;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => taskController.reorderTaskBefore(
        movedTaskId: d.data,
        beforeTaskId: null,
        listId: listId,
        sectionId: sectionId,
      ),
      builder: (context, candidates, _) {
        return AnimatedBuilder(
          animation: ReorderDragNotifier.instance,
          builder: (context, _) {
            final hovering = candidates.isNotEmpty;
            final placeholder = hovering
                ? ReorderDragNotifier.instance.draggingHeight
                : 0.0;
            return AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: hovering ? placeholder : 12,
                width: double.infinity,
              ),
            );
          },
        );
      },
    );
  }
}

/// Header row for a user-defined section. Tap to expand/collapse, long-press
/// for rename/delete, accepts task drops via the DragTarget overlay.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.section,
    required this.onToggleCollapsed,
    required this.onRename,
    required this.onDelete,
    required this.onAcceptTask,
  });

  final ListSection section;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final Future<void> Function(String taskId) onAcceptTask;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) {
        final data = d.data;
        if (data is String) {
          onAcceptTask(data);
        } else if (data is PlusDragPayload) {
          PlusDragScope.of(context)
              ?.onDropOnSection
              ?.call(section.listId, section.id);
        }
      },
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return GestureDetector(
          onTap: onToggleCollapsed,
          onLongPress: () => _showSectionMenu(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.accent.withOpacity(0.15)
                  : null,
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: section.isCollapsed ? -0.25 : 0,
                  child: Icon(
                    CupertinoIcons.chevron_down,
                    size: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSectionMenu(BuildContext context) async {
    final s = S.of(context);
    final choice = await showSelectionMenu<String>(
      context: context,
      title: section.name,
      options: [
        SelectionMenuOption(
          value: 'rename',
          label: s.rename,
          icon: CupertinoIcons.pencil,
        ),
        SelectionMenuOption(
          value: 'delete',
          label: s.delete,
          icon: CupertinoIcons.trash,
          isDestructive: true,
        ),
      ],
    );
    if (choice == 'rename') {
      onRename();
    } else if (choice == 'delete') {
      onDelete();
    }
  }
}

class _ListOptionsDropdown extends StatelessWidget {
  const _ListOptionsDropdown({
    required this.onDismiss,
    required this.onEdit,
    required this.onMoveTo,
    required this.onInfo,
    required this.onDelete,
    required this.isKanban,
    this.onView,
    this.onAddSection,
    this.onSelect,
  });

  final VoidCallback onDismiss;
  final VoidCallback onEdit;
  final VoidCallback onMoveTo;
  final VoidCallback onInfo;
  final VoidCallback onDelete;
  final bool isKanban;
  final VoidCallback? onView;
  final VoidCallback? onAddSection;
  final VoidCallback? onSelect;

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
          child: _DropdownPanel(
            items: [
              if (onView != null)
                _DropdownItem(
                    label: S.of(context).viewLabel,
                    icon: isKanban
                        ? CupertinoIcons.square_split_2x1
                        : CupertinoIcons.list_bullet,
                    onTap: onView!),
              if (onSelect != null)
                _DropdownItem(
                    label: S.of(context).select,
                    icon: CupertinoIcons.checkmark_circle,
                    onTap: onSelect!),
              _DropdownItem(
                  label: S.of(context).editList,
                  icon: CupertinoIcons.pencil,
                  onTap: onEdit),
              if (onAddSection != null)
                _DropdownItem(
                    label: S.of(context).addSection,
                    icon: CupertinoIcons.text_alignleft,
                    onTap: onAddSection!),
              _DropdownItem(
                  label: S.of(context).moveTo,
                  icon: CupertinoIcons.folder,
                  onTap: onMoveTo),
              _DropdownItem(
                  label: S.of(context).info,
                  icon: CupertinoIcons.info,
                  onTap: onInfo),
              _DropdownItem(
                  label: S.of(context).delete,
                  icon: CupertinoIcons.trash,
                  onTap: onDelete,
                  color: CupertinoColors.destructiveRed),
            ],
          ),
        ),
      ],
    );
  }
}

class _DropdownPanel extends StatelessWidget {
  const _DropdownPanel({required this.items});

  final List<_DropdownItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                height: 0.5,
                color: CupertinoColors.separator.resolveFrom(context),
              ),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _DropdownItem extends StatelessWidget {
  const _DropdownItem({
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
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: effectiveColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: effectiveColor),
            ),
          ),
        ],
      ),
    );
  }
}
