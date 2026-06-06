import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart' show showModalBottomSheet;

import '../localization/strings.dart';
import '../models/app_folder.dart';
import '../models/app_list.dart';
import '../models/list_type.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';
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

/// Bundles all editable fields the Edit sheet needs to know about. Color is
/// only meaningful for lists — folders pass null and `supportsColor: false`.
class EditItemArgs {
  const EditItemArgs({
    required this.name,
    required this.iconId,
    required this.iconColor,
    required this.color,
    required this.isFolder,
    required this.supportsColor,
    this.description,
  });

  final String name;
  final String? iconId;
  final int? iconColor;
  final int? color;
  final bool isFolder;
  final bool supportsColor;
  final String? description;
}

class EditItemResult {
  const EditItemResult({
    required this.name,
    required this.iconId,
    required this.iconColor,
    required this.color,
    this.description,
  });

  final String name;
  final String? iconId;
  final int? iconColor;
  final int? color;
  final String? description;
}

/// Single sheet that composes Rename + Change Icon + (for lists) Change Color.
/// Used by both list and folder edit dropdowns. Returns null if dismissed.
Future<EditItemResult?> showEditItemSheet(
  BuildContext context, {
  required EditItemArgs args,
}) {
  return showModalBottomSheet<EditItemResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _EditItemSheet(args: args),
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

enum CreateSheetInitial { list, folder }

void showCreateFolderListSheet(
  BuildContext context,
  FolderController controller, {
  String? parentFolderId,
  CreateSheetInitial initialType = CreateSheetInitial.list,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _CreateSheet(
      controller: controller,
      parentFolderId: parentFolderId,
      initialType: initialType == CreateSheetInitial.folder
          ? _CreateType.folder
          : _CreateType.list,
    ),
  );
}

enum _CreateType { folder, list }

class _CreateSheet extends StatefulWidget {
  const _CreateSheet({
    required this.controller,
    this.parentFolderId,
    this.initialType = _CreateType.list,
  });

  final FolderController controller;
  final String? parentFolderId;
  final _CreateType initialType;

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  late _CreateType _type = widget.initialType;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int? _selectedColor;
  late String? _selectedIconId =
      _type == _CreateType.folder ? AppDefaults.folderIcon : AppDefaults.listIcon;
  int? _selectedIconColor;
  ListType _listType = ListType.tasks;

  void _onTypeChanged(_CreateType next) {
    if (next == _type) return;
    setState(() {
      _type = next;
      // Switching folder ↔ list — apply that type's default icon if the user
      // hasn't picked one yet (or has the previous type's default selected).
      final prevDefault =
          _type == _CreateType.folder ? AppDefaults.folderIcon : AppDefaults.listIcon;
      if (_selectedIconId == prevDefault) {
        _selectedIconId = next == _CreateType.folder
            ? AppDefaults.folderIcon
            : AppDefaults.listIcon;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final desc = _descCtrl.text.trim();
    if (_type == _CreateType.folder) {
      await widget.controller.addFolder(AppFolder(
        name: name,
        parentFolderId: widget.parentFolderId,
        iconId: _selectedIconId,
        iconColor: _selectedIconColor,
        description: desc.isEmpty ? null : desc,
      ));
    } else {
      await widget.controller.addList(AppList(
        name: name,
        folderId: widget.parentFolderId,
        color: _selectedColor,
        iconId: _selectedIconId,
        iconColor: _selectedIconColor,
        description: desc.isEmpty ? null : desc,
        listType: _listType,
      ));
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _pickListType() async {
    final s = S.of(context);
    final picked = await showSelectionMenu<ListType>(
      context: context,
      title: s.listType,
      current: _listType,
      options: [
        SelectionMenuOption(value: ListType.tasks, label: s.listTypeTasks),
        SelectionMenuOption(
            value: ListType.birthdays, label: s.listTypeBirthdays),
        SelectionMenuOption(value: ListType.shopping, label: s.listTypeShopping),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _listType = picked);
    }
  }

  String _listTypeLabel(S s, ListType t) {
    switch (t) {
      case ListType.tasks:
        return s.listTypeTasks;
      case ListType.birthdays:
        return s.listTypeBirthdays;
      case ListType.shopping:
        return s.listTypeShopping;
    }
  }

  void _openIconPicker() {
    showFolderIconPickerSheet(
      context,
      currentIconId: _selectedIconId,
      currentIconColor: _selectedIconColor,
      isFolder: _type == _CreateType.folder,
      onSelected: (id, color) {
        if (mounted) {
          setState(() {
            _selectedIconId = id;
            _selectedIconColor = color;
          });
        }
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
              if (v != null) _onTypeChanged(v);
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
          const SizedBox(height: 12),
          _DescriptionField(controller: _descCtrl),
          if (_type == _CreateType.list) ...[
            const SizedBox(height: 16),
            _ListTypeButton(
              label: _listTypeLabel(S.of(context), _listType),
              onTap: _pickListType,
            ),
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

class _EditItemSheet extends StatefulWidget {
  const _EditItemSheet({required this.args});

  final EditItemArgs args;

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String? _iconId;
  late int? _iconColor;
  late int? _color;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.args.name);
    _descCtrl = TextEditingController(text: widget.args.description ?? '');
    _iconId = widget.args.iconId;
    _iconColor = widget.args.iconColor;
    _color = widget.args.color;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final desc = _descCtrl.text.trim();
    Navigator.of(context, rootNavigator: true).pop(EditItemResult(
      name: name,
      iconId: _iconId,
      iconColor: _iconColor,
      color: _color,
      description: desc.isEmpty ? null : desc,
    ));
  }

  void _openIconPicker() {
    showFolderIconPickerSheet(
      context,
      currentIconId: _iconId,
      currentIconColor: _iconColor,
      isFolder: widget.args.isFolder,
      onSelected: (id, color) {
        if (mounted) {
          setState(() {
            _iconId = id;
            _iconColor = color;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final s = S.of(context);

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
          Center(
            child: Text(
              widget.args.isFolder ? s.editFolder : s.editList,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                // Modal bottom sheets are Material widgets — a const TextStyle
                // without a color falls through to Material's dark text, which
                // becomes invisible in dark mode. Pin label color.
                color: CupertinoColors.label.resolveFrom(context),
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
                      _iconId,
                      isFolder: widget.args.isFolder,
                      iconColor: _iconColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoTextField(
                  controller: _nameCtrl,
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
          const SizedBox(height: 12),
          _DescriptionField(controller: _descCtrl),
          if (widget.args.supportsColor) ...[
            const SizedBox(height: 16),
            _ColorPickerButton(
              selectedColor: _color,
              onTap: () => showListColorPickerSheet(
                context,
                _color,
                (c) {
                  if (mounted) setState(() => _color = c);
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
              s.save,
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

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: S.of(context).descriptionPlaceholder,
      textCapitalization: TextCapitalization.sentences,
      minLines: 1,
      maxLines: 4,
      style: const TextStyle(fontSize: 15),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

class _ListTypeButton extends StatelessWidget {
  const _ListTypeButton({required this.label, required this.onTap});

  final String label;
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
                S.of(context).listType,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 4),
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
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
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
