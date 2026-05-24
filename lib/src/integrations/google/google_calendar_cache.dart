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
class GoogleCalendarCache {
  static const _fileName = 'google_calendar_cache.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
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
  }
}
