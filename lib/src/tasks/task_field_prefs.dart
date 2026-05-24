import 'dart:convert';

/// How the task counter next to a folder row is computed.
enum FolderCounterMode {
  /// Show no count next to folders.
  hidden,

  /// Count only tasks in lists that sit directly in this folder.
  directOnly,

  /// Count tasks in this folder and every nested subfolder.
  recursive,
}

/// Which optional fields are shown in the task detail view. Defaults to all
/// visible. Persisted as JSON in `app_settings` under [storageKey].
class TaskFieldPrefs {
  TaskFieldPrefs({
    this.showPriority = true,
    this.showDate = true,
    this.showRepeat = true,
    this.showList = true,
    this.showDuration = true,
    this.showTags = true,
    this.showReminders = true,
    this.showListCount = true,
    this.folderCounterMode = FolderCounterMode.directOnly,
  });

  bool showPriority;
  bool showDate;
  bool showRepeat;
  bool showList;
  bool showDuration;
  bool showTags;
  bool showReminders;
  bool showListCount;
  FolderCounterMode folderCounterMode;

  static const String storageKey = 'task_fields';

  static TaskFieldPrefs fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return TaskFieldPrefs();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return TaskFieldPrefs(
        showPriority: m['priority'] != false,
        showDate: m['date'] != false,
        showRepeat: m['repeat'] != false,
        showList: m['list'] != false,
        showDuration: m['duration'] != false,
        showTags: m['tags'] != false,
        showReminders: m['reminders'] != false,
        showListCount: m['listCount'] != false,
        folderCounterMode: _parseFolderMode(m['folderCounter']),
      );
    } catch (_) {
      return TaskFieldPrefs();
    }
  }

  String toJson() => jsonEncode({
        'priority': showPriority,
        'date': showDate,
        'repeat': showRepeat,
        'list': showList,
        'duration': showDuration,
        'tags': showTags,
        'reminders': showReminders,
        'listCount': showListCount,
        'folderCounter': _encodeFolderMode(folderCounterMode),
      });

  TaskFieldPrefs copy() => TaskFieldPrefs(
        showPriority: showPriority,
        showDate: showDate,
        showRepeat: showRepeat,
        showList: showList,
        showDuration: showDuration,
        showTags: showTags,
        showReminders: showReminders,
        showListCount: showListCount,
        folderCounterMode: folderCounterMode,
      );

  static FolderCounterMode _parseFolderMode(dynamic v) {
    switch (v) {
      case 'hidden':
        return FolderCounterMode.hidden;
      case 'recursive':
        return FolderCounterMode.recursive;
      case 'directOnly':
      default:
        return FolderCounterMode.directOnly;
    }
  }

  static String _encodeFolderMode(FolderCounterMode m) {
    switch (m) {
      case FolderCounterMode.hidden:
        return 'hidden';
      case FolderCounterMode.recursive:
        return 'recursive';
      case FolderCounterMode.directOnly:
        return 'directOnly';
    }
  }
}
