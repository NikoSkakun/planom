import 'package:flutter/cupertino.dart';

import '../models/app_list.dart';
import '../tasks/task_controller.dart';
import '../tasks/task_detail_view.dart';
import '../tasks/task_row.dart';
import '../utils/fast_route.dart';
import 'folder_controller.dart';
import 'folder_icon_picker.dart';
import 'list_color_picker.dart';

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

class _ListTaskViewState extends State<ListTaskView> {
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
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _ListOptionsDropdown(
        onDismiss: () => entry.remove(),
        onChangeColor: () {
          entry.remove();
          showListColorPickerSheet(context, _currentList.color, (color) {
            final updated = _currentList.copyWith(
              color: color,
              clearColor: color == null,
            );
            widget.folderController.updateList(updated);
            if (mounted) setState(() => _currentList = updated);
          });
        },
        onChangeIcon: () {
          entry.remove();
          showFolderIconPickerSheet(
            context,
            currentIconId: _currentList.iconId,
            isFolder: false,
            onSelected: (id) {
              final updated = _currentList.copyWith(
                iconId: id,
                clearIconId: id == null,
              );
              widget.folderController.updateList(updated);
              if (mounted) setState(() => _currentList = updated);
            },
          );
        },
      ),
    );

    overlay.insert(entry);
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
        child: ListenableBuilder(
          listenable: widget.taskController,
          builder: (context, _) {
            final tasks =
                widget.taskController.tasksForList(widget.list.id);
            final canReorder = widget.taskController.sortOrder ==
                TaskSortOrder.defaultOrder;

            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'No tasks',
                  style:
                      TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverReorderableList(
                  itemCount: tasks.length,
                  onReorder: canReorder
                      ? (old, neo) =>
                          widget.taskController.reorderTasks(
                            listId: widget.list.id,
                            oldIndex: old,
                            newIndex: neo,
                          )
                      : (_, __) {},
                  proxyDecorator: taskProxyDecorator,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('list_task_${task.id}'),
                      index: i,
                      enabled: canReorder,
                      child: Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: const TaskDeleteBackground(),
                        onDismissed: (_) =>
                            widget.taskController.deleteTask(task.id),
                        child: TaskRow(
                          task: task,
                          onToggle: () => widget.taskController
                              .toggleCompleted(task.id),
                          onTap: () => Navigator.of(context).push(
                            FastRoute<void>(
                              settings: const RouteSettings(
                                  name: TaskDetailView.routeName),
                              builder: (_) => TaskDetailView(
                                task: task,
                                controller: widget.taskController,
                                folderController: widget.folderController,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ListOptionsDropdown extends StatelessWidget {
  const _ListOptionsDropdown({
    required this.onDismiss,
    required this.onChangeColor,
    required this.onChangeIcon,
  });

  final VoidCallback onDismiss;
  final VoidCallback onChangeColor;
  final VoidCallback onChangeIcon;

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
              _DropdownItem(label: 'Change Icon', onTap: onChangeIcon),
              _DropdownItem(label: 'Change Color', onTap: onChangeColor),
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
  const _DropdownItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
