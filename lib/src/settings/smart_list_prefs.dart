import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum SmartListVisibility { show, showIfNotEmpty, hidden }

class SmartListPrefs {
  SmartListVisibility today;
  SmartListVisibility upcoming;
  SmartListVisibility completed;
  SmartListVisibility trash;

  SmartListPrefs({
    this.today = SmartListVisibility.show,
    this.upcoming = SmartListVisibility.show,
    this.completed = SmartListVisibility.showIfNotEmpty,
    this.trash = SmartListVisibility.showIfNotEmpty,
  });

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/smart_list_prefs.json');
  }

  static Future<SmartListPrefs> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return SmartListPrefs();
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SmartListPrefs(
        today: _parse(data['today']),
        upcoming: _parse(data['upcoming']),
        completed: _parse(data['completed']),
        trash: _parse(data['trash']),
      );
    } catch (_) {
      return SmartListPrefs();
    }
  }

  Future<void> save() async {
    final file = await _file();
    await file.writeAsString(jsonEncode({
      'today': _encode(today),
      'upcoming': _encode(upcoming),
      'completed': _encode(completed),
      'trash': _encode(trash),
    }));
  }

  static SmartListVisibility _parse(dynamic value) {
    switch (value) {
      case 'show':
        return SmartListVisibility.show;
      case 'showIfNotEmpty':
        return SmartListVisibility.showIfNotEmpty;
      case 'hidden':
        return SmartListVisibility.hidden;
      default:
        return SmartListVisibility.show;
    }
  }

  static String _encode(SmartListVisibility v) {
    switch (v) {
      case SmartListVisibility.show:
        return 'show';
      case SmartListVisibility.showIfNotEmpty:
        return 'showIfNotEmpty';
      case SmartListVisibility.hidden:
        return 'hidden';
    }
  }
}
