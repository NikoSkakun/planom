import 'package:flutter/cupertino.dart';

import '../folders/folder_icon_picker.dart';
import '../localization/strings.dart';
import '../tasks/task_field_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';
import 'smart_list_prefs.dart';

class TasksSettingsView extends StatelessWidget {
  const TasksSettingsView({super.key, required this.controller});

  final SettingsController controller;

  Future<void> _showVisibilityPicker(
      BuildContext context, String key, SmartListVisibility current) async {
    final s = S.of(context);
    final selected = await showSelectionMenu<SmartListVisibility>(
      context: context,
      title: s.visibility,
      current: current,
      options: SmartListVisibility.values
          .map((v) => SelectionMenuOption(
                value: v,
                label: _visibilityLabel(s, v),
              ))
          .toList(),
    );
    if (selected != null) {
      controller.updateSmartListVisibility(key, selected);
    }
  }

  static String _visibilityLabel(S s, SmartListVisibility v) {
    switch (v) {
      case SmartListVisibility.show:
        return s.visibilityShow;
      case SmartListVisibility.showIfNotEmpty:
        return s.visibilityIfNotEmpty;
      case SmartListVisibility.hidden:
        return s.visibilityHidden;
    }
  }

  static String _folderCounterLabel(S s, FolderCounterMode m) {
    switch (m) {
      case FolderCounterMode.directOnly:
        return s.folderCounterDirect;
      case FolderCounterMode.recursive:
        return s.folderCounterRecursive;
      case FolderCounterMode.hidden:
        return s.folderCounterHidden;
    }
  }

  Future<void> _showFolderCounterPicker(
      BuildContext context, FolderCounterMode current) async {
    final s = S.of(context);
    final selected = await showSelectionMenu<FolderCounterMode>(
      context: context,
      title: s.folderCounter,
      current: current,
      options: FolderCounterMode.values
          .map((m) => SelectionMenuOption(
                value: m,
                label: _folderCounterLabel(s, m),
              ))
          .toList(),
    );
    if (selected != null) {
      final next = controller.taskFieldPrefs.copy();
      next.folderCounterMode = selected;
      await controller.updateTaskFieldPrefs(next);
    }
  }

  static String _checkboxStyleLabel(S s, TaskCheckboxStyle style) {
    switch (style) {
      case TaskCheckboxStyle.roundedRect:
        return s.checkboxStyleRoundedRect;
      case TaskCheckboxStyle.sharpRect:
        return s.checkboxStyleSharpRect;
      case TaskCheckboxStyle.circle:
        return s.checkboxStyleCircle;
    }
  }

