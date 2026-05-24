import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
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
              ],
            );
          },
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
