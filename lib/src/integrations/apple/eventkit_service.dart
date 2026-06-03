import 'package:flutter/services.dart';

import '../../utils/platform_capabilities.dart';
import 'device_event.dart';

/// Authorization state reported by the native EventKit bridge. Mirrors
/// `EKAuthorizationStatus` plus the iOS 17 / macOS 14 `fullAccess` / `writeOnly`
/// split.
enum EventKitAuthStatus {
  notDetermined,
  denied,
  restricted,
  authorized, // legacy full access (pre-iOS 17)
  fullAccess,
  writeOnly,
  unsupported;

  static EventKitAuthStatus parse(String? s) {
    switch (s) {
      case 'denied':
        return EventKitAuthStatus.denied;
      case 'restricted':
        return EventKitAuthStatus.restricted;
      case 'authorized':
        return EventKitAuthStatus.authorized;
      case 'fullAccess':
        return EventKitAuthStatus.fullAccess;
      case 'writeOnly':
        return EventKitAuthStatus.writeOnly;
      case 'notDetermined':
        return EventKitAuthStatus.notDetermined;
      default:
        return EventKitAuthStatus.unsupported;
    }
  }

  /// Whether we can read events (full access on any OS version).
  bool get canRead =>
      this == EventKitAuthStatus.authorized ||
      this == EventKitAuthStatus.fullAccess;
}

/// Thin wrapper over the `app.planom/eventkit` platform channel. Plays the same
/// role for the Apple Calendar integration that `GoogleCalendarApi` plays for
/// Google. Every method no-ops / reports "unsupported" off iOS+macOS.
class EventKitService {
  EventKitService([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('app.planom/eventkit');

  final MethodChannel _channel;

  bool get isSupported => PlatformCapabilities.supportsEventKit;

  Future<EventKitAuthStatus> authorizationStatus() async {
    if (!isSupported) return EventKitAuthStatus.unsupported;
    final s = await _channel.invokeMethod<String>('authorizationStatus');
    return EventKitAuthStatus.parse(s);
  }

  /// Requests calendar access (full access on iOS 17 / macOS 14, legacy access
  /// otherwise). Returns true when granted.
  Future<bool> requestAccess() async {
    if (!isSupported) return false;
    final granted = await _channel.invokeMethod<bool>('requestAccess');
    return granted ?? false;
  }

  Future<List<DeviceCalendarMeta>> listCalendars() async {
    if (!isSupported) return const [];
    final raw = await _channel.invokeMethod<List<dynamic>>('listCalendars');
    if (raw == null) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(DeviceCalendarMeta.fromChannel)
        .toList();
  }

  Future<List<DeviceEvent>> fetchEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async {
    if (!isSupported || calendarIds.isEmpty) return const [];
    final raw = await _channel.invokeMethod<List<dynamic>>('fetchEvents', {
      'startMs': start.millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
      'calendarIds': calendarIds,
    });
    if (raw == null) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(DeviceEvent.fromChannel)
        .whereType<DeviceEvent>()
        .toList();
  }

  Future<DeviceEvent?> createEvent(
    DeviceEventDraft draft, {
    required String calendarId,
  }) async {
    if (!isSupported) return null;
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'createEvent', _eventArgs(calendarId: calendarId, draft: draft));
    return res == null ? null : DeviceEvent.fromChannel(res);
  }

  Future<DeviceEvent?> updateEvent(DeviceEvent event) async {
    if (!isSupported) return null;
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('updateEvent', {
      'id': event.eventId,
      'title': event.title,
      'notes': event.note,
      ..._timeArgs(event.date, event.doTime, event.duration),
    });
    return res == null ? null : DeviceEvent.fromChannel(res);
  }

  Future<bool> deleteEvent(DeviceEvent event) async {
    if (!isSupported) return false;
    final ok =
        await _channel.invokeMethod<bool>('deleteEvent', {'id': event.eventId});
    return ok ?? false;
  }

  Map<String, dynamic> _eventArgs({
    required String calendarId,
    required DeviceEventDraft draft,
  }) =>
      {
        'calendarId': calendarId,
        'title': draft.title,
        'notes': draft.note,
        ..._timeArgs(draft.date, draft.doTime, draft.duration),
      };

  /// Converts a Planom (date, doTime, duration) triple into the start/end
  /// epoch-millisecond + all-day shape the native side expects.
  Map<String, dynamic> _timeArgs(DateTime date, int? doTime, int? duration) {
    if (doTime == null) {
      // All-day: span N whole days (default 1).
      final days = (duration != null && duration >= 24 * 60)
          ? duration ~/ (24 * 60)
          : 1;
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(Duration(days: days));
      return {
        'isAllDay': true,
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      };
    }
    final start = date.add(Duration(minutes: doTime));
    final end = start.add(Duration(minutes: duration ?? 60));
    return {
      'isAllDay': false,
      'startMs': start.millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
    };
  }
}
