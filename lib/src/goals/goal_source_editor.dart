import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../models/goal.dart';
import '../tasks/calendar_date_picker.dart';
import '../tasks/tag_picker_sheet.dart';
import '../tasks/task_controller.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import '../settings/settings_widgets.dart';
import 'goal_controller.dart';
import 'goal_scope_picker.dart';
import 'goal_source_labels.dart';
import 'goal_task_picker.dart';

/// Full-screen editor for one goal source. Returns the configured source, or
/// null when cancelled.
Future<GoalSource?> showGoalSourceEditor(
  BuildContext context, {
  required GoalController goalController,
  required TaskController taskController,
  required FolderController folderController,
  GoalSource? existing,
}) {
  return Navigator.of(context).push<GoalSource>(
    FastRoute<GoalSource>(
      fullscreenDialog: true,
      builder: (_) => _GoalSourceEditor(
        goalController: goalController,
        taskController: taskController,
        folderController: folderController,
        existing: existing,
      ),
    ),
  );
}

class _GoalSourceEditor extends StatefulWidget {
  const _GoalSourceEditor({
    required this.goalController,
    required this.taskController,
    required this.folderController,
    this.existing,
  });

  final GoalController goalController;
  final TaskController taskController;
  final FolderController folderController;
  final GoalSource? existing;

  @override
  State<_GoalSourceEditor> createState() => _GoalSourceEditorState();
}

class _GoalSourceEditorState extends State<_GoalSourceEditor> {
  late GoalSource _source = widget.existing ?? GoalSource();

  void _update(GoalSource next) => setState(() => _source = next);

  Future<void> _pickTasks() async {
    final picked = await showGoalTaskPicker(
      context,
      widget.taskController,
      widget.folderController,
      initialSelected: _source.taskIds,
    );
    if (picked == null || !mounted) return;
    _update(_source.copyWith(taskIds: picked));
  }

  Future<void> _pickScopeType() async {
    final s = S.of(context);
    final picked = await showSelectionMenu<GoalScopeType>(
      context: context,
      title: s.goalScope,
      current: _source.scopeType,
      options: [
        SelectionMenuOption(value: GoalScopeType.all, label: s.goalScopeAll),
        SelectionMenuOption(
            value: GoalScopeType.folders, label: s.goalScopeFolders),
        SelectionMenuOption(
            value: GoalScopeType.lists, label: s.goalScopeLists),
        SelectionMenuOption(
            value: GoalScopeType.sections, label: s.goalScopeSections),
      ],
    );
    if (picked == null || !mounted) return;
    // Switching scope invalidates the previously chosen container ids.
    _update(_source.copyWith(
      scopeType: picked,
      scopeIds: picked == _source.scopeType ? _source.scopeIds : const [],
    ));
    if (picked != GoalScopeType.all && _source.scopeIds.isEmpty) {
      await _pickScopeIds();
    }
  }

  Future<void> _pickScopeIds() async {
    if (_source.scopeType == GoalScopeType.all) return;
    final picked = await showGoalScopePicker(
      context,
      widget.folderController,
      scopeType: _source.scopeType,
      initialSelected: _source.scopeIds,
    );
    if (picked == null || !mounted) return;
    _update(_source.copyWith(scopeIds: picked));
  }

  Future<void> _pickTags() async {
    final picked = await showTagPickerSheet(
      context,
      widget.taskController,
      initialSelected: _source.tagIds,
    );
    if (picked == null || !mounted) return;
    _update(_source.copyWith(tagIds: picked));
  }

  void _togglePriority(int priority) {
    final next = [..._source.priorities];
    if (!next.remove(priority)) next.add(priority);
    _update(_source.copyWith(priorities: next));
  }

  Future<void> _pickDateFilter() async {
    final s = S.of(context);
    final picked = await showSelectionMenu<GoalDateFilter>(
      context: context,
      title: s.goalDateFilter,
      current: _source.dateFilter,
      options: [
        for (final f in GoalDateFilter.values)
          SelectionMenuOption(value: f, label: goalDateFilterLabel(s, f)),
      ],
    );
    if (picked == null || !mounted) return;
    _update(_source.copyWith(dateFilter: picked));
    if (picked == GoalDateFilter.range && _source.from == null) {
      await _pickRangeBound(isFrom: true);
    }
  }

  Future<void> _pickRangeBound({required bool isFrom}) async {
    final result = await showCalendarDatePicker(
      context,
      initial: isFrom ? _source.from : _source.to,
    );
    if (result == null || !mounted) return;
    final (date, _) = result;
    if (date == null) {
      _update(isFrom
          ? _source.copyWith(clearFrom: true)
          : _source.copyWith(clearTo: true));
      return;
    }
    _update(isFrom
        ? _source.copyWith(from: date)
        : _source.copyWith(to: date));
  }

