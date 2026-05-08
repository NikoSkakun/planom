import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../models/app_folder.dart';
import '../models/app_list.dart';
import 'folder_controller.dart';
import 'folder_icon_picker.dart';
import 'list_color_picker.dart';

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
                  const Text('List'),
                ],
              ),
              _CreateType.folder: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icons/folder.png',
                      width: 16, height: 16),
                  const SizedBox(width: 6),
                  const Text('Folder'),
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
                  placeholder: isFolder ? 'Folder name' : 'List name',
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
            ListColorSwatches(
              selected: _selectedColor,
              onSelect: (c) => setState(() => _selectedColor = c),
            ),
          ],
          const SizedBox(height: 16),
          CupertinoButton(
            color: const Color(0xFFFF4D00),
            borderRadius: BorderRadius.circular(12),
            onPressed: _submit,
            child: Text(
              isFolder ? 'Create Folder' : 'Create List',
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
