import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum SmartListVisibility { show, showIfNotEmpty, hidden }

class SmartListPrefs {
  SmartListVisibility today;
  SmartListVisibility tomorrow;
  SmartListVisibility upcoming;
  SmartListVisibility allTasks;
  SmartListVisibility completed;
  SmartListVisibility trash;
  SmartListVisibility notesTrash;
  bool hideTabLabels;
  bool showAddFolderButton;
  bool showNotesAddFolderButton;

  SmartListPrefs({
    this.today = SmartListVisibility.show,
    this.tomorrow = SmartListVisibility.showIfNotEmpty,
    this.upcoming = SmartListVisibility.show,
    this.allTasks = SmartListVisibility.hidden,
    this.completed = SmartListVisibility.showIfNotEmpty,
    this.trash = SmartListVisibility.showIfNotEmpty,
    this.notesTrash = SmartListVisibility.showIfNotEmpty,
    this.hideTabLabels = false,
    this.showAddFolderButton = true,
    this.showNotesAddFolderButton = true,
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
        tomorrow: _parse(data['tomorrow'],
            fallback: SmartListVisibility.showIfNotEmpty),
        upcoming: _parse(data['upcoming']),
        allTasks: _parse(data['allTasks'],
            fallback: SmartListVisibility.hidden),
        completed: _parse(data['completed']),
        trash: _parse(data['trash']),
        notesTrash: _parse(data['notesTrash'],
            fallback: SmartListVisibility.showIfNotEmpty),
        hideTabLabels: data['hideTabLabels'] == true,
        showAddFolderButton: data['showAddFolderButton'] != false,
        showNotesAddFolderButton:
            data['showNotesAddFolderButton'] != false,
      );
    } catch (_) {
      return SmartListPrefs();
    }
  }

  Future<void> save() async {
    final file = await _file();
    await file.writeAsString(jsonEncode(toJson()));
  }

  Map<String, dynamic> toJson() => {
        'today': _encode(today),
        'tomorrow': _encode(tomorrow),
        'upcoming': _encode(upcoming),
        'allTasks': _encode(allTasks),
        'completed': _encode(completed),
        'trash': _encode(trash),
        'notesTrash': _encode(notesTrash),
        'hideTabLabels': hideTabLabels,
        'showAddFolderButton': showAddFolderButton,
        'showNotesAddFolderButton': showNotesAddFolderButton,
      };

  void applyJson(Map<String, dynamic> data) {
    today = _parse(data['today']);
    tomorrow =
        _parse(data['tomorrow'], fallback: SmartListVisibility.showIfNotEmpty);
    upcoming = _parse(data['upcoming']);
    allTasks = _parse(data['allTasks'], fallback: SmartListVisibility.hidden);
    completed = _parse(data['completed']);
    trash = _parse(data['trash']);
    notesTrash = _parse(data['notesTrash'],
        fallback: SmartListVisibility.showIfNotEmpty);
    hideTabLabels = data['hideTabLabels'] == true;
    showAddFolderButton = data['showAddFolderButton'] != false;
    showNotesAddFolderButton =
        data['showNotesAddFolderButton'] != false;
  }

  static SmartListVisibility _parse(dynamic value,
      {SmartListVisibility fallback = SmartListVisibility.show}) {
    switch (value) {
      case 'show':
        return SmartListVisibility.show;
      case 'showIfNotEmpty':
        return SmartListVisibility.showIfNotEmpty;
      case 'hidden':
        return SmartListVisibility.hidden;
      default:
        return fallback;
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
