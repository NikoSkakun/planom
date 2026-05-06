import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../models/app_folder.dart';
import '../models/app_list.dart';
import 'folder_controller.dart';

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
      ));
    } else {
      await widget.controller.addList(AppList(
        name: name,
        folderId: widget.parentFolderId,
      ));
    }
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
          // Type selector
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
              if (v != null) setState(() => _type = v);
            },
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _nameCtrl,
            placeholder: _type == _CreateType.folder ? 'Folder name' : 'List name',
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            color: const Color(0xFFFF4D00),
            borderRadius: BorderRadius.circular(12),
            onPressed: _submit,
            child: Text(
              _type == _CreateType.folder ? 'Create Folder' : 'Create List',
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
