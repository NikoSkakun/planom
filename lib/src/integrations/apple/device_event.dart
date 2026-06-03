/// A native Apple Calendar (EventKit) event held in memory. The source of
/// truth lives in the device's calendar store — Planom never persists
/// [DeviceEvent]s to SQLite (the same invariant as Google's [RemoteEvent]).
///
/// Fields mirror the subset of an `EKEvent` we surface in the UI. The native
/// Swift bridge sends a flat map (see [fromChannel]); the on-disk cache uses
/// [toJson] / [fromJson].
class DeviceEvent {
  DeviceEvent({
    required this.eventId,
    required this.calendarId,
    required this.calendarName,
    required this.calendarColor,
    required this.title,
    this.note,
    required this.date,
    this.doTime,
    this.duration,
    this.isReadOnly = false,
    this.isRecurring = false,
  });

  /// `EKEvent.eventIdentifier` — stable id of the event (or occurrence).
  final String eventId;

  /// Containing calendar's `calendarIdentifier`.
  final String calendarId;

  /// Display name of the containing calendar (for the chip + day view).
  final String calendarName;

  /// ARGB color shown on the chip / card.
  final int calendarColor;

  final String title;
  final String? note;

  /// Local-time date (midnight) the event starts on.
  final DateTime date;

  /// Minutes since midnight for timed events; null = all-day.
  final int? doTime;

  /// Duration in minutes; null = no end / single-day all-day.
  final int? duration;

  /// True for events on calendars the user can't modify (subscribed holidays,
  /// shared read-only calendars). The detail view disables save in that case.
  final bool isReadOnly;

  /// True when this is an instance of a recurring event.
  final bool isRecurring;

  DeviceEvent copyWith({
    String? title,
    String? note,
    bool clearNote = false,
    DateTime? date,
    int? doTime,
    bool clearDoTime = false,
    int? duration,
    bool clearDuration = false,
  }) {
    return DeviceEvent(
      eventId: eventId,
      calendarId: calendarId,
      calendarName: calendarName,
      calendarColor: calendarColor,
      title: title ?? this.title,
      note: clearNote ? null : (note ?? this.note),
      date: date ?? this.date,
      doTime: clearDoTime ? null : (doTime ?? this.doTime),
      duration: clearDuration ? null : (duration ?? this.duration),
      isReadOnly: isReadOnly,
      isRecurring: isRecurring,
    );
  }

  /// Parses the flat map sent by the native EventKit bridge. Returns null when
  /// the payload has no usable start time. The bridge sends `startMs`/`endMs`
  /// as epoch milliseconds (local wall-clock for all-day events) plus an
  /// `isAllDay` flag.
  static DeviceEvent? fromChannel(Map<dynamic, dynamic> m) {
    final id = m['id'] as String?;
    final startMs = (m['startMs'] as num?)?.toInt();
    if (id == null || startMs == null) return null;

    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final date = DateTime(start.year, start.month, start.day);
    final isAllDay = (m['isAllDay'] as bool?) ?? false;

    int? doTime;
    int? duration;
    if (!isAllDay) {
      doTime = start.hour * 60 + start.minute;
      final endMs = (m['endMs'] as num?)?.toInt();
      if (endMs != null) {
        final end = DateTime.fromMillisecondsSinceEpoch(endMs);
        final mins = end.difference(start).inMinutes;
        if (mins > 0) duration = mins;
      }
    } else {
      // All-day: EventKit's end is the inclusive last second of the final day;
      // surface a multi-day span as a duration in whole days.
      final endMs = (m['endMs'] as num?)?.toInt();
      if (endMs != null) {
        final end = DateTime.fromMillisecondsSinceEpoch(endMs);
        final days = DateTime(end.year, end.month, end.day).difference(date).inDays;
        if (days > 1) duration = days * 24 * 60;
      }
    }

    final color = (m['colorArgb'] as num?)?.toInt() ?? 0xFFFF3B30;
    return DeviceEvent(
      eventId: id,
      calendarId: (m['calendarId'] as String?) ?? '',
      calendarName: (m['calendarName'] as String?) ?? '',
      calendarColor: color,
      title: ((m['title'] as String?) ?? '').trim().isEmpty
          ? '(No title)'
          : (m['title'] as String).trim(),
      note: ((m['notes'] as String?) ?? '').trim().isEmpty
          ? null
          : (m['notes'] as String),
      date: date,
      doTime: doTime,
      duration: duration,
      isReadOnly: (m['isReadOnly'] as bool?) ?? false,
      isRecurring: (m['hasRecurrence'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'calendarId': calendarId,
        'calendarName': calendarName,
        'calendarColor': calendarColor,
        'title': title,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'doTime': doTime,
        'duration': duration,
        'isReadOnly': isReadOnly,
        'isRecurring': isRecurring,
      };

  static DeviceEvent fromJson(Map<String, dynamic> m) => DeviceEvent(
        eventId: m['eventId'] as String,
        calendarId: m['calendarId'] as String,
        calendarName: m['calendarName'] as String,
        calendarColor: (m['calendarColor'] as num).toInt(),
        title: m['title'] as String,
        note: m['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        doTime: m['doTime'] as int?,
        duration: m['duration'] as int?,
        isReadOnly: (m['isReadOnly'] as bool?) ?? false,
        isRecurring: (m['isRecurring'] as bool?) ?? false,
      );
}

/// Metadata for one of the device's calendars (a row in the
/// settings → Apple Calendar list).
class DeviceCalendarMeta {
  DeviceCalendarMeta({
    required this.id,
    required this.title,
    required this.color,
    required this.allowsModify,
    this.isPrimary = false,
    this.sourceTitle = '',
  });

  /// `EKCalendar.calendarIdentifier`.
  final String id;
  final String title;

  /// ARGB color.
  final int color;

  /// `EKCalendar.allowsContentModifications` — false for subscribed / shared
  /// read-only calendars.
  final bool allowsModify;

  /// True for the default calendar of the device's events.
  final bool isPrimary;

  /// Account/source the calendar belongs to (e.g. "iCloud", "Gmail").
  final String sourceTitle;

  bool get canWrite => allowsModify;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'color': color,
        'allowsModify': allowsModify,
        'isPrimary': isPrimary,
        'sourceTitle': sourceTitle,
      };

  static DeviceCalendarMeta fromJson(Map<String, dynamic> m) => DeviceCalendarMeta(
        id: m['id'] as String,
        title: m['title'] as String,
        color: (m['color'] as num).toInt(),
        allowsModify: (m['allowsModify'] as bool?) ?? false,
        isPrimary: (m['isPrimary'] as bool?) ?? false,
        sourceTitle: (m['sourceTitle'] as String?) ?? '',
      );

  static DeviceCalendarMeta fromChannel(Map<dynamic, dynamic> m) =>
      DeviceCalendarMeta(
        id: m['id'] as String,
        title: ((m['title'] as String?) ?? '').isEmpty
            ? (m['id'] as String)
            : m['title'] as String,
        color: (m['colorArgb'] as num?)?.toInt() ?? 0xFFFF3B30,
        allowsModify: (m['allowsModify'] as bool?) ?? false,
        isPrimary: (m['isPrimary'] as bool?) ?? false,
        sourceTitle: (m['sourceTitle'] as String?) ?? '',
      );
}

/// A user-edited draft used by `DeviceCalendarController.createEvent`.
class DeviceEventDraft {
  DeviceEventDraft({
    required this.title,
    this.note,
    required this.date,
    this.doTime,
    this.duration,
  });

  final String title;
  final String? note;
  final DateTime date;
  final int? doTime;
  final int? duration;
}
