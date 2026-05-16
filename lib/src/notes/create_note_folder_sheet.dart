import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart' show showModalBottomSheet;

import '../folders/folder_icon_picker.dart';
import '../models/note_folder.dart';
import '../theme/app_theme.dart';
import 'note_controller.dart';

void showCreateNoteFolderSheet(
  BuildContext context,
  NoteController controller, {
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

class _CreateSheet extends StatefulWidget {
  const _CreateSheet({required this.controller, this.parentFolderId});

  final NoteController controller;
  final String? parentFolderId;

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final _nameCtrl = TextEditingController();
  String? _selectedIconId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await widget.controller.addFolder(NoteFolder(
      name: name,
      parentFolderId: widget.parentFolderId,
      iconId: _selectedIconId,
    ));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _openIconPicker() {
    showFolderIconPickerSheet(
      context,
      currentIconId: _selectedIconId,
      isFolder: true,
      onSelected: (id) {
        if (mounted) setState(() => _selectedIconId = id);
      },
    );
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
          Row(
            children: [
              GestureDetector(
                onTap: _openIconPicker,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: buildFolderItemIcon(
                      _selectedIconId,
                      isFolder: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoTextField(
                  controller: _nameCtrl,
                  placeholder: 'Folder name',
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
          const SizedBox(height: 16),
          CupertinoButton(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
            onPressed: _submit,
            child: const Text(
              'Create Folder',
              style: TextStyle(
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
