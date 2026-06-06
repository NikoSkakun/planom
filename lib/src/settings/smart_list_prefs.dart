import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum SmartListVisibility { show, showIfNotEmpty, hidden }

class SmartListPrefs {
  // Inbox is treated as a smart list for visibility purposes, even though it's
  // really "tasks without a list assignment". When hidden, new tasks created
  // from the global + button get routed to the user-configured default list
  // (see [SettingsController.defaultTaskListId]) or the first available list.
  SmartListVisibility inbox;
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
  // When false, note bodies are rendered/edited as plain text. The markdown
  // toolbar in NoteDetailView is also hidden in that mode.
  bool notesUseMarkdown;

  SmartListPrefs({
    this.inbox = SmartListVisibility.show,
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
    this.notesUseMarkdown = true,
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
        inbox: _parse(data['inbox']),
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
        notesUseMarkdown: data['notesUseMarkdown'] != false,
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
        'inbox': _encode(inbox),
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
        'notesUseMarkdown': notesUseMarkdown,
      };

  void applyJson(Map<String, dynamic> data) {
    inbox = _parse(data['inbox']);
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
    notesUseMarkdown = data['notesUseMarkdown'] != false;
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
