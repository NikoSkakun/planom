import 'package:googleapis/calendar/v3.dart' as gcal;

/// A Google Calendar event held in memory. The source of truth lives on
/// Google's servers — Planom never persists [RemoteEvent]s to SQLite.
///
/// Fields mirror the subset of [gcal.Event] we surface in the UI. Conversion
/// helpers map to/from the API representation.
class RemoteEvent {
  RemoteEvent({
    required this.googleEventId,
    required this.accountId,
    required this.calendarId,
    required this.calendarName,
    required this.calendarColor,
    required this.title,
    this.note,
    required this.date,
    this.doTime,
    this.duration,
    this.htmlLink,
    this.etag,
    this.isReadOnly = false,
    this.recurringEventId,
  });

  /// Google's event id within [calendarId] (`event.id`).
  final String googleEventId;

  /// The connected account this event belongs to (its email / primary
  /// calendar id). Edits and deletes route through this account's client.
  final String accountId;

  /// Containing calendar id (e.g. `primary` or a long opaque string).
  final String calendarId;

  /// Display name of the containing calendar (for the chip color + day view).
  final String calendarName;

  /// ARGB color shown on the chip / card. Defaults to the Google blue.
  final int calendarColor;

  final String title;
  final String? note;

  /// Local-time date (midnight) the event starts on.
  final DateTime date;

  /// Minutes since midnight for timed events; null = all-day.
  final int? doTime;

  /// Duration in minutes; null = no end / single-day all-day.
  final int? duration;

  /// `https://www.google.com/calendar/event?eid=...` link used by the "Open
  /// in Google Calendar" button when an event is read-only.
  final String? htmlLink;

  /// HTTP ETag from the API — used for optimistic concurrency on edits.
  final String? etag;

  /// True for events on calendars the user has only `reader` / `freeBusyReader`
  /// access to (subscribed holidays, shared work calendars they can view but
  /// not edit, etc.). The detail view disables save in that case.
  final bool isReadOnly;

  /// Set when this is a single instance of a recurring event.
  final String? recurringEventId;

  RemoteEvent copyWith({
    String? title,
    String? note,
    bool clearNote = false,
    DateTime? date,
    int? doTime,
    bool clearDoTime = false,
    int? duration,
    bool clearDuration = false,
    String? etag,
  }) {
    return RemoteEvent(
      googleEventId: googleEventId,
      accountId: accountId,
      calendarId: calendarId,
      calendarName: calendarName,
      calendarColor: calendarColor,
      title: title ?? this.title,
      note: clearNote ? null : (note ?? this.note),
      date: date ?? this.date,
      doTime: clearDoTime ? null : (doTime ?? this.doTime),
      duration: clearDuration ? null : (duration ?? this.duration),
      htmlLink: htmlLink,
      etag: etag ?? this.etag,
      isReadOnly: isReadOnly,
      recurringEventId: recurringEventId,
    );
  }

  /// Builds a [RemoteEvent] from a Calendar API event. Returns null when the
  /// event is cancelled (Google sometimes returns tombstones during sync) or
  /// it has no usable start time.
  static RemoteEvent? fromGoogle(
    gcal.Event e, {
    required String accountId,
    required String calendarId,
    required String calendarName,
    required int calendarColor,
    required bool isReadOnly,
  }) {
    if (e.status == 'cancelled') return null;
    final id = e.id;
    if (id == null) return null;

    DateTime? start;
    int? doTime;
    int? duration;

    if (e.start?.dateTime != null) {
      final s = e.start!.dateTime!.toLocal();
      start = DateTime(s.year, s.month, s.day);
      doTime = s.hour * 60 + s.minute;
      if (e.end?.dateTime != null) {
        final endDt = e.end!.dateTime!.toLocal();
        duration = endDt.difference(s).inMinutes;
        if (duration <= 0) duration = null;
      }
    } else if (e.start?.date != null) {
      final s = e.start!.date!;
      start = DateTime(s.year, s.month, s.day);
      // All-day events use exclusive end dates per the Calendar API spec.
      if (e.end?.date != null) {
        final endDate = e.end!.date!;
        final days = DateTime(endDate.year, endDate.month, endDate.day)
            .difference(start)
            .inDays;
        if (days > 1) duration = days * 24 * 60;
      }
    }

    if (start == null) return null;

    return RemoteEvent(
      googleEventId: id,
      accountId: accountId,
      calendarId: calendarId,
      calendarName: calendarName,
      calendarColor: calendarColor,
      title: (e.summary ?? '').trim().isEmpty
          ? '(No title)'
          : e.summary!.trim(),
      note: (e.description ?? '').trim().isEmpty ? null : e.description,
      date: start,
      doTime: doTime,
      duration: duration,
      htmlLink: e.htmlLink,
      etag: e.etag,
      isReadOnly: isReadOnly,
      recurringEventId: e.recurringEventId,
    );
  }

