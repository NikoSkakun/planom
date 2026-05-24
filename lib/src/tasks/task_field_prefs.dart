import 'dart:convert';

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
  });

  bool showPriority;
  bool showDate;
  bool showRepeat;
  bool showList;
  bool showDuration;
  bool showTags;
  bool showReminders;

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
      });

  TaskFieldPrefs copy() => TaskFieldPrefs(
        showPriority: showPriority,
        showDate: showDate,
        showRepeat: showRepeat,
        showList: showList,
        showDuration: showDuration,
        showTags: showTags,
        showReminders: showReminders,
      );
}
