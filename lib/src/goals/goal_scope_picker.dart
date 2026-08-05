import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../folders/folder_controller.dart';
import '../folders/folder_icon_picker.dart';
import '../localization/strings.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import '../utils/selection_checkbox.dart';

/// Multi-select picker for a rule's scope: folders, lists, or list sections
/// depending on [scopeType]. Returns the chosen ids, or null when dismissed
/// without confirming.
Future<List<String>?> showGoalScopePicker(
  BuildContext context,
  FolderController folderController, {
  required GoalScopeType scopeType,
  required List<String> initialSelected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _GoalScopePicker(
      folderController: folderController,
      scopeType: scopeType,
      initialSelected: initialSelected,
    ),
  );
}

class _GoalScopePicker extends StatefulWidget {
  const _GoalScopePicker({
    required this.folderController,
    required this.scopeType,
    required this.initialSelected,
  });

  final FolderController folderController;
  final GoalScopeType scopeType;
  final List<String> initialSelected;

  @override
  State<_GoalScopePicker> createState() => _GoalScopePickerState();
}

class _GoalScopePickerState extends State<_GoalScopePicker> {
  late final Set<String> _selected = {...widget.initialSelected};

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  /// Folder rows, depth-first so nesting is visible, each with its indent.
  List<(String id, String name, int depth)> _folderRows() {
    final rows = <(String, String, int)>[];
    void walk(String? parentId, int depth) {
      for (final folder in widget.folderController.foldersIn(parentId)) {
        rows.add((folder.id, folder.name, depth));
        walk(folder.id, depth + 1);
      }
    }

    walk(null, 0);
    return rows;
  }

  List<(String id, String name, int depth)> _listRows() {
    final rows = <(String, String, int)>[];
    for (final list in widget.folderController.listsIn(null)) {
      rows.add((list.id, list.name, 0));
    }
    void walk(String? parentId, int depth) {
      for (final folder in widget.folderController.foldersIn(parentId)) {
        for (final list in widget.folderController.listsIn(folder.id)) {
          rows.add((list.id, '${folder.name} › ${list.name}', depth));
        }
        walk(folder.id, depth + 1);
      }
    }

    walk(null, 0);
    return rows;
  }

  List<(String id, String name, int depth)> _sectionRows() {
    final rows = <(String, String, int)>[];
    for (final list in widget.folderController.lists) {
      final sections = widget.folderController.sectionsForList(list.id);
      if (sections.isEmpty) continue;
      for (final section in sections) {
        rows.add((section.id, '${list.name} › ${section.name}', 0));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final rows = switch (widget.scopeType) {
      GoalScopeType.folders => _folderRows(),
      GoalScopeType.lists => _listRows(),
      GoalScopeType.sections => _sectionRows(),
      GoalScopeType.all => const <(String, String, int)>[],
    };
    final title = switch (widget.scopeType) {
      GoalScopeType.folders => s.goalScopeFolders,
      GoalScopeType.lists => s.goalScopeLists,
      GoalScopeType.sections => s.goalScopeSections,
      GoalScopeType.all => s.goalScopeAll,
    };
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
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
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Text(
                  s.goalScopeNothingToPick,
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
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final (id, name, depth) = rows[index];
                    final selected = _selected.contains(id);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggle(id),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            16 + depth * 16.0, 9, 16, 9),
                        child: Row(
                          children: [
                            SelectionCheckbox(checked: selected),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Center(
                                child: buildFolderItemIcon(
                                  null,
                                  isFolder:
                                      widget.scopeType == GoalScopeType.folders,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16),
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
