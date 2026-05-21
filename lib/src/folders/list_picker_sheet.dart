import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart' show showModalBottomSheet;

import '../localization/strings.dart';
import '../models/app_folder.dart';
import '../theme/app_theme.dart';
import 'folder_controller.dart';
import 'folder_icon_picker.dart';

// Sentinel popped when Inbox is selected; maps to a null listId in the result.
const _kInboxSentinel = '';

/// Shows a hierarchical list/inbox picker. Returns the selected listId
/// (null = Inbox). If the sheet is dismissed without a selection the
/// current value is returned unchanged.
Future<String?> showListPickerSheet(
  BuildContext context,
  FolderController folderController,
  String? currentListId,
) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _ListPickerSheet(
      folderController: folderController,
      currentListId: currentListId,
    ),
  );
  // null means the sheet was swiped away without a selection — no change.
  if (result == null) return currentListId;
  // Empty string sentinel means the user explicitly chose Inbox.
  if (result == _kInboxSentinel) return null;
  return result;
}

class _ListPickerSheet extends StatefulWidget {
  const _ListPickerSheet({
    required this.folderController,
    required this.currentListId,
  });

  final FolderController folderController;
  final String? currentListId;

  @override
  State<_ListPickerSheet> createState() => _ListPickerSheetState();
}

class _ListPickerSheetState extends State<_ListPickerSheet> {
  // Stack of folders navigated into; null means "root level".
  final _path = <AppFolder?>[];

  AppFolder? get _current => _path.isEmpty ? null : _path.last;

  void _enter(AppFolder folder) => setState(() => _path.add(folder));

  void _back() {
    if (_path.length > 1) {
      setState(() => _path.removeLast());
    } else {
      setState(() => _path.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final fc = widget.folderController;
    final folders = fc.foldersIn(_current?.id);
    final lists = fc.listsIn(_current?.id);
    final isRoot = _path.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CupertinoColors.separator.resolveFrom(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!isRoot)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _back,
                        child: Icon(
                          CupertinoIcons.chevron_left,
                          size: 20,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    if (!isRoot) const SizedBox(width: 4),
                    Text(
                      isRoot ? S.of(context).moveTo : (_current?.name ?? ''),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // List items
          Flexible(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 8,
              ),
              shrinkWrap: true,
              children: [
                // Inbox only at root level
                if (isRoot)
                  _PickerRow(
                    icon: Image.asset('assets/icons/inbox.png',
                        width: 22, height: 22),
                    label: S.of(context).inbox,
                    isSelected: widget.currentListId == null,
                    onTap: () => Navigator.of(context, rootNavigator: true)
                        .pop(_kInboxSentinel),
                    trailing: null,
                  ),
                // Folders — drill in
                ...folders.map((f) => _PickerRow(
                      icon: SizedBox(
                        width: 22,
                        height: 22,
                        child: buildFolderItemIcon(f.iconId, isFolder: true),
                      ),
                      label: f.name,
                      isSelected: false,
                      onTap: () => _enter(f),
                      trailing: Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    )),
                // Lists — select
                ...lists.map((l) => _PickerRow(
                      icon: SizedBox(
                        width: 22,
                        height: 22,
                        child: buildFolderItemIcon(l.iconId, isFolder: false),
                      ),
                      label: l.name,
                      isSelected: widget.currentListId == l.id,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .pop(l.id),
                      trailing: null,
                    )),
                if (folders.isEmpty && lists.isEmpty && !isRoot)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Text(
                      S.of(context).noListsInFolder,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.trailing,
  });

  final Widget icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      onPressed: onTap,
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          if (isSelected)
            const Icon(CupertinoIcons.checkmark,
                size: 16, color: AppColors.accent)
          else if (trailing != null)
            trailing!,
        ],
      ),
    );
  }
}
