import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Tracks which Google Font keys have been seen/rendered in the font picker
/// (and thus cached to disk by the google_fonts package). Also persists the
/// custom preview phrase the user can set via the ⋯ menu.
class FontCache {
  FontCache._();
  static final FontCache instance = FontCache._();

  Set<String> _cachedKeys = {};
  String _previewText = 'The quick brown fox';
  bool _loaded = false;

  String get previewText => _previewText;

  bool isCached(String key) => _cachedKeys.contains(key);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _file();
      if (await file.exists()) {
        final map = json.decode(await file.readAsString()) as Map<String, dynamic>;
        final keys = map['keys'];
        if (keys is List) _cachedKeys = Set<String>.from(keys.cast<String>());
        final pt = map['previewText'];
        if (pt is String && pt.trim().isNotEmpty) _previewText = pt.trim();
      }
    } catch (_) {}
  }

  Future<void> markCached(String key) async {
    if (_cachedKeys.contains(key)) return;
    _cachedKeys.add(key);
    await _save();
  }

  Future<void> setPreviewText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == _previewText) return;
    _previewText = trimmed;
    await _save();
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(json.encode({
        'keys': _cachedKeys.toList(),
        'previewText': _previewText,
      }));
    } catch (_) {}
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/font_cache.json');
  }
}