  /// Builds the API payload for inserting / patching this event.
  gcal.Event toGoogle() {
    final out = gcal.Event(summary: title, description: note);
    if (doTime == null) {
      // All-day event. Calendar API expects exclusive end date.
      final endDate = date.add(Duration(days: (duration ?? 0) ~/ (24 * 60) > 0
          ? (duration ?? 0) ~/ (24 * 60)
          : 1));
      out.start = gcal.EventDateTime(date: date);
      out.end = gcal.EventDateTime(date: endDate);
    } else {
      final startDt = date.add(Duration(minutes: doTime!));
      final endDt = startDt.add(Duration(minutes: duration ?? 60));
      out.start = gcal.EventDateTime(dateTime: startDt.toUtc());
      out.end = gcal.EventDateTime(dateTime: endDt.toUtc());
    }
    return out;
  }
}

/// JSON shape used for the on-disk cache (offline display + cold start).
extension RemoteEventJson on RemoteEvent {
  Map<String, dynamic> toJson() => {
        'googleEventId': googleEventId,
        'accountId': accountId,
        'calendarId': calendarId,
        'calendarName': calendarName,
        'calendarColor': calendarColor,
        'title': title,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'doTime': doTime,
        'duration': duration,
        'htmlLink': htmlLink,
        'etag': etag,
        'isReadOnly': isReadOnly,
        'recurringEventId': recurringEventId,
      };

  static RemoteEvent fromJson(Map<String, dynamic> m) => RemoteEvent(
        googleEventId: m['googleEventId'] as String,
        accountId: (m['accountId'] as String?) ?? '',
        calendarId: m['calendarId'] as String,
        calendarName: m['calendarName'] as String,
        calendarColor: (m['calendarColor'] as num).toInt(),
        title: m['title'] as String,
        note: m['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        doTime: m['doTime'] as int?,
        duration: m['duration'] as int?,
        htmlLink: m['htmlLink'] as String?,
        etag: m['etag'] as String?,
        isReadOnly: (m['isReadOnly'] as bool?) ?? false,
        recurringEventId: m['recurringEventId'] as String?,
      );
}

/// Composite key identifying a calendar within a specific account. Unique
/// across accounts (a shared calendar can appear under more than one account
/// with the same id). The space separator can't appear in an email or a
/// Google calendar id.
String calendarKey(String accountId, String calendarId) =>
    '$accountId $calendarId';

/// Metadata for one of the user's Google calendars (a row in the
/// settings → calendars list).
class GoogleCalendarMeta {
  GoogleCalendarMeta({
    required this.accountId,
    required this.id,
    required this.summary,
    required this.color,
    required this.accessRole,
    required this.primary,
    this.accountReadOnly = false,
  });

  /// The connected account this calendar belongs to.
  final String accountId;

  final String id;
  final String summary;

  /// ARGB color (resolved from Google's color id when present; falls back
  /// to the calendar's `backgroundColor` or the Google blue).
  final int color;

  /// `owner` | `writer` | `reader` | `freeBusyReader`. Reader / freeBusy
  /// calendars surface as read-only inside Planom.
  final String accessRole;

  final bool primary;

  /// True when the owning account was connected read-only — forces the whole
  /// calendar to be non-editable even if the access role would allow writes.
  final bool accountReadOnly;

  bool get canWrite =>
      !accountReadOnly && (accessRole == 'owner' || accessRole == 'writer');

  /// Stable composite key, unique across accounts (a shared calendar can
  /// appear under more than one account with the same [id]).
  String get key => calendarKey(accountId, id);

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'id': id,
        'summary': summary,
        'color': color,
        'accessRole': accessRole,
        'primary': primary,
        'accountReadOnly': accountReadOnly,
      };

  static GoogleCalendarMeta fromJson(Map<String, dynamic> m) =>
      GoogleCalendarMeta(
        accountId: (m['accountId'] as String?) ?? '',
        id: m['id'] as String,
        summary: m['summary'] as String,
        color: (m['color'] as num).toInt(),
        accessRole: m['accessRole'] as String,
        primary: (m['primary'] as bool?) ?? false,
        accountReadOnly: (m['accountReadOnly'] as bool?) ?? false,
      );
}

/// A user-edited draft used by [GoogleCalendarController.createEvent].
class RemoteEventDraft {
  RemoteEventDraft({
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

  gcal.Event toGoogle() {
    final out = gcal.Event(summary: title, description: note);
    if (doTime == null) {
      out.start = gcal.EventDateTime(date: date);
      out.end = gcal.EventDateTime(date: date.add(const Duration(days: 1)));
    } else {
      final startDt = date.add(Duration(minutes: doTime!));
      final endDt = startDt.add(Duration(minutes: duration ?? 60));
      out.start = gcal.EventDateTime(dateTime: startDt.toUtc());
      out.end = gcal.EventDateTime(dateTime: endDt.toUtc());
    }
    return out;
  }
}
