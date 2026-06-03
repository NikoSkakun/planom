import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'device_event.dart';

/// On-disk JSON snapshot of the last fetched Apple Calendar (EventKit) events
/// so the calendar can render something on cold start before the device fetch
/// completes. Mirrors `GoogleCalendarCache`.
///
/// Events sit at `<docs>/device_calendar_cache.json` (a flat list of
/// [DeviceEvent.toJson]); calendar metadata at
/// `<docs>/device_calendars_cache.json` (a list of [DeviceCalendarMeta.toJson])
/// so the settings page + event-creation picker know the calendars immediately.
/// The data is regenerable, so on any decode error we just drop the file.
class DeviceCalendarCache {
  static const _fileName = 'device_calendar_cache.json';
  static const _calendarsFileName = 'device_calendars_cache.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<File> _calendarsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_calendarsFileName');
  }

  Future<List<DeviceEvent>> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      if (raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DeviceEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> write(List<DeviceEvent> events) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(events.map((e) => e.toJson()).toList()));
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

  Future<List<DeviceCalendarMeta>> readCalendars() async {
    try {
      final f = await _calendarsFile();
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      if (raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((c) => DeviceCalendarMeta.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeCalendars(List<DeviceCalendarMeta> calendars) async {
    try {
      final f = await _calendarsFile();
      await f.writeAsString(
          jsonEncode(calendars.map((c) => c.toJson()).toList()));
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
