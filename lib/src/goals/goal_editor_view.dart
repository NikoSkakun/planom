import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../models/goal.dart';
import '../settings/settings_widgets.dart';
import '../tasks/task_controller.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'goal_controller.dart';
import 'goal_icons.dart';
import 'goal_source_editor.dart';
import 'goal_source_labels.dart';

/// Create / edit a goal: its name, description, look, and the sources that
/// decide which tasks it tracks. Returns the saved goal, or null on cancel.
Future<Goal?> showGoalEditor(
  BuildContext context, {
  required GoalController goalController,
  required TaskController taskController,
  required FolderController folderController,
  Goal? existing,
}) {
  return Navigator.of(context).push<Goal>(
    FastRoute<Goal>(
      fullscreenDialog: existing == null,
      builder: (_) => _GoalEditorView(
        goalController: goalController,
        taskController: taskController,
        folderController: folderController,
        existing: existing,
      ),
    ),
  );
}

class _GoalEditorView extends StatefulWidget {
  const _GoalEditorView({
    required this.goalController,
    required this.taskController,
    required this.folderController,
    this.existing,
  });

  final GoalController goalController;
  final TaskController taskController;
  final FolderController folderController;
  final Goal? existing;

  @override
  State<_GoalEditorView> createState() => _GoalEditorViewState();
}

class _GoalEditorViewState extends State<_GoalEditorView> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _descCtrl =
      TextEditingController(text: widget.existing?.description ?? '');
  late String _iconId = widget.existing?.iconId ?? kGoalIcons.first;
  late int _color = widget.existing?.color ?? kGoalColors.first;
  late List<GoalSource> _sources = [...?widget.existing?.sources];

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSource() async {
    final created = await showGoalSourceEditor(
      context,
      goalController: widget.goalController,
      taskController: widget.taskController,
      folderController: widget.folderController,
    );
    if (created == null || !mounted) return;
    setState(() => _sources = [..._sources, created]);
  }

  Future<void> _editSource(GoalSource source) async {
    final updated = await showGoalSourceEditor(
      context,
      goalController: widget.goalController,
      taskController: widget.taskController,
      folderController: widget.folderController,
      existing: source,
    );
    if (updated == null || !mounted) return;
    setState(() {
      _sources = [
        for (final s in _sources) if (s.id == updated.id) updated else s,
      ];
    });
  }

  Future<void> _sourceMenu(GoalSource source) async {
    final s = S.of(context);
    final action = await showSelectionMenu<String>(
      context: context,
      title: goalSourceTitle(s, source),
      options: [
        SelectionMenuOption(value: 'edit', label: s.edit),
        SelectionMenuOption(
            value: 'remove', label: s.delete, isDestructive: true),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _editSource(source);
    } else {
      setState(() =>
          _sources = _sources.where((item) => item.id != source.id).toList());
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final description = _descCtrl.text.trim();
    final existing = widget.existing;
    final result = existing == null
        ? Goal(
            name: name,
            description: description.isEmpty ? null : description,
            iconId: _iconId,
            color: _color,
            sources: _sources,
          )
        : existing.copyWith(
            name: name,
            description: description.isEmpty ? null : description,
            clearDescription: description.isEmpty,
            iconId: _iconId,
            color: _color,
            sources: _sources,
          );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final canSave = _nameCtrl.text.trim().isNotEmpty;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(widget.existing == null ? s.goalNew : s.goalEdit),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel, style: TextStyle(color: AppColors.accent)),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: canSave ? _save : null,
          child: Text(
            s.save,
            style: TextStyle(
              color: canSave
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
            Row(
              children: [
                GoalCircleIcon(iconId: _iconId, color: _color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoTextField(
                    controller: _nameCtrl,
                    autofocus: widget.existing == null,
                    placeholder: s.goalName,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 17),
                    decoration: BoxDecoration(
                      color: CupertinoColors.tertiarySystemFill
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: _descCtrl,
              placeholder: s.goalDescription,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            const SizedBox(height: 20),
            SettingsSectionHeader(s.colorLabel),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in kGoalColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: _color == color
                            ? Border.all(
                                color:
                                    CupertinoColors.label.resolveFrom(context),
                                width: 2)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSectionHeader(s.iconLabel),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final icon in kGoalIcons)
                  GestureDetector(
                    onTap: () => setState(() => _iconId = icon),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _iconId == icon
                            ? Color(_color).withOpacity(0.18)
                            : CupertinoColors.tertiarySystemFill
                                .resolveFrom(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        goalIcon(icon),
                        size: 22,
                        color: _iconId == icon
                            ? Color(_color)
                            : CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSectionHeader(s.goalSources),
            if (_sources.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  s.goalNoSourcesHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            for (final source in _sources) ...[
              _SourceRow(
                title: goalSourceTitle(s, source),
                detail: goalSourceDetail(
                  context,
                  source,
                  folderController: widget.folderController,
                  taskController: widget.taskController,
                ),
                matches: widget.goalController.tasksForSource(source).length,
                onTap: () => _editSource(source),
                onLongPress: () => _sourceMenu(source),
              ),
              const SizedBox(height: 1),
            ],
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _addSource,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemBackground
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.add, size: 18, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Text(
                      s.goalAddSource,
                      style: TextStyle(fontSize: 17, color: AppColors.accent),
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

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.title,
    required this.detail,
    required this.matches,
    required this.onTap,
    required this.onLongPress,
  });

  final String title;
  final String detail;
  final int matches;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              CupertinoColors.tertiarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17)),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              s.goalMatchesShort(matches),
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}
