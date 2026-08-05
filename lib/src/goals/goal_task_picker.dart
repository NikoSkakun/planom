import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../models/task.dart';
import '../tasks/task_controller.dart';
import '../theme/app_theme.dart';
import '../utils/selection_checkbox.dart';

/// Multi-select task picker used by a goal's hand-picked source. Lists every
/// active top-level task with its list name, filtered live by the search
/// field. Returns the chosen task ids, or null when dismissed.
Future<List<String>?> showGoalTaskPicker(
  BuildContext context,
  TaskController taskController,
  FolderController folderController, {
  required List<String> initialSelected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _GoalTaskPicker(
      taskController: taskController,
      folderController: folderController,
      initialSelected: initialSelected,
    ),
  );
}

class _GoalTaskPicker extends StatefulWidget {
  const _GoalTaskPicker({
    required this.taskController,
    required this.folderController,
    required this.initialSelected,
  });

  final TaskController taskController;
  final FolderController folderController;
  final List<String> initialSelected;

  @override
  State<_GoalTaskPicker> createState() => _GoalTaskPickerState();
}

class _GoalTaskPickerState extends State<_GoalTaskPicker> {
  late final Set<String> _selected = {...widget.initialSelected};
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Task> get _tasks {
    final all = widget.taskController.allTasks;
    if (_query.isEmpty) return all;
    return all
        .where((t) =>
            t.title.toLowerCase().contains(_query) ||
            (t.note ?? '').toLowerCase().contains(_query))
        .toList();
  }

  String _listName(Task task, S s) {
    final id = task.listId;
    if (id == null) return s.inbox;
    return widget.folderController.listById(id)?.name ?? s.inbox;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tasks = _tasks;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.separator.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.goalPickTasks,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minSize: 0,
                    onPressed: () =>
                        Navigator.of(context).pop(_selected.toList()),
                    child: Text(
                      s.done,
                      style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: CupertinoSearchTextField(controller: _searchCtrl),
            ),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Text(
                  s.goalNoTasksToPick,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final selected = _selected.contains(task.id);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        if (!_selected.remove(task.id)) _selected.add(task.id);
                      }),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        child: Row(
                          children: [
                            SelectionCheckbox(checked: selected),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: task.isCompleted
                                          ? CupertinoColors.secondaryLabel
                                              .resolveFrom(context)
                                          : CupertinoColors.label
                                              .resolveFrom(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _listName(task, s),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.secondaryLabel
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
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
