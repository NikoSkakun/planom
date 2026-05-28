import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'remote_event.dart';

/// On-disk JSON snapshot of the last fetched Google Calendar events so the
/// calendar can render something on cold start before the network refresh
/// completes (and after, when offline).
///
/// Sits at `<docs>/google_calendar_cache.json`. Schema is a flat list of
/// [RemoteEvent.toJson] objects; we don't version it yet because the data
/// is regenerable — on a schema mismatch we just nuke the file and refetch.
///
/// Calendar metadata gets its own snapshot at `<docs>/google_calendars_cache.json`
/// (a map of accountId -> list of [GoogleCalendarMeta.toJson]) so the settings
/// page and the event-creation picker still know each account's calendars on a
/// cold start — or whenever a live `calendarList.list` call fails — instead of
/// showing "No calendars found" while cached events keep rendering.
class GoogleCalendarCache {
  static const _fileName = 'google_calendar_cache.json';
  static const _calendarsFileName = 'google_calendars_cache.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<File> _calendarsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_calendarsFileName');
  }

  Future<List<RemoteEvent>> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      if (raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RemoteEventJson.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> write(List<RemoteEvent> events) async {
    try {
      final f = await _file();
      final json = jsonEncode(events.map((e) => e.toJson()).toList());
      await f.writeAsString(json);
    } catch (_) {
      // Cache is best-effort; failures are non-fatal.
    }
  }

  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await clearCalendars();
  }

  /// Reads the cached per-account calendar metadata. Returns an empty map on a
  /// missing file or any decode error.
  Future<Map<String, List<GoogleCalendarMeta>>> readCalendars() async {
    try {
      final f = await _calendarsFile();
      if (!await f.exists()) return {};
      final raw = await f.readAsString();
      if (raw.isEmpty) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((accountId, cals) => MapEntry(
            accountId,
            (cals as List<dynamic>)
                .map((c) => GoogleCalendarMeta.fromJson(c as Map<String, dynamic>))
                .toList(),
          ));
    } catch (_) {
      return {};
    }
  }

  Future<void> writeCalendars(
      Map<String, List<GoogleCalendarMeta>> calendars) async {
    try {
      final f = await _calendarsFile();
      final json = jsonEncode(calendars.map(
          (accountId, cals) => MapEntry(accountId, cals.map((c) => c.toJson()).toList())));
      await f.writeAsString(json);
    } catch (_) {
      // Cache is best-effort; failures are non-fatal.
    }
  }

  Future<void> clearCalendars() async {
    try {
      final f = await _calendarsFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
