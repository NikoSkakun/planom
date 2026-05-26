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

/// Visual style of the per-task checkbox.
enum TaskCheckboxStyle {
  /// Rounded square (default — current behavior).
  roundedRect,

  /// Sharp / rectangular square (no corner radius).
  sharpRect,

  /// Circular.
  circle,
}

/// Mutable global the checkbox widget reads to render in the user-selected
/// style. Updated by [SettingsController] whenever [TaskFieldPrefs] change.
/// Kept as a static (rather than threaded through every TaskRow callsite)
/// because the value is read from many render paths.
class TaskCheckboxAppearance {
  TaskCheckboxAppearance._();
  static TaskCheckboxStyle current = TaskCheckboxStyle.roundedRect;
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
    this.useMarkdown = true,
    this.folderCounterMode = FolderCounterMode.directOnly,
    this.checkboxStyle = TaskCheckboxStyle.roundedRect,
  });

  bool showPriority;
  bool showDate;
  bool showRepeat;
  bool showList;
  bool showDuration;
  bool showTags;
  bool showReminders;
  bool showListCount;
  // When false, the task note is rendered and edited as plain text — the
  // markdown preview and the formatting toolbar are skipped entirely.
  bool useMarkdown;
  FolderCounterMode folderCounterMode;
  TaskCheckboxStyle checkboxStyle;

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
        useMarkdown: m['useMarkdown'] != false,
        folderCounterMode: _parseFolderMode(m['folderCounter']),
        checkboxStyle: _parseCheckboxStyle(m['checkboxStyle']),
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
        'useMarkdown': useMarkdown,
        'folderCounter': _encodeFolderMode(folderCounterMode),
        'checkboxStyle': _encodeCheckboxStyle(checkboxStyle),
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
        useMarkdown: useMarkdown,
        folderCounterMode: folderCounterMode,
        checkboxStyle: checkboxStyle,
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

  static TaskCheckboxStyle _parseCheckboxStyle(dynamic v) {
    switch (v) {
      case 'sharpRect':
        return TaskCheckboxStyle.sharpRect;
      case 'circle':
        return TaskCheckboxStyle.circle;
      case 'roundedRect':
      default:
        return TaskCheckboxStyle.roundedRect;
    }
  }

  static String _encodeCheckboxStyle(TaskCheckboxStyle s) {
    switch (s) {
      case TaskCheckboxStyle.sharpRect:
        return 'sharpRect';
      case TaskCheckboxStyle.circle:
        return 'circle';
      case TaskCheckboxStyle.roundedRect:
        return 'roundedRect';
    }
  }
}
