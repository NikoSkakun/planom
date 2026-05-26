import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material;

import '../localization/strings.dart';
import '../models/app_list.dart';
import '../models/list_section.dart';
import '../models/list_type.dart';
import '../models/task.dart';
import '../tasks/birthday_list_view.dart';
import '../tasks/task_controller.dart';
import '../tasks/task_detail_view.dart';
import '../tasks/task_row.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/dropdown_overlay.dart';
import '../utils/fast_route.dart';
import '../utils/item_info_sheet.dart';
import '../utils/undo_controller.dart';
import 'create_folder_list_sheet.dart';
import 'folder_controller.dart';
import 'move_to_sheet.dart';
import 'section_name_sheet.dart';

class ListTaskView extends StatefulWidget {
  const ListTaskView({
    super.key,
    required this.list,
    required this.taskController,
    required this.folderController,
    required this.activeListId,
  });

  final AppList list;
  final TaskController taskController;
  final FolderController folderController;
  final ValueNotifier<String?> activeListId;

  @override
  State<ListTaskView> createState() => _ListTaskViewState();
}

class _ListTaskViewState extends State<ListTaskView>
    with DropdownOverlayMixin {
  late AppList _currentList;

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
    super.dispose();
  }

  void _showDropdown(BuildContext context) {
    showDropdown(context, (dismiss) {
      return _ListOptionsDropdown(
        onDismiss: dismiss,
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
    await widget.folderController.deleteList(_currentList.id);
    undo?.show(
      label: s.listTrashedToast,
      onUndo: () async {
        await widget.folderController
            .restoreList(_currentList.id, _currentList.folderId);
        await widget.taskController.restoreAt(ts);
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(_currentList.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showDropdown(context),
          child: const Icon(CupertinoIcons.ellipsis, size: 26),
        ),
      ),
      child: SafeArea(
        child: _currentList.listType == ListType.birthdays
            ? BirthdayListView(
                listId: _currentList.id,
                taskController: widget.taskController,
                folderController: widget.folderController,
              )
            : _SectionedListBody(
                list: _currentList,
                taskController: widget.taskController,
                folderController: widget.folderController,
              ),
      ),
    );
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
  });

  final AppList list;
  final TaskController taskController;
  final FolderController folderController;

  @override
  State<_SectionedListBody> createState() => _SectionedListBodyState();
}

class _SectionedListBodyState extends State<_SectionedListBody> {
  bool _completedExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([widget.taskController, widget.folderController]),
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
        for (final t in topTasks) {
          children.add(_buildDraggableTask(context, t, sectionId: null));
        }

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
            for (final t in secTasks) {
              children
                  .add(_buildDraggableTask(context, t, sectionId: section.id));
            }
          }
        }

        // Implicit "Completed" virtual section — always shown when there's
        // at least one completed task; cannot be edited or deleted.
        if (completed.isNotEmpty) {
          children.add(_CompletedHeader(
            count: completed.length,
            expanded: _completedExpanded,
            onToggle: () =>
                setState(() => _completedExpanded = !_completedExpanded),
          ));
          if (_completedExpanded) {
            for (final t in completed) {
              children.add(_buildTaskRow(context, t));
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 80),
          children: children,
        );
      },
    );
  }

  Widget _buildDraggableTask(BuildContext context, Task task,
      {required String? sectionId}) {
    return LongPressDraggable<String>(
      data: task.id,
      feedback: Material(
        color: const Color(0x00000000),
        child: Container(
          width: MediaQuery.sizeOf(context).width - 32,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            task.title,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTaskRow(context, task),
      ),
      child: _buildTaskRow(context, task),
    );
  }

  Widget _buildTaskRow(BuildContext context, Task task) {
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
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onAcceptTask(d.data),
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

  void _showSectionMenu(BuildContext context) {
    final s = S.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRename();
            },
            child: Text(s.rename),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: Text(s.delete),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.cancel),
        ),
      ),
    );
  }
}

/// Implicit virtual "Completed" header — always at the bottom of the list,
/// not editable. Counts and reveals completed tasks for the list.
class _CompletedHeader extends StatelessWidget {
  const _CompletedHeader({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            AnimatedRotation(
              duration: const Duration(milliseconds: 180),
              turns: expanded ? 0 : -0.25,
              child: Icon(
                CupertinoIcons.chevron_down,
                size: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${S.of(context).sectionCompleted} ($count)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListOptionsDropdown extends StatelessWidget {
  const _ListOptionsDropdown({
    required this.onDismiss,
    required this.onEdit,
    required this.onMoveTo,
    required this.onInfo,
    required this.onDelete,
    this.onAddSection,
  });

  final VoidCallback onDismiss;
  final VoidCallback onEdit;
  final VoidCallback onMoveTo;
  final VoidCallback onInfo;
  final VoidCallback onDelete;
  final VoidCallback? onAddSection;

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
