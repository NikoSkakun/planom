import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../utils/platform_capabilities.dart';
import '../utils/selection_menu.dart';
import 'emoji_catalog.dart';

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

/// Prefix used to encode an emoji / unicode character as an iconId
/// (e.g. `emoji:🎯`). Stored like any other iconId string.
const String kEmojiIconPrefix = 'emoji:';

/// Returns true for custom-image iconIds (relative or legacy absolute paths).
bool isCustomIconId(String? iconId) {
  if (iconId == null) return false;
  return iconId.startsWith('icons/') || iconId.startsWith('/');
}

/// Returns true for emoji / unicode-character iconIds (`emoji:…`).
bool isEmojiIconId(String? iconId) =>
    iconId != null && iconId.startsWith(kEmojiIconPrefix);

/// Extracts the raw character(s) from an emoji iconId.
String emojiFromIconId(String iconId) =>
    iconId.startsWith(kEmojiIconPrefix)
        ? iconId.substring(kEmojiIconPrefix.length)
        : iconId;

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

  if (isEmojiIconId(iconId)) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          emojiFromIconId(iconId),
          textAlign: TextAlign.center,
          // height: 1.0 + even leading distribution removes the emoji's extra
          // line-box padding so the glyph sits centred in the 22×22 box rather
          // than riding slightly low/right.
          style: const TextStyle(
            fontSize: 18,
            height: 1.0,
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    );
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

// Icons are rendered as 22×22 logical px (≤ 88px at 4x). Cap at 256 to give
// us headroom for future high-density displays without bloating storage.
const _kMaxIconDimension = 256;

/// Resizes [source] to fit inside [_kMaxIconDimension] (preserving aspect
/// ratio), re-encodes as PNG and writes the result into the app's documents
/// directory under `icons/`. Returns the **relative** path
/// (`icons/<timestamp>.png`) that survives app reinstalls.
///
/// Returning PNG even for JPEG sources keeps alpha intact (some chosen
/// icons have transparent backgrounds) and is plenty small at 256px.
/// On any decoding failure we fall back to copying the original bytes so
/// the picker never silently swallows the user's selection.
Future<String> _copyIconToDocuments(String sourcePath) async {
  _docsPath ??= (await getApplicationDocumentsDirectory()).path;
  final iconsDir = Directory('$_docsPath/icons');
  if (!iconsDir.existsSync()) iconsDir.createSync(recursive: true);

  final file = File(sourcePath);
  final bytes = await file.readAsBytes();
  Uint8List? resized;
  try {
    resized = await _resizeToFit(bytes, _kMaxIconDimension);
  } catch (e, st) {
    debugPrint('icon resize failed, copying original: $e\n$st');
  }

  final ts = DateTime.now().millisecondsSinceEpoch;
  if (resized != null) {
    final outPath = '$_docsPath/icons/$ts.png';
    await File(outPath).writeAsBytes(resized);
    return 'icons/$ts.png';
  }
  // Fallback: copy as-is preserving extension.
  final ext = p.extension(sourcePath);
  final outPath = '$_docsPath/icons/$ts$ext';
  await file.copy(outPath);
  return 'icons/$ts$ext';
}

/// Decodes [src], resizes so the largest side ≤ [maxDimension], and re-encodes
/// as PNG. Returns null if the image already fits and is therefore not worth
/// re-encoding (we still keep the original bytes around in the caller).
Future<Uint8List?> _resizeToFit(Uint8List src, int maxDimension) async {
  // Probe the source dimensions first so we can skip the resize entirely if
  // the image is already small.
  final descriptor = await ui.ImageDescriptor.encoded(
      await ui.ImmutableBuffer.fromUint8List(src));
  final srcW = descriptor.width;
  final srcH = descriptor.height;
  descriptor.dispose();
  final longest = srcW > srcH ? srcW : srcH;
  final int targetW;
  final int targetH;
  if (longest <= maxDimension) {
    // Already small enough — but we still want to re-encode as PNG to drop
    // EXIF / preview thumbnails / unused metadata that bloats photo-library
    // exports. Skip if it's already a reasonably small PNG to save CPU.
    if (src.lengthInBytes < 64 * 1024) return null;
    targetW = srcW;
    targetH = srcH;
  } else {
    final scale = maxDimension / longest;
    targetW = (srcW * scale).round();
    targetH = (srcH * scale).round();
  }

  final codec = await ui.instantiateImageCodec(
    src,
    targetWidth: targetW,
    targetHeight: targetH,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  codec.dispose();
  if (png == null) return null;
  return png.buffer.asUint8List();
}

/// Resizes [bytes] and writes them as a PNG into the app's `icons/` directory.
/// Returns the **relative** path (`icons/<timestamp>.png`). Used by the URL
/// download path where we have raw bytes rather than a source file.
Future<String> _saveIconBytes(Uint8List bytes) async {
  _docsPath ??= (await getApplicationDocumentsDirectory()).path;
  final iconsDir = Directory('$_docsPath/icons');
  if (!iconsDir.existsSync()) iconsDir.createSync(recursive: true);

  Uint8List out = bytes;
  try {
    final resized = await _resizeToFit(bytes, _kMaxIconDimension);
    if (resized != null) out = resized;
  } catch (e, st) {
    debugPrint('icon resize failed, saving original: $e\n$st');
  }

  final ts = DateTime.now().millisecondsSinceEpoch;
  final outPath = '$_docsPath/icons/$ts.png';
  await File(outPath).writeAsBytes(out);
  return 'icons/$ts.png';
}

/// Opens the system photo gallery and returns the relative icon path, or null.
///
/// Mobile uses `image_picker` (the OS gallery UI) with a max-dimension and
/// quality hint so big photos are pre-scaled by the platform before they
/// even reach Dart. Desktop has no gallery concept, so we fall back to
/// `file_picker` and rely on our own resize pass.
Future<String?> pickIconFromGallery() async {
  if (PlatformCapabilities.supportsImagePicker) {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _kMaxIconDimension.toDouble(),
      maxHeight: _kMaxIconDimension.toDouble(),
      imageQuality: 90,
    );
    if (xfile == null) return null;
    return _copyIconToDocuments(xfile.path);
  }
  return pickIconFromFile();
}

