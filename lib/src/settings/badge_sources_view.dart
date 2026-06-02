import 'package:flutter/cupertino.dart';

import '../folders/folder_controller.dart';
import '../folders/folder_icon_picker.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'settings_controller.dart';

/// Lets the user pick which smart lists, lists and folders feed the app icon
/// badge when [BadgeMode.custom] is selected. Selections are persisted as
/// [BadgeSource] tokens via [SettingsController.updateBadgeCustomSources].
class BadgeSourcesView extends StatefulWidget {
  const BadgeSourcesView({
    super.key,
    required this.settingsController,
    required this.folderController,
  });

  final SettingsController settingsController;
  final FolderController folderController;

  @override
  State<BadgeSourcesView> createState() => _BadgeSourcesViewState();
}

class _BadgeSourcesViewState extends State<BadgeSourcesView> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.settingsController.badgeCustomSources.toSet();
  }

  Future<void> _toggle(String token) async {
    setState(() {
      if (!_selected.add(token)) _selected.remove(token);
    });
    await widget.settingsController.updateBadgeCustomSources(_selected.toList());
  }

  static const _smartKeys = ['inbox', 'today', 'tomorrow', 'upcoming', 'allTasks'];

  String _smartLabel(S s, String key) {
    switch (key) {
      case 'inbox':
        return s.inbox;
      case 'today':
        return s.today;
      case 'tomorrow':
        return s.tomorrow;
      case 'upcoming':
        return s.upcoming;
      case 'allTasks':
        return s.allTasks;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.appBadgeSources),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.folderController,
          builder: (context, _) {
            final rows = <Widget>[];
            rows.add(_header(s.smartListsHeader, labelColor));
            for (final key in _smartKeys) {
              final token = BadgeSource.smart(key).token;
              rows.add(_CheckRow(
                label: _smartLabel(s, key),
                checked: _selected.contains(token),
                onTap: () => _toggle(token),
              ));
            }
            rows.add(const SizedBox(height: 20));
            rows.add(_header(s.listsAndFoldersHeader, labelColor));
            _appendTree(rows, null, 0);
            rows.add(const SizedBox(height: 24));

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: rows,
            );
          },
        ),
      ),
    );
  }

  Widget _header(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style:
                TextStyle(fontSize: 13, color: color, letterSpacing: -0.08)),
      );

  /// Recursively appends folder + list rows for the folder [parentId] scope.
  void _appendTree(List<Widget> rows, String? parentId, int depth) {
    final folders = widget.folderController.foldersIn(parentId);
    final lists = widget.folderController.listsIn(parentId);
    for (final f in folders) {
      final token = BadgeSource.folder(f.id).token;
      rows.add(_CheckRow(
        label: f.name,
        icon: buildFolderItemIcon(f.iconId,
            isFolder: true, iconColor: f.iconColor),
        indent: depth * 16.0,
        checked: _selected.contains(token),
        onTap: () => _toggle(token),
      ));
      _appendTree(rows, f.id, depth + 1);
    }
    for (final l in lists) {
      final token = BadgeSource.list(l.id).token;
      rows.add(_CheckRow(
        label: l.name,
        icon: buildFolderItemIcon(l.iconId,
            isFolder: false, iconColor: l.iconColor),
        indent: depth * 16.0,
        checked: _selected.contains(token),
        onTap: () => _toggle(token),
      ));
    }
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
    this.icon,
    this.indent = 0,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;
  final Widget? icon;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.fromLTRB(16 + indent, 11, 16, 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                SizedBox(width: 22, height: 22, child: icon),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              if (checked)
                Icon(CupertinoIcons.checkmark, size: 18, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
