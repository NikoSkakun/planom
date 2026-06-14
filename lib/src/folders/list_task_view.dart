import 'package:flutter/cupertino.dart';

import '../contacts/contact_controller.dart';
import '../contacts/contact_list_view.dart';
import '../localization/strings.dart';
import '../models/app_list.dart';
import '../models/list_section.dart';
import '../models/list_type.dart';
import '../models/task.dart';
import '../models/view_mode.dart';
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
import '../utils/notifier_reset.dart';
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
  final _kanbanBoardController = KanbanBoardController();
  late final bool Function() _kanbanTapHandler = _handleKanbanPlusTap;
  PlusDragController? _plusScope;

  ItemViewMode get _viewMode => _currentList.viewMode;

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.activeListId.value = widget.list.id;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _plusScope = PlusDragScope.of(context);
  }

  @override
  void dispose() {
    // Deferred past the current frame: a synchronous write here notifies the
    // shell while this view is unmounting (tree locked), which throws.
    resetNotifierAfterFrame(widget.activeListId, null);
    if (identical(_plusScope?.onKanbanPlusTap, _kanbanTapHandler)) {
      _plusScope!.onKanbanPlusTap = null;
    }
    _selection.dispose();
    super.dispose();
  }

  /// Registers (or clears) the Kanban + tap handler so the global Plus button
  /// creates tasks in the focused column while this list's Kanban view is on
  /// top. Called from build so it tracks view-mode / selection changes.
  void _syncKanbanHandler() {
    final scope = _plusScope;
    if (scope == null) return;
    final active = _viewMode == ItemViewMode.kanban &&
        !_selection.active &&
        _currentList.listType != ListType.birthdays;
    if (active) {
      scope.onKanbanPlusTap = _kanbanTapHandler;
    } else if (identical(scope.onKanbanPlusTap, _kanbanTapHandler)) {
      scope.onKanbanPlusTap = null;
    }
  }

  /// Creates a task in the column identified by [columnId] (a section id or
  /// the top-group sentinel) by routing through the host's Plus-drop handlers.
  void _createInColumn(String columnId) {
    final scope = _plusScope;
    if (columnId == _kTopColumnId) {
      scope?.onDropOnList?.call(_currentList.id);
    } else {
      scope?.onDropOnSection?.call(_currentList.id, columnId);
    }
  }

  bool _handleKanbanPlusTap() {
    final focused = _kanbanBoardController.focusedColumnId;
    if (focused == null) return false;
    if (_currentList.kanbanScrollMode == KanbanScrollMode.free) {
      // Free scroll: snap to the nearest column first, then create there.
      _kanbanBoardController.snapToFocused().then((_) {
        if (!mounted) return;
        _createInColumn(_kanbanBoardController.focusedColumnId ?? focused);
      });
    } else {
      _createInColumn(focused);
    }
    return true;
  }

  void _showDropdown(BuildContext context) {
    showDropdown(context, (dismiss) {
      return _ListOptionsDropdown(
        onDismiss: dismiss,
        isKanban: _viewMode == ItemViewMode.kanban,
        onView: _currentList.listType == ListType.birthdays
            ? null
            : () {
                dismiss();
                _pickViewMode();
              },
        onScrollMode: (_currentList.listType != ListType.birthdays &&
                _viewMode == ItemViewMode.kanban)
            ? () {
                dismiss();
                _pickScrollMode();
              }
            : null,
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
    final picked = await showSelectionMenu<ItemViewMode>(
      context: context,
      title: s.viewLabel,
      current: _viewMode,
      // Opened from the nav-bar ⋯ menu → anchor top-right so the picker
      // appears in the same place as the parent dropdown.
      anchor: SelectionMenuAnchor.topRight,
      options: [
        SelectionMenuOption(
          value: ItemViewMode.list,
          label: s.viewAsList,
          icon: CupertinoIcons.list_bullet,
        ),
        SelectionMenuOption(
          value: ItemViewMode.kanban,
          label: s.viewAsKanban,
          icon: CupertinoIcons.square_split_2x1,
        ),
      ],
    );
    if (picked == null || !mounted || picked == _viewMode) return;
    final updated = _currentList.copyWith(viewMode: picked);
    await widget.folderController.updateList(updated);
    if (mounted) setState(() => _currentList = updated);
  }

  Future<void> _pickScrollMode() async {
    final s = S.of(context);
    final picked = await showSelectionMenu<KanbanScrollMode>(
      context: context,
      title: s.kanbanScrollLabel,
      current: _currentList.kanbanScrollMode,
      anchor: SelectionMenuAnchor.topRight,
      options: [
        SelectionMenuOption(
          value: KanbanScrollMode.snap,
          label: s.kanbanScrollSnap,
          icon: CupertinoIcons.rectangle_split_3x1,
        ),
        SelectionMenuOption(
          value: KanbanScrollMode.free,
          label: s.kanbanScrollFree,
          icon: CupertinoIcons.arrow_left_right,
        ),
      ],
    );
    if (picked == null || !mounted || picked == _currentList.kanbanScrollMode) {
      return;
    }
    final updated = _currentList.copyWith(kanbanScrollMode: picked);
    await widget.folderController.updateList(updated);
    if (mounted) setState(() => _currentList = updated);
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

        // Each column (a section, or the implicit "No Section" group) holds an
        // active group plus a collapsible "Completed" group for its own tasks.
        List<KanbanGroupData> groupsFor(String columnId, String? sectionId) {
          final active = widget.taskController
              .tasksForListSection(_currentList.id, sectionId);
          final done =
              completed.where((t) => t.sectionId == sectionId).toList();
          return [
            KanbanGroupData(
              id: '$columnId::active',
              tasks: active,
              sectionId: sectionId,
            ),
            if (done.isNotEmpty)
              KanbanGroupData(
                id: '$columnId::completed',
                title: s.sectionCompleted,
                isCompleted: true,
                tasks: done,
                sectionId: sectionId,
              ),
          ];
        }

        final columns = <KanbanColumnData>[
          KanbanColumnData(
            id: _kTopColumnId,
            title: s.noSectionTitle,
            accentColor: _currentList.color != null
                ? Color(_currentList.color!)
                : null,
            groups: groupsFor(_kTopColumnId, null),
          ),
          for (final section in sections)
            KanbanColumnData(
              id: section.id,
              title: section.name,
              groups: groupsFor(section.id, section.id),
            ),
        ];

        return KanbanBoard(
          columns: columns,
          scrollMode: _currentList.kanbanScrollMode,
          boardController: _kanbanBoardController,
          emptyLabel: s.noTasks,
          onMoveTask: _moveTaskToColumn,
          onCreateInColumn: _createInColumn,
          // Each kanban column IS a list-section here, so a Plus-drop on the
          // column already targets that section — the per-group ("drag to
          // section") drop is redundant and disabled. (Folder kanban, where
          // columns are whole lists, keeps the per-section drop.)
          onCreateInGroup: null,
          onReorderTask: (columnId, group, movedTaskId, beforeTaskId) {
            widget.taskController.reorderTaskBefore(
              movedTaskId: movedTaskId,
              beforeTaskId: beforeTaskId,
              listId: _currentList.id,
              sectionId: group.sectionId,
            );
          },
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
    _syncKanbanHandler();
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        _syncKanbanHandler();
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
                        : (_viewMode == ItemViewMode.kanban && !selecting)
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
              group: topTasks,
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
                  group: secTasks,
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
    required List<Task> group,
  }) {
    if (widget.selection.active) {
      return _buildTaskRow(context, task);
    }
    // The id of the row immediately after this one in the same group drives
    // the midpoint hand-off: crossing this row's centre while dragging down
    // hands the gap to [nextId] (or the section end when this is the last
    // row). Computed from the live group order the list is rendering.
    final idx = group.indexWhere((t) => t.id == task.id);
    final nextId =
        (idx >= 0 && idx + 1 < group.length) ? group[idx + 1].id : null;
    return _TaskReorderRow(
      task: task,
      nextId: nextId,
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

/// Long-press-to-drag wrapper for a task row.
///
/// The reorder is driven by a single shared gap (see [ReorderDragNotifier]):
///   • On pickup the gap is parked at the dragged row's own origin, so the
///     space the row vacated stays open instead of the list snapping closed.
///   • As the finger moves, whichever row's centre the *lifted card's* centre
///     crosses hands the gap on (to that row, the next row, or the section
///     end), so rows shift exactly on the midpoint — never a row too late.
///   • Because exactly one target is ever set, the origin gap and the new gap
///     animate as one hand-off (no double-shift jitter).
///
/// Each row's height (gap + collapsed source) is held in a single
/// [AnimatedSize]: at pickup the gap grows to the row height in the very frame
/// the source collapses to zero, so the net height is unchanged and nothing
/// jumps; only a genuine hand-off animates.
class _TaskReorderRow extends StatefulWidget {
  const _TaskReorderRow({
    required this.task,
    required this.nextId,
    required this.sectionId,
    required this.listId,
    required this.taskController,
    required this.child,
  });

  final Task task;

  /// Id of the next row in the same group, or null when this is the last row.
  final String? nextId;
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

  ReorderTarget get _beforeSelf => (
        kind: 'before',
        beforeId: widget.task.id,
        listId: widget.listId,
        sectionId: widget.sectionId,
      );

  /// Resolves the insertion target for a lifted-card centre at [draggedCentreY]
  /// (global). Comparing the dragged card's centre against this row's centre
  /// makes the hand-off independent of where the row was grabbed and lands it
  /// right on the midpoint.
  ReorderTarget _resolveTarget(double draggedCentreY) {
    // The dragged row maps to its own origin so the gap stays parked there
    // until the finger genuinely reaches another row.
    if (widget.task.id == ReorderDragNotifier.instance.draggingId) {
      return _beforeSelf;
    }
    final ro = _measureKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      final centre = ro.localToGlobal(Offset.zero).dy + ro.size.height / 2;
      if (draggedCentreY > centre) {
        // Past this row's centre → hand the gap to the next row, or to the
        // section end when there's nothing after this row.
        if (widget.nextId != null) {
          return (
            kind: 'before',
            beforeId: widget.nextId,
            listId: widget.listId,
            sectionId: widget.sectionId,
          );
        }
        return (
          kind: 'end',
          beforeId: null,
          listId: widget.listId,
          sectionId: widget.sectionId,
        );
      }
    }
    return _beforeSelf;
  }

  void _onDragStarted() {
    final notifier = ReorderDragNotifier.instance;
    notifier.start(widget.task.id, 'task', _measureHeight());
    // Park the gap at this row's origin so the vacated space stays open.
    notifier.setTarget(_beforeSelf);
  }

  void _onMove(DragTargetDetails<String> details) {
    final notifier = ReorderDragNotifier.instance;
    final centre = details.offset.dy + notifier.draggingHeight / 2;
    notifier.setTarget(_resolveTarget(centre));
  }

  void _onDragEnded() {
    ReorderDragNotifier.instance.end();
  }

  void _applyDrop() {
    final notifier = ReorderDragNotifier.instance;
    final movedId = notifier.draggingId;
    final target = notifier.target;
    if (movedId == null || target == null) return;
    // Dropping a row before itself is a no-op — and would otherwise slip
    // through to "end of section" inside reorderTaskBefore (which excludes
    // the moved row from its scope, so beforeId == movedId never matches).
    if (target.kind == 'before' && target.beforeId == movedId) return;
    widget.taskController.reorderTaskBefore(
      movedTaskId: movedId,
      beforeTaskId: target.kind == 'end' ? null : target.beforeId,
      listId: target.listId,
      sectionId: target.sectionId,
    );
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
    return AnimatedBuilder(
      animation: ReorderDragNotifier.instance,
      builder: (context, _) {
        final notifier = ReorderDragNotifier.instance;
        final target = notifier.target;
        final showGap = notifier.isDragging &&
            target != null &&
            target.kind == 'before' &&
            target.beforeId == widget.task.id;
        final gapHeight = showGap ? notifier.draggingHeight : 0.0;
        return DragTarget<String>(
          onWillAcceptWithDetails: (_) => true,
          onMove: _onMove,
          onAcceptWithDetails: (_) => _applyDrop(),
          builder: (context, candidates, _) {
            // Gap + (collapsed-while-dragging) source held in one AnimatedSize
            // so the two cancel on pickup and only real hand-offs animate.
            return AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: gapHeight, width: double.infinity),
                  LongPressDraggable<String>(
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
                    feedback: buildReorderDragFeedback(
                        context, feedbackWidth, widget.child),
                    childWhenDragging: const SizedBox.shrink(),
                    child: KeyedSubtree(
                      key: _measureKey,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Trailing slot after the last task in a section. Stays at a tiny constant
/// height while a task drag is in flight (so the user has somewhere to aim for
/// an end-of-list drop) and grows to the dragged row's height once the shared
/// gap parks at this section's end.
class _TaskReorderTrailingSlot extends StatelessWidget {
  const _TaskReorderTrailingSlot({
    required this.listId,
    required this.sectionId,
    required this.taskController,
  });

  final String listId;
  final String? sectionId;
  final TaskController taskController;

  ReorderTarget get _endTarget => (
        kind: 'end',
        beforeId: null,
        listId: listId,
        sectionId: sectionId,
      );

  void _applyDrop() {
    final notifier = ReorderDragNotifier.instance;
    final movedId = notifier.draggingId;
    final target = notifier.target;
    if (movedId == null || target == null) return;
    if (target.kind == 'before' && target.beforeId == movedId) return;
    taskController.reorderTaskBefore(
      movedTaskId: movedId,
      beforeTaskId: target.kind == 'end' ? null : target.beforeId,
      listId: target.listId,
      sectionId: target.sectionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (_) => ReorderDragNotifier.instance.setTarget(_endTarget),
      onAcceptWithDetails: (_) => _applyDrop(),
      builder: (context, candidates, _) {
        return AnimatedBuilder(
          animation: ReorderDragNotifier.instance,
          builder: (context, _) {
            final notifier = ReorderDragNotifier.instance;
            final draggingTask =
                notifier.isDragging && notifier.draggingKind == 'task';
            final isEndTarget = draggingTask && notifier.target == _endTarget;
            final double height = isEndTarget
                ? notifier.draggingHeight
                : (draggingTask ? 12 : 0);
            return AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: height,
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
    this.onScrollMode,
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
  final VoidCallback? onScrollMode;
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
              if (onScrollMode != null)
                _DropdownItem(
                    label: S.of(context).kanbanScrollLabel,
                    icon: CupertinoIcons.arrow_left_right,
                    onTap: onScrollMode!),
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
      decoration: AppColors.menuDecoration(context),
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