/// Captures a photo with the device camera and returns the relative icon path,
/// or null. Mobile only (no-op elsewhere).
Future<String?> pickIconFromCamera() async {
  if (!PlatformCapabilities.supportsImagePicker) return null;
  final picker = ImagePicker();
  final xfile = await picker.pickImage(
    source: ImageSource.camera,
    maxWidth: _kMaxIconDimension.toDouble(),
    maxHeight: _kMaxIconDimension.toDouble(),
    imageQuality: 90,
  );
  if (xfile == null) return null;
  return _copyIconToDocuments(xfile.path);
}

/// Opens the document picker (file system) filtered to images and returns the
/// relative icon path, or null.
Future<String?> pickIconFromFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: false,
  );
  final path = result?.files.single.path;
  if (path == null) return null;
  return _copyIconToDocuments(path);
}

/// Downloads an image from [url] (http/https), stores it as an icon and returns
/// the relative path. Throws a [FormatException] for malformed URLs and an
/// [HttpException] for non-image / failed responses.
Future<String?> downloadIconFromUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      !uri.hasScheme ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      uri.host.isEmpty) {
    throw const FormatException('Invalid URL');
  }

  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw HttpException('Empty response', uri: uri);
    }
    // Validate that the bytes actually decode as an image before saving.
    final descriptor = await ui.ImageDescriptor.encoded(
        await ui.ImmutableBuffer.fromUint8List(bytes));
    descriptor.dispose();
    return _saveIconBytes(bytes);
  } finally {
    client.close();
  }
}

/// Opens the system photo picker and returns the relative icon path, or null.
/// Backwards-compatible entry point (delegates to [pickIconFromGallery]); used
/// by the routine icon picker.
Future<String?> pickCustomIcon() => pickIconFromGallery();

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