  bool get _canSave => _source.kind == GoalSourceKind.manual
      ? _source.taskIds.isNotEmpty
      : _source.scopeType == GoalScopeType.all || _source.scopeIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final matches = widget.goalController.tasksForSource(_source).length;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(widget.existing == null ? s.goalAddSource : s.goalEditSource),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel, style: TextStyle(color: AppColors.accent)),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: _canSave ? () => Navigator.of(context).pop(_source) : null,
          child: Text(
            s.done,
            style: TextStyle(
              color: _canSave
                  ? AppColors.accent
                  : CupertinoColors.tertiaryLabel.resolveFrom(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            SettingsSectionHeader(s.goalSourceKind),
            CupertinoSlidingSegmentedControl<GoalSourceKind>(
              groupValue: _source.kind,
              children: {
                GoalSourceKind.manual: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    s.goalSourcePicked,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                GoalSourceKind.rule: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    s.goalSourceRule,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              },
              onValueChanged: (v) {
                if (v != null) _update(_source.copyWith(kind: v));
              },
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _source.kind == GoalSourceKind.manual
                    ? s.goalSourcePickedHint
                    : s.goalSourceRuleHint,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_source.kind == GoalSourceKind.manual) ...[
              SettingsSectionHeader(s.tabTasks),
              SettingsNavRow(
                label: s.goalPickTasks,
                trailingLabel: s.goalTasksSelected(_source.taskIds.length),
                onTap: _pickTasks,
              ),
            ] else ...[
              SettingsSectionHeader(s.goalScope),
              SettingsNavRow(
                label: s.goalScope,
                trailingLabel: goalSourceTitle(s, _source),
                onTap: _pickScopeType,
              ),
              if (_source.scopeType != GoalScopeType.all) ...[
                const SizedBox(height: 1),
                SettingsNavRow(
                  label: _scopeIdsLabel(s),
                  trailingLabel: _source.scopeIds.isEmpty
                      ? s.goalScopeNothingSelected
                      : '${_source.scopeIds.length}',
                  onTap: _pickScopeIds,
                ),
              ],
              const SizedBox(height: 18),
              SettingsSectionHeader(s.goalFilters),
              SettingsNavRow(
                label: s.tags,
                trailingLabel: _source.tagIds.isEmpty
                    ? s.goalFilterAny
                    : '${_source.tagIds.length}',
                onTap: _pickTags,
              ),
              const SizedBox(height: 1),
              _PriorityFilterRow(
                selected: _source.priorities,
                onToggle: _togglePriority,
              ),
              const SizedBox(height: 1),
              SettingsNavRow(
                label: s.goalDateFilter,
                trailingLabel: goalDateFilterLabel(s, _source.dateFilter),
                onTap: _pickDateFilter,
              ),
              if (_source.dateFilter == GoalDateFilter.range) ...[
                const SizedBox(height: 1),
                SettingsNavRow(
                  label: s.goalRangeFrom,
                  trailingLabel: _source.from == null
                      ? s.goalFilterAny
                      : formatTaskDate(context, _source.from!),
                  onTap: () => _pickRangeBound(isFrom: true),
                ),
                const SizedBox(height: 1),
                SettingsNavRow(
                  label: s.goalRangeTo,
                  trailingLabel: _source.to == null
                      ? s.goalFilterAny
                      : formatTaskDate(context, _source.to!),
                  onTap: () => _pickRangeBound(isFrom: false),
                ),
              ],
            ],
            const SizedBox(height: 18),
            // Live feedback: the same resolution the goal will use, so the
            // user can tell a rule is doing what they meant before saving.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.checkmark_circle,
                    size: 18,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.goalMatchesTasks(matches),
                      style: const TextStyle(fontSize: 15),
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

  String _scopeIdsLabel(S s) {
    switch (_source.scopeType) {
      case GoalScopeType.folders:
        return s.goalScopeFolders;
      case GoalScopeType.lists:
        return s.goalScopeLists;
      case GoalScopeType.sections:
        return s.goalScopeSections;
      case GoalScopeType.all:
        return s.goalScopeAll;
    }
  }
}

/// Priority multi-select rendered as four toggle chips — nothing selected
/// means "any priority".
class _PriorityFilterRow extends StatelessWidget {
  const _PriorityFilterRow({required this.selected, required this.onToggle});

  final List<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.priority, style: const TextStyle(fontSize: 17)),
              ),
              Text(
                selected.isEmpty ? s.goalFilterAny : '${selected.length}',
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final p in const [3, 2, 1, 0]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => onToggle(p),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected.contains(p)
                            ? AppColors.accent.withOpacity(0.18)
                            : CupertinoColors.tertiarySystemFill
                                .resolveFrom(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        goalPriorityLabel(s, p),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected.contains(p)
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected.contains(p)
                              ? AppColors.accent
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