  Future<void> _showCheckboxStylePicker(
      BuildContext context, TaskCheckboxStyle current) async {
    final s = S.of(context);
    final selected = await showSelectionMenu<TaskCheckboxStyle>(
      context: context,
      title: s.checkboxStyle,
      current: current,
      options: TaskCheckboxStyle.values
          .map((v) => SelectionMenuOption(
                value: v,
                label: _checkboxStyleLabel(s, v),
              ))
          .toList(),
    );
    if (selected != null) {
      final next = controller.taskFieldPrefs.copy();
      next.checkboxStyle = selected;
      await controller.updateTaskFieldPrefs(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.tabTasks),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (ctx, _) {
            final prefs = controller.smartListPrefs;
            final fields = controller.taskFieldPrefs;

            Future<void> updateField(void Function(TaskFieldPrefs) m) async {
              final next = fields.copy();
              m(next);
              await controller.updateTaskFieldPrefs(next);
            }

            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                SettingsSectionHeader(s.sectionSmartLists),
                _SmartListRow(
                  icon: Image.asset('assets/icons/inbox.png',
                      width: 22, height: 22),
                  label: s.inbox,
                ),
                const SizedBox(height: 1),
                _SmartListRow(
                  icon: Image.asset('assets/icons/today.png',
                      width: 22, height: 22),
                  label: s.today,
                  visibility: prefs.today,
                  onTap: () =>
                      _showVisibilityPicker(ctx, 'today', prefs.today),
                ),
                const SizedBox(height: 1),
                _SmartListRow(
                  icon: Icon(
                    CupertinoIcons.sun_max,
                    size: 22,
                    color: CupertinoColors.systemOrange.resolveFrom(ctx),
                  ),
                  label: s.tomorrow,
                  visibility: prefs.tomorrow,
                  onTap: () =>
                      _showVisibilityPicker(ctx, 'tomorrow', prefs.tomorrow),
                ),
                const SizedBox(height: 1),
                _SmartListRow(
                  icon: Image.asset('assets/icons/upcoming.png',
                      width: 22, height: 22),
                  label: s.upcoming,
                  visibility: prefs.upcoming,
                  onTap: () =>
                      _showVisibilityPicker(ctx, 'upcoming', prefs.upcoming),
                ),
                const SizedBox(height: 1),
                _SmartListRow(
                  icon: Icon(
                    CupertinoIcons.tray_full,
                    size: 22,
                    color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                  ),
                  label: s.allTasks,
                  visibility: prefs.allTasks,
                  onTap: () =>
                      _showVisibilityPicker(ctx, 'allTasks', prefs.allTasks),
                ),
                const SizedBox(height: 1),
                _SmartListRow(
                  icon: Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 22,
                    color: AppColors.systemGreen,
                  ),
                  label: s.completed,
                  visibility: prefs.completed,
                  onTap: () => _showVisibilityPicker(
                      ctx, 'completed', prefs.completed),
                ),
                const SizedBox(height: 1),
                _SmartListRow(
                  icon: Icon(
                    CupertinoIcons.trash,
                    size: 22,
                    color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                  ),
                  label: s.trash,
                  visibility: prefs.trash,
                  onTap: () =>
                      _showVisibilityPicker(ctx, 'trash', prefs.trash),
                ),

                const SizedBox(height: 18),
                SettingsSectionHeader(s.tabRoutines),
                SettingsToggleRow(
                  label: s.showRoutinesInToday,
                  value: controller.showRoutinesInToday,
                  onChanged: controller.updateShowRoutinesInToday,
                ),

                const SizedBox(height: 18),
                SettingsSectionHeader(s.sectionTaskCounters),
                SettingsNavRow(
                  label: s.folderCounter,
                  trailingLabel:
                      _folderCounterLabel(s, fields.folderCounterMode),
                  onTap: () => _showFolderCounterPicker(
                      ctx, fields.folderCounterMode),
                ),
                const SizedBox(height: 1),
                SettingsToggleRow(
                  label: s.showListCount,
                  value: fields.showListCount,
                  onChanged: (v) =>
                      updateField((p) => p.showListCount = v),
                ),

                const SizedBox(height: 18),
                SettingsSectionHeader(s.sectionTaskFields),
                SettingsToggleRow(
                  label: s.showHidePriority,
                  value: fields.showPriority,
                  onChanged: (v) =>
                      updateField((p) => p.showPriority = v),
                ),
                const SizedBox(height: 1),
                SettingsToggleRow(
                  label: s.showHideDate,
                  value: fields.showDate,
                  onChanged: (v) => updateField((p) => p.showDate = v),
                ),
                const SizedBox(height: 1),
                SettingsToggleRow(
                  label: s.showHideRepeat,
                  value: fields.showRepeat,
                  onChanged: (v) => updateField((p) => p.showRepeat = v),
                ),
                const SizedBox(height: 1),
                SettingsToggleRow(
                  label: s.showHideList,
                  value: fields.showList,
                  onChanged: (v) => updateField((p) => p.showList = v),
                ),
                const SizedBox(height: 1),
                SettingsToggleRow(
                  label: s.showHideDuration,
                  value: fields.showDuration,
                  onChanged: (v) => updateField((p) => p.showDuration = v),
                ),
                const SizedBox(height: 1),
                SettingsToggleRow(
                  label: s.showHideTags,
                  value: fields.showTags,
                  onChanged: (v) => updateField((p) => p.showTags = v),
                ),
                const SizedBox(height: 1),
                SettingsToggleRow(
                  label: s.showHideReminders,
                  value: fields.showReminders,
                  onChanged: (v) =>
                      updateField((p) => p.showReminders = v),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.taskFieldsHint,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                SettingsSectionHeader(s.sectionBody),
                SettingsToggleRow(
                  label: s.useMarkdown,
                  value: fields.useMarkdown,
                  onChanged: (v) =>
                      updateField((p) => p.useMarkdown = v),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.useMarkdownHint,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                SettingsSectionHeader(s.sectionTasksUi),
                SettingsToggleRow(
                  label: s.showAddFolderButton,
                  value: controller.smartListPrefs.showAddFolderButton,
                  onChanged: controller.updateShowAddFolderButton,
                ),
                const SizedBox(height: 1),
                SettingsNavRow(
                  label: s.checkboxStyle,
                  trailingLabel:
                      _checkboxStyleLabel(s, fields.checkboxStyle),
                  onTap: () =>
                      _showCheckboxStylePicker(ctx, fields.checkboxStyle),
                ),
                const SizedBox(height: 1),
                SettingsToggleRow(
                  label: s.undoOnComplete,
                  value: fields.showUndoOnComplete,
                  onChanged: (v) =>
                      updateField((p) => p.showUndoOnComplete = v),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.undoOnCompleteHint,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                SettingsSectionHeader(s.sectionDefaults),
                _DefaultIconRow(
                  label: s.defaultTaskIcon,
                  iconId: controller.defaultTaskIcon,
                  isFolder: false,
                  // Tasks never have null icons — historical default 'inbox'.
                  onPicked: (id, _) {
                    controller.updateDefaultTaskIcon(id ?? 'inbox');
                  },
                ),
                const SizedBox(height: 1),
                _DefaultIconRow(
                  label: s.defaultListIcon,
                  iconId: controller.defaultListIcon,
                  isFolder: false,
                  onPicked: (id, _) => controller.updateDefaultListIcon(id),
                ),
                const SizedBox(height: 1),
                _DefaultIconRow(
                  label: s.defaultFolderIcon,
                  iconId: controller.defaultFolderIcon,
                  isFolder: true,
                  onPicked: (id, _) =>
                      controller.updateDefaultFolderIcon(id),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DefaultIconRow extends StatelessWidget {
  const _DefaultIconRow({
    required this.label,
    required this.iconId,
    required this.isFolder,
    required this.onPicked,
  });

  final String label;
  final String? iconId;
  final bool isFolder;
  final void Function(String? iconId, int? iconColor) onPicked;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return GestureDetector(
      onTap: () => showFolderIconPickerSheet(
        context,
        currentIconId: iconId,
        isFolder: isFolder,
        onSelected: onPicked,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: buildFolderItemIcon(iconId, isFolder: isFolder),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 17),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartListRow extends StatelessWidget {
  const _SmartListRow({
    required this.icon,
    required this.label,
    this.visibility,
    this.onTap,
  });

  final Widget icon;
  final String label;
  final SmartListVisibility? visibility;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(width: 22, height: 22, child: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: isDisabled
                      ? CupertinoColors.secondaryLabel.resolveFrom(context)
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isDisabled
                  ? s.visibilityAlwaysShown
                  : _label(s, visibility!),
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            if (!isDisabled) ...[
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _label(S s, SmartListVisibility v) {
    switch (v) {
      case SmartListVisibility.show:
        return s.visibilityShow;
      case SmartListVisibility.showIfNotEmpty:
        return s.visibilityIfNotEmpty;
      case SmartListVisibility.hidden:
        return s.visibilityHidden;
    }
  }
}