// Tab indices for the icon-picker segmented control.
const int _kTabEmoji = 0;
const int _kTabIcons = 1;
const int _kTabUpload = 2;

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
  late int _tab;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentIconId;
    _color = widget.currentIconColor;
    // Open on the tab matching the current icon (emoji → Emoji, otherwise the
    // Icons gallery; a custom photo has no gallery representation).
    _tab = isEmojiIconId(_selected) ? _kTabEmoji : _kTabIcons;
  }

  /// Runs an image-source [picker], and on success applies the result and
  /// closes the sheet. Surfaces any error in an alert.
  Future<void> _handleSource(Future<String?> Function() picker) async {
    setState(() => _picking = true);
    try {
      final path = await picker();
      if (!mounted) return;
      if (path != null) {
        // Custom images don't accept a color tint — clear any override.
        widget.onSelected(path, null);
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _showUploadMenu() async {
    final s = S.of(context);
    final options = <SelectionMenuOption<int>>[
      if (PlatformCapabilities.supportsImagePicker)
        SelectionMenuOption(
          value: 0,
          label: s.photoLibrary,
          icon: CupertinoIcons.photo_on_rectangle,
        ),
      if (PlatformCapabilities.supportsImagePicker)
        SelectionMenuOption(
          value: 1,
          label: s.takePhoto,
          icon: CupertinoIcons.camera,
        ),
      SelectionMenuOption(
        value: 2,
        label: s.chooseFile,
        icon: CupertinoIcons.folder,
      ),
      SelectionMenuOption(
        value: 3,
        label: s.fromUrl,
        icon: CupertinoIcons.link,
      ),
    ];
    final choice = await showSelectionMenu<int>(
      context: context,
      options: options,
      title: s.uploadAnImage,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 0:
        await _handleSource(pickIconFromGallery);
      case 1:
        await _handleSource(pickIconFromCamera);
      case 2:
        await _handleSource(pickIconFromFile);
      case 3:
        await _handleUrl();
    }
  }

  Future<void> _handleUrl() async {
    final url = await _promptForUrl();
    if (url == null || url.trim().isEmpty || !mounted) return;
    await _handleSource(() => downloadIconFromUrl(url));
  }

  Future<String?> _promptForUrl() {
    final s = S.of(context);
    final ctrl = TextEditingController();
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.imageUrl),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: 'https://…',
            keyboardType: TextInputType.url,
            autocorrect: false,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: Text(s.download),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  void _showError(Object error) {
    final s = S.of(context);
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.downloadFailed),
        content: Text('$error'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.done),
          ),
        ],
      ),
    );
  }

  void _selectPreset(String iconId) {
    setState(() => _selected = iconId);
    widget.onSelected(iconId, _color);
  }

  void _selectColor(int? color) {
    setState(() => _color = color);
    // If no SF-symbol icon is set yet, don't propagate — the color only matters
    // once the user has picked one. Custom images and emoji can't be tinted.
    if (_selected != null &&
        !isCustomIconId(_selected) &&
        !isEmojiIconId(_selected)) {
      widget.onSelected(_selected, color);
    }
  }

  void _selectEmoji(String char) {
    widget.onSelected('$kEmojiIconPrefix$char', null);
    Navigator.of(context, rootNavigator: true).pop();
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
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
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
          // Header: centered title + Reset on the right.
          SizedBox(
            height: 28,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    widget.isFolder ? s.folderIcon : s.listIcon,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: _resetToDefault,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        s.resetLabel,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _tab,
              onValueChanged: (v) {
                if (v != null) setState(() => _tab = v);
              },
              children: {
                _kTabEmoji: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(s.iconTabEmoji),
                ),
                _kTabIcons: Text(s.iconTabIcons),
                _kTabUpload: Text(s.iconTabUpload),
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildTab(context, s)),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, S s) {
    switch (_tab) {
      case _kTabEmoji:
        return _EmojiPicker(
          selected: isEmojiIconId(_selected) ? emojiFromIconId(_selected!) : null,
          onSelected: _selectEmoji,
        );
      case _kTabUpload:
        return _buildUploadTab(context, s);
      case _kTabIcons:
      default:
        return _buildIconsTab(context, s);
    }
  }

  Widget _buildIconsTab(BuildContext context, S s) {
    final effectiveColor = _color != null ? Color(_color!) : AppColors.accent;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // "Default" tile.
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
        const SizedBox(height: 24),
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
      ],
    );
  }

  Widget _buildUploadTab(BuildContext context, S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _picking ? null : _showUploadMenu,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.cloud_upload,
                    size: 18,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _picking ? s.opening : s.uploadAnImage,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.uploadImageHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Categorised emoji grid with a search bar + top category bar. Search matches
/// per-emoji keywords (and the category name as a fallback) via [searchEmojis].
class _EmojiPicker extends StatefulWidget {
  const _EmojiPicker({required this.selected, required this.onSelected});

  final String? selected;
  final void Function(String emoji) onSelected;

  @override
  State<_EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<_EmojiPicker> {
  int _category = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Open on the category that already contains the selected emoji.
    if (widget.selected != null) {
      for (var i = 0; i < kEmojiCatalog.length; i++) {
        if (kEmojiCatalog[i].emojis.contains(widget.selected)) {
          _category = i;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final searching = _query.trim().isNotEmpty;
    final emojis =
        searching ? searchEmojis(_query) : kEmojiCatalog[_category].emojis;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: CupertinoSearchTextField(
            controller: _searchCtrl,
            placeholder: s.search,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        // Category bar (hidden while searching).
        if (!searching) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < kEmojiCatalog.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _category = i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Icon(
                        kEmojiCatalog[i].icon,
                        size: 22,
                        color: i == _category
                            ? AppColors.accent
                            : CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ],
        Expanded(
          child: emojis.isEmpty
              ? Center(
                  child: Text(
                    s.noResults,
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 48,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, i) {
                    final emoji = emojis[i];
                    final isSelected = emoji == widget.selected;
                    return GestureDetector(
                      onTap: () => widget.onSelected(emoji),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        decoration: isSelected
                            ? BoxDecoration(
                                color: CupertinoColors.tertiarySystemFill
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.accent,
                                  width: 2,
                                ),
                              )
                            : null,
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
            ? const Icon(
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
