import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/platform_capabilities.dart';
import 'appearance_prefs.dart';

// Cached app documents path — populated by [initBackgroundService] in main.dart
// so background image resolution is synchronous during widget builds.
String? _docsPath;

/// Call once at startup (before runApp) to cache the documents directory.
Future<void> initBackgroundService() async {
  _docsPath ??= (await getApplicationDocumentsDirectory()).path;
}

/// Resolves a relative background image path (`backgrounds/<file>`) to an
/// absolute file path, or null if the format is unrecognised / docs dir not
/// yet cached.
String? resolveBackgroundImagePath(String? rel) {
  if (rel == null) return null;
  if (rel.startsWith('/')) return rel; // legacy / absolute
  if (rel.startsWith('backgrounds/') && _docsPath != null) {
    return '$_docsPath/$rel';
  }
  return null;
}

// Full-screen backgrounds want more resolution than icons. Cap the longest
// side so even very large photos stay reasonable on disk and in memory.
const _kMaxBackgroundDimension = 1600;

/// Opens the system photo picker and copies the chosen image into
/// `backgrounds/` under the documents directory. Returns the relative path
/// (portable across reinstalls) or null if cancelled.
Future<String?> pickBackgroundImage() async {
  String? sourcePath;
  if (PlatformCapabilities.supportsImagePicker) {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _kMaxBackgroundDimension.toDouble(),
      maxHeight: _kMaxBackgroundDimension.toDouble(),
      imageQuality: 90,
    );
    sourcePath = xfile?.path;
  } else {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    sourcePath = result?.files.single.path;
  }
  if (sourcePath == null) return null;
  return _copyBackgroundToDocuments(sourcePath);
}

Future<String> _copyBackgroundToDocuments(String sourcePath) async {
  _docsPath ??= (await getApplicationDocumentsDirectory()).path;
  final dir = Directory('$_docsPath/backgrounds');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final file = File(sourcePath);
  final bytes = await file.readAsBytes();
  Uint8List? resized;
  try {
    resized = await _resizeToFit(bytes, _kMaxBackgroundDimension);
  } catch (e, st) {
    debugPrint('background resize failed, copying original: $e\n$st');
  }

  final ts = DateTime.now().millisecondsSinceEpoch;
  if (resized != null) {
    final outPath = '$_docsPath/backgrounds/$ts.png';
    await File(outPath).writeAsBytes(resized);
    return 'backgrounds/$ts.png';
  }
  final ext = p.extension(sourcePath);
  final outPath = '$_docsPath/backgrounds/$ts$ext';
  await file.copy(outPath);
  return 'backgrounds/$ts$ext';
}

Future<Uint8List?> _resizeToFit(Uint8List src, int maxDimension) async {
  final descriptor = await ui.ImageDescriptor.encoded(
      await ui.ImmutableBuffer.fromUint8List(src));
  final srcW = descriptor.width;
  final srcH = descriptor.height;
  descriptor.dispose();
  final longest = srcW > srcH ? srcW : srcH;
  if (longest <= maxDimension && src.lengthInBytes < 512 * 1024) return null;
  final scale = longest <= maxDimension ? 1.0 : maxDimension / longest;
  final codec = await ui.instantiateImageCodec(
    src,
    targetWidth: (srcW * scale).round(),
    targetHeight: (srcH * scale).round(),
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  codec.dispose();
  if (png == null) return null;
  return png.buffer.asUint8List();
}

/// Paints the user-configured image background (when active) behind [child].
///
/// Only the [BackgroundMode.image] case needs a painter — solid and dynamic
/// color backgrounds are applied through the theme's `scaffoldBackgroundColor`
/// (with transparent scaffolds layered above), so this widget is a no-op for
/// every other mode and returns [child] unchanged.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.appearance,
    required this.child,
  });

  final ThemeAppearance appearance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (appearance.backgroundMode != BackgroundMode.image) return child;
    final path = resolveBackgroundImagePath(appearance.backgroundImagePath);
    final fallback =
        appearance.isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    if (path == null) {
      return ColoredBox(color: fallback, child: child);
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(color: fallback),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
