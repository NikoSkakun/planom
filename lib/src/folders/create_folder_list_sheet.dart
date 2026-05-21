import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart' show showModalBottomSheet;

import '../localization/strings.dart';
import '../models/app_folder.dart';
import '../models/app_list.dart';
import '../theme/app_theme.dart';
import 'folder_controller.dart';
import 'folder_icon_picker.dart';
import 'list_color_picker.dart';

Future<void> showRenameSheet(
  BuildContext context, {
  required String currentName,
  required Future<void> Function(String) onRename,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _RenameSheet(
      currentName: currentName,
      onRename: onRename,
    ),
  );
}

class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.currentName, required this.onRename});
  final String currentName;
  final Future<void> Function(String) onRename;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    await widget.onRename(name);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            decoration: BoxDecoration(
              color:
                  CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
            onPressed: _submit,
            child: Text(
              S.of(context).rename,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showCreateFolderListSheet(
  BuildContext context,
  FolderController controller, {
  String? parentFolderId,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _CreateSheet(
      controller: controller,
      parentFolderId: parentFolderId,
    ),
  );
}

enum _CreateType { folder, list }

class _CreateSheet extends StatefulWidget {
  const _CreateSheet({
    required this.controller,
    this.parentFolderId,
  });

  final FolderController controller;
  final String? parentFolderId;

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  _CreateType _type = _CreateType.list;
  final _nameCtrl = TextEditingController();
  int? _selectedColor;
  String? _selectedIconId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_type == _CreateType.folder) {
      await widget.controller.addFolder(AppFolder(
        name: name,
        parentFolderId: widget.parentFolderId,
        iconId: _selectedIconId,
      ));
    } else {
      await widget.controller.addList(AppList(
        name: name,
        folderId: widget.parentFolderId,
        color: _selectedColor,
        iconId: _selectedIconId,
      ));
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _openIconPicker() {
    showFolderIconPickerSheet(
      context,
      currentIconId: _selectedIconId,
      isFolder: _type == _CreateType.folder,
      onSelected: (id) {
        if (mounted) setState(() => _selectedIconId = id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final isFolder = _type == _CreateType.folder;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 16),
          CupertinoSlidingSegmentedControl<_CreateType>(
            groupValue: _type,
            children: {
              _CreateType.list: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icons/list.png', width: 16, height: 16),
                  const SizedBox(width: 6),
                  Text(S.of(context).list),
                ],
              ),
              _CreateType.folder: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icons/folder.png',
                      width: 16, height: 16),
                  const SizedBox(width: 6),
                  Text(S.of(context).folder),
                ],
              ),
            },
            onValueChanged: (v) {
              if (v != null) {
                setState(() {
                  _type = v;
                  _selectedIconId = null;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: _openIconPicker,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: buildFolderItemIcon(
                      _selectedIconId,
                      isFolder: isFolder,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoTextField(
                  controller: _nameCtrl,
                  placeholder: isFolder
                      ? S.of(context).folderName
                      : S.of(context).listName,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w500),
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
          if (_type == _CreateType.list) ...[
            const SizedBox(height: 16),
            _ColorPickerButton(
              selectedColor: _selectedColor,
              onTap: () => showListColorPickerSheet(
                context,
                _selectedColor,
                (c) {
                  if (mounted) setState(() => _selectedColor = c);
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          CupertinoButton(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
            onPressed: _submit,
            child: Text(
              isFolder
                  ? S.of(context).createFolder
                  : S.of(context).createList,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerButton extends StatelessWidget {
  const _ColorPickerButton({
    required this.selectedColor,
    required this.onTap,
  });

  final int? selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                S.of(context).listColor,
                style: const TextStyle(fontSize: 17),
              ),
            ),
            if (selectedColor == null)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.separator.resolveFrom(context),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 10,
                  color:
                      CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(selectedColor!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
