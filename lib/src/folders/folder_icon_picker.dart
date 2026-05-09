import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Preset (iconId, displayColor) pairs.
const kFolderIconPresets = <(String, int)>[
  ('list.bullet', 0xFFFF4D00),
  ('star.fill', 0xFFFFCC00),
  ('heart.fill', 0xFFFF3B30),
  ('tag.fill', 0xFF32ADE6),
  ('bookmark.fill', 0xFF5856D6),
  ('person.fill', 0xFF007AFF),
  ('house.fill', 0xFFA2845E),
  ('book.fill', 0xFFAF52DE),
  ('music.note', 0xFF5AC8FA),
  ('camera.fill', 0xFF34C759),
  ('cart.fill', 0xFFFF9500),
  ('pencil', 0xFFFF2D55),
  ('folder.fill', 0xFFFF9500),
  ('bolt.fill', 0xFF34C759),
  ('flame.fill', 0xFFFF6B35),
  ('moon.fill', 0xFF5856D6),
];

IconData folderItemIconData(String iconId) => switch (iconId) {
      'list.bullet' => CupertinoIcons.list_bullet,
      'star.fill' => CupertinoIcons.star_fill,
      'heart.fill' => CupertinoIcons.heart_fill,
      'tag.fill' => CupertinoIcons.tag_fill,
      'bookmark.fill' => CupertinoIcons.bookmark_fill,
      'person.fill' => CupertinoIcons.person_fill,
      'house.fill' => CupertinoIcons.house_fill,
      'book.fill' => CupertinoIcons.book_fill,
      'music.note' => CupertinoIcons.music_note,
      'camera.fill' => CupertinoIcons.camera_fill,
      'cart.fill' => CupertinoIcons.cart_fill,
      'pencil' => CupertinoIcons.pencil,
      'folder.fill' => CupertinoIcons.folder_fill,
      'bolt.fill' => CupertinoIcons.bolt_fill,
      'flame.fill' => CupertinoIcons.flame_fill,
      'moon.fill' => CupertinoIcons.moon_fill,
      _ => CupertinoIcons.circle_fill,
    };

bool _isFilePath(String iconId) => iconId.startsWith('/');

/// Renders the appropriate icon widget for a folder/list row (22×22).
Widget buildFolderItemIcon(String? iconId, {required bool isFolder}) {
  if (iconId == null) {
    return Image.asset(
      isFolder ? 'assets/icons/folder.png' : 'assets/icons/list.png',
      width: 22,
      height: 22,
    );
  }
  if (_isFilePath(iconId)) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Image.file(
        File(iconId),
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          isFolder ? 'assets/icons/folder.png' : 'assets/icons/list.png',
          width: 22,
          height: 22,
        ),
      ),
    );
  }
  return SizedBox(
    width: 22,
    height: 22,
    child: Center(
      child: Icon(
        folderItemIconData(iconId),
        size: 20,
        color: const Color(0xFFFF4D00),
      ),
    ),
  );
}

/// Copies [source] into the app's documents directory under `icons/` and
/// returns the destination absolute path.
Future<String> _copyIconToDocuments(String sourcePath) async {
  final docs = await getApplicationDocumentsDirectory();
  final iconsDir = Directory(p.join(docs.path, 'icons'));
  if (!iconsDir.existsSync()) iconsDir.createSync(recursive: true);
  final ext = p.extension(sourcePath);
  final dest = p.join(iconsDir.path, '${DateTime.now().millisecondsSinceEpoch}$ext');
  await File(sourcePath).copy(dest);
  return dest;
}

/// Opens the system photo picker and returns the copied file path, or null if
/// the user cancelled.
Future<String?> pickCustomIcon() async {
  final picker = ImagePicker();
  final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
  if (xfile == null) return null;
  return _copyIconToDocuments(xfile.path);
}

/// Shows the icon picker bottom sheet.
///
/// [currentIconId] is the currently selected iconId (may be null).
/// [isFolder] controls which default asset is shown as the "none" option.
/// [onSelected] is called with the new iconId (null = reset to default).
void showFolderIconPickerSheet(
  BuildContext context, {
  required String? currentIconId,
  required bool isFolder,
  required void Function(String?) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _IconPickerSheet(
      currentIconId: currentIconId,
      isFolder: isFolder,
      onSelected: onSelected,
    ),
  );
}

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({
    required this.currentIconId,
    required this.isFolder,
    required this.onSelected,
  });

  final String? currentIconId;
  final bool isFolder;
  final void Function(String?) onSelected;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  late String? _selected;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentIconId;
  }

  Future<void> _pickFromLibrary() async {
    setState(() => _picking = true);
    try {
      final path = await pickCustomIcon();
      if (!mounted) return;
      if (path != null) {
        widget.onSelected(path);
        Navigator.of(context, rootNavigator: true).pop();
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _selectPreset(String iconId) {
    widget.onSelected(iconId);
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _resetToDefault() {
    widget.onSelected(null);
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const Text(
            'Choose Icon',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // "Default" tile
              _IconTile(
                isSelected: _selected == null,
                onTap: _resetToDefault,
                child: Image.asset(
                  widget.isFolder
                      ? 'assets/icons/folder.png'
                      : 'assets/icons/list.png',
                  width: 26,
                  height: 26,
                ),
              ),
              ...kFolderIconPresets.map(
                (preset) => _IconTile(
                  isSelected: _selected == preset.$1,
                  color: Color(preset.$2),
                  onTap: () => _selectPreset(preset.$1),
                  child: Icon(
                    folderItemIconData(preset.$1),
                    size: 22,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _picking ? null : _pickFromLibrary,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color:
                    CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.photo,
                    size: 18,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _picking ? 'Opening…' : 'Choose from Library',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.isSelected,
    required this.onTap,
    required this.child,
    this.color,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color ?? CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: CupertinoColors.label.resolveFrom(context),
                  width: 2.5,
                )
              : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}
