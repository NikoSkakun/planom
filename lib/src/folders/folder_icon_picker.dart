import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../utils/platform_capabilities.dart';

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

// Cached app docs path — populated by initFolderIconService() in main.dart.
String? _docsPath;

/// Call once at startup (before runApp) to cache the documents directory.
/// This makes custom icon resolution synchronous during widget builds.
Future<void> initFolderIconService() async {
  _docsPath = (await getApplicationDocumentsDirectory()).path;
}

/// Returns true for custom-image iconIds (relative or legacy absolute paths).
bool isCustomIconId(String? iconId) {
  if (iconId == null) return false;
  return iconId.startsWith('icons/') || iconId.startsWith('/');
}

/// Resolves a custom iconId to an absolute file path.
/// Returns null if the docs dir isn't cached yet or the format is unrecognised.
String? resolveCustomIconPath(String iconId) {
  if (iconId.startsWith('/')) return iconId; // legacy absolute path
  if (iconId.startsWith('icons/') && _docsPath != null) {
    return '$_docsPath/$iconId';
  }
  return null;
}

/// Renders the appropriate icon widget for a folder/list row (22×22).
///
/// [iconColor] overrides the SF-symbol tint (defaults to [AppColors.accent]).
/// It has no effect on custom-image icons — those are rendered as-is.
Widget buildFolderItemIcon(
  String? iconId, {
  required bool isFolder,
  int? iconColor,
}) {
  final defaultAsset =
      isFolder ? 'assets/icons/folder.png' : 'assets/icons/list.png';

  if (iconId == null) {
    return Image.asset(defaultAsset, width: 22, height: 22);
  }

  final filePath = resolveCustomIconPath(iconId);
  if (filePath != null) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Image.file(
        File(filePath),
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Image.asset(defaultAsset, width: 22, height: 22),
      ),
    );
  }

  // SF-symbol key
  return SizedBox(
    width: 22,
    height: 22,
    child: Center(
      child: Icon(
        folderItemIconData(iconId),
        size: 20,
        color: iconColor != null ? Color(iconColor) : AppColors.accent,
      ),
    ),
  );
}

/// Copies [source] into the app's documents directory under `icons/` and
/// returns the **relative** path (`icons/<timestamp><ext>`) that survives
/// app reinstalls.
Future<String> _copyIconToDocuments(String sourcePath) async {
  _docsPath ??= (await getApplicationDocumentsDirectory()).path;
  final iconsDir = Directory('$_docsPath/icons');
  if (!iconsDir.existsSync()) iconsDir.createSync(recursive: true);
  final ext = p.extension(sourcePath);
  final filename = '${DateTime.now().millisecondsSinceEpoch}$ext';
  await File(sourcePath).copy('$_docsPath/icons/$filename');
  return 'icons/$filename'; // relative — stable across rebuilds
}

/// Opens the system photo picker and returns the relative icon path, or null.
///
/// Mobile uses `image_picker` (the OS gallery UI); desktop has no gallery
/// concept, so we fall back to `file_picker` with image filetype filters.
Future<String?> pickCustomIcon() async {
  if (PlatformCapabilities.supportsImagePicker) {
    final picker = ImagePicker();
    final xfile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return null;
    return _copyIconToDocuments(xfile.path);
  }

  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: false,
  );
  final path = result?.files.single.path;
  if (path == null) return null;
  return _copyIconToDocuments(path);
}

/// Shows the icon picker bottom sheet.
///
/// [currentIconId] is the currently selected iconId (may be null).
/// [currentIconColor] is the optional ARGB color override (null = use accent).
/// [isFolder] controls which default asset is shown as the "none" option.
/// [onSelected] is called with the new iconId + optional iconColor.
/// Color overrides apply only to SF-symbol icons (not custom images);
/// picking a custom image passes back the path + null color.
void showFolderIconPickerSheet(
  BuildContext context, {
  required String? currentIconId,
  int? currentIconColor,
  required bool isFolder,
  required void Function(String? iconId, int? iconColor) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _IconPickerSheet(
      currentIconId: currentIconId,
      currentIconColor: currentIconColor,
      isFolder: isFolder,
      onSelected: onSelected,
    ),
  );
}

// Preset color overrides for SF-symbol icons. Matches the list color picker
// palette so users see a consistent set of swatches across the app.
const _kIconColorPresets = <int>[
  0xFFFF3B30,
  0xFFFF9500,
  0xFFFFCC00,
  0xFF34C759,
  0xFF00C7BE,
  0xFF32ADE6,
  0xFF007AFF,
  0xFF5856D6,
  0xFFAF52DE,
  0xFFFF2D55,
  0xFFA2845E,
  0xFF8E8E93,
];

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({
    required this.currentIconId,
    required this.currentIconColor,
    required this.isFolder,
    required this.onSelected,
  });

  final String? currentIconId;
  final int? currentIconColor;
  final bool isFolder;
  final void Function(String? iconId, int? iconColor) onSelected;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  late String? _selected;
  int? _color;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentIconId;
    _color = widget.currentIconColor;
  }

  Future<void> _pickFromLibrary() async {
    setState(() => _picking = true);
    try {
      final path = await pickCustomIcon();
      if (!mounted) return;
      if (path != null) {
        // Custom images don't accept a color tint — clear any override.
        widget.onSelected(path, null);
        Navigator.of(context, rootNavigator: true).pop();
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _selectPreset(String iconId) {
    setState(() => _selected = iconId);
    widget.onSelected(iconId, _color);
  }

  void _selectColor(int? color) {
    setState(() => _color = color);
    // If no icon is set yet (default/photo tile), don't propagate — the color
    // only matters once the user has picked an SF-symbol icon.
    if (_selected != null && !isCustomIconId(_selected)) {
      widget.onSelected(_selected, color);
    }
  }

  void _resetToDefault() {
    setState(() {
      _selected = null;
      _color = null;
    });
    widget.onSelected(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final s = S.of(context);
    final effectiveColor = _color != null
        ? Color(_color!)
        : AppColors.accent;

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
          Text(
            s.chooseIcon,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  color: effectiveColor,
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
          Text(
            s.iconColor,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ColorDot(
                isSelected: _color == null,
                color: AppColors.accent,
                isDefault: true,
                onTap: () => _selectColor(null),
              ),
              for (final c in _kIconColorPresets)
                _ColorDot(
                  isSelected: _color == c,
                  color: Color(c),
                  isDefault: false,
                  onTap: () => _selectColor(c),
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
                    _picking
                        ? s.opening
                        : s.chooseFromLibrary,
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

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.isSelected,
    required this.color,
    required this.isDefault,
    required this.onTap,
  });

  final bool isSelected;
  final Color color;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: isSelected
              ? Border.all(
                  color: CupertinoColors.label.resolveFrom(context),
                  width: 2.5,
                )
              : isDefault
                  ? Border.all(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 1,
                    )
                  : null,
        ),
        child: isDefault
            ? Icon(
                CupertinoIcons.circle_grid_3x3_fill,
                size: 14,
                color: CupertinoColors.white,
              )
            : (isSelected
                ? const Icon(CupertinoIcons.checkmark,
                    size: 16, color: CupertinoColors.white)
                : null),
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
          color: color ??
              CupertinoColors.tertiarySystemFill.resolveFrom(context),
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
