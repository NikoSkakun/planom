import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../database/database_service.dart';
import '../../notifications/notification_service.dart';
import 'device_calendar_cache.dart';
import 'device_event.dart';
import 'eventkit_service.dart';

/// Global controller for the native Apple Calendar (EventKit) integration.
///
/// Single device store (no multi-account, unlike Google). Source-of-truth
/// invariant: a device event lives only in EventKit; Planom keeps an in-memory
/// view + on-disk cache and never writes device events into the local `events`
/// table.
///
/// State persisted in the global `planom.db` `app_settings` table (all keys
/// start with `ekcal_`, so [isReservedKey] excludes them from backups):
///   `ekcal_selected`         — JSON list of selected calendar ids
///   `ekcal_default_calendar` — calendar id new events default to
///   `ekcal_loaded_from/to`   — fetched time window (ms since epoch)
///   `ekcal_last_sync_at`     — last refresh timestamp (ms since epoch)
///   `ekcal_event_reminders`  — JSON map of Planom-only reminder offsets
class DeviceCalendarController with ChangeNotifier {
  DeviceCalendarController({
    required DatabaseService db,
    EventKitService? service,
    DeviceCalendarCache? cache,
  })  : _db = db,
        _service = service ?? EventKitService(),
        _cache = cache ?? DeviceCalendarCache();

  final DatabaseService _db;
  final EventKitService _service;
  final DeviceCalendarCache _cache;

  // ── Settings keys ──────────────────────────────────────────────────────
  static const _kSelected = 'ekcal_selected';
  static const _kDefaultCalendar = 'ekcal_default_calendar';
  static const _kLastSyncAt = 'ekcal_last_sync_at';
  static const _kLoadedFrom = 'ekcal_loaded_from';
  static const _kLoadedTo = 'ekcal_loaded_to';
  static const _kEventReminders = 'ekcal_event_reminders';

  /// Every key this controller owns is `ekcal_`-prefixed; backups exclude them.
  static bool isReservedKey(String key) => key.startsWith('ekcal_');

  // ── In-memory state ───────────────────────────────────────────────────

  /// Whether the underlying EventKit bridge is usable here. Backed by the
  /// service so a fake can enable it in tests; in production the real service
  /// reports `PlatformCapabilities.supportsEventKit`.
  bool get isAvailable => _service.isSupported;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  EventKitAuthStatus _authStatus = EventKitAuthStatus.notDetermined;
  EventKitAuthStatus get authorizationStatus => _authStatus;

  /// True once the user has granted read access — events can be fetched.
  bool get isAuthorized => _authStatus.canRead;

  List<DeviceCalendarMeta> _calendars = const [];
  List<DeviceCalendarMeta> get availableCalendars =>
      List.unmodifiable(_calendars);

  Set<String> _selectedIds = <String>{};
  Set<String> get selectedCalendarIds => Set.unmodifiable(_selectedIds);
  bool isCalendarSelected(DeviceCalendarMeta cal) =>
      _selectedIds.contains(cal.id);

  /// Writable + selected calendars — source list for the event-creation picker
  /// and the default-calendar picker.
  List<DeviceCalendarMeta> get writableSelectedCalendars => _calendars
      .where((c) => c.canWrite && _selectedIds.contains(c.id))
      .toList();

  String? _defaultCalendarId;
  String? get defaultCalendarId => _defaultCalendarId;

  DeviceCalendarMeta? get defaultCalendar {
    if (_defaultCalendarId == null) return null;
    for (final c in _calendars) {
      if (c.id == _defaultCalendarId) return c;
    }
    return null;
  }

  DateTime? _lastSyncAt;
  DateTime? get lastSyncAt => _lastSyncAt;

  DateTime? _loadedFrom;
  DateTime? _loadedTo;

  List<DeviceEvent> _events = const [];
  List<DeviceEvent> get events => List.unmodifiable(_events);

  List<DeviceEvent> eventsForDate(DateTime date) {
    if (!isAuthorized) return const [];
    return _events
        .where((e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day &&
            _selectedIds.contains(e.calendarId))
        .toList();
  }

  // ── Planom-only reminders ───────────────────────────────────────────────

  /// Reminders attached to device events inside Planom, keyed by `ek:<eventId>`
  /// so they never collide with Google's reminder keys. The reminders stay on
  /// the device; the event itself in EventKit is untouched.
  Map<String, List<int>> _eventReminders = {};

  String _reminderKey(DeviceEvent e) => 'ek:${e.eventId}';

  /// Identity used to de-duplicate events in memory. A recurring event expands
  /// into many occurrences that all share one `eventId`, so the id alone would
  /// collapse the whole series into a single row (the last-iterated occurrence,
  /// i.e. the furthest-future one — which is exactly why past occurrences
  /// disappeared). Keying by id + occurrence date/time keeps every occurrence.
  String _occKey(DeviceEvent e) =>
      '${e.eventId}|${e.date.year}-${e.date.month}-${e.date.day}|${e.doTime ?? -1}';

  List<int> remindersForEvent(DeviceEvent event) =>
      List.unmodifiable(_eventReminders[_reminderKey(event)] ?? const <int>[]);

  Future<void> setEventReminders(DeviceEvent event, List<int> offsets) async {
    final key = _reminderKey(event);
    if (offsets.isEmpty) {
      _eventReminders.remove(key);
    } else {
      _eventReminders[key] = List<int>.from(offsets);
    }
    await _persistEventReminders();
    await NotificationService.instance.scheduleRemoteEventReminders(
      key: key,
      title: event.title,
      date: event.date,
      doTime: event.doTime,
      offsets: offsets,
    );
    notifyListeners();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  Future<void> load() async {
    if (!isAvailable) return;
    await _readPrefs();
    _events = await _cache.read();
    _calendars = await _cache.readCalendars();
    _authStatus = await _service.authorizationStatus();
    await _rescheduleEventReminders();
    notifyListeners();
    if (isAuthorized) {
      // Paint from cache, refresh device calendars + events in the background.
      unawaited(refresh());
    }
  }

  /// Requests calendar access. On grant, loads the device calendars (selecting
  /// them all by default) and refreshes events.
  Future<bool> connect() async {
    if (!isAvailable) return false;
    _setLoading(true);
    _lastError = null;
    try {
      final granted = await _service.requestAccess();
      _authStatus = await _service.authorizationStatus();
      if (!granted || !isAuthorized) {
        notifyListeners();
        return false;
      }
      final cals = await _service.listCalendars();
      _calendars = cals;
      await _cache.writeCalendars(cals);
      // Select every calendar by default on first connect.
      if (_selectedIds.isEmpty) {
        _selectedIds = cals.map((c) => c.id).toSet();
        await _persistSelected();
      }
      _resetLoadedRange();
      await _persistLoadedRange();
      notifyListeners();
      await refresh();
      return true;
    } catch (e, st) {
      debugPrint('DeviceCalendarController.connect failed: $e\n$st');
      _lastError = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Forgets the connection: clears the selection, events, cache, default, and
  /// loaded range. Re-reads the OS authorization status (the user may revoke
  /// access in system Settings independently).
  Future<void> disconnect() async {
    _setLoading(true);
    try {
      for (final key in _eventReminders.keys.toList()) {
        await NotificationService.instance.cancelRemoteEventReminders(key);
      }
      _eventReminders = {};
      _events = const [];
      _calendars = const [];
      _selectedIds = <String>{};
      _defaultCalendarId = null;
      _resetLoadedRange();
      await _persistEventReminders();
      await _persistSelected();
      await _db.setAppSetting(_kDefaultCalendar, '');
      await _persistLoadedRange();
      await _cache.clear();
      _authStatus = await _service.authorizationStatus();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _readPrefs() async {
    final rows = await _db.getAppSettings();
    for (final row in rows) {
      final key = row['key'] as String;
      final value = row['value'] as String?;
      if (value == null || value.isEmpty) continue;
      switch (key) {
        case _kSelected:
          try {
            _selectedIds =
                (jsonDecode(value) as List<dynamic>).cast<String>().toSet();
          } catch (_) {
            _selectedIds = <String>{};
          }
        case _kDefaultCalendar:
          _defaultCalendarId = value;
        case _kLastSyncAt:
          final ms = int.tryParse(value);
          if (ms != null) _lastSyncAt = DateTime.fromMillisecondsSinceEpoch(ms);
        case _kLoadedFrom:
          final ms = int.tryParse(value);
          if (ms != null) _loadedFrom = DateTime.fromMillisecondsSinceEpoch(ms);
        case _kLoadedTo:
          final ms = int.tryParse(value);
          if (ms != null) _loadedTo = DateTime.fromMillisecondsSinceEpoch(ms);
        case _kEventReminders:
          try {
            final decoded = jsonDecode(value) as Map<String, dynamic>;
            _eventReminders = decoded.map((k, v) =>
                MapEntry(k, (v as List<dynamic>).map((e) => e as int).toList()));
          } catch (_) {
            _eventReminders = {};
          }
      }
    }
  }

  Future<void> _persistSelected() =>
      _db.setAppSetting(_kSelected, jsonEncode(_selectedIds.toList()));

  Future<void> _persistEventReminders() =>
      _db.setAppSetting(_kEventReminders, jsonEncode(_eventReminders));

  /// Reconciles the OS notification schedule with [_eventReminders] against the
  /// currently-loaded events: matched events get their reminders (re)scheduled,
  /// reminders for events no longer present get cancelled.
  Future<void> _rescheduleEventReminders() async {
    if (_eventReminders.isEmpty) return;
    final byKey = <String, DeviceEvent>{
      for (final e in _events) _reminderKey(e): e,
    };
    for (final entry in _eventReminders.entries) {
      final ev = byKey[entry.key];
      if (ev == null) {
        await NotificationService.instance.cancelRemoteEventReminders(entry.key);
      } else {
        await NotificationService.instance.scheduleRemoteEventReminders(
          key: entry.key,
          title: ev.title,
          date: ev.date,
          doTime: ev.doTime,
          offsets: entry.value,
        );
      }
    }
  }

  // ── Calendar selection / default ────────────────────────────────────────

  Future<void> setCalendarSelected(DeviceCalendarMeta cal, bool selected) async {
    if (selected) {
      if (!_selectedIds.add(cal.id)) return;
      // Newly-selected calendar has no events loaded; reset the window so the
      // next refresh re-fetches everything.
      _resetLoadedRange();
      await _persistLoadedRange();
    } else {
      if (!_selectedIds.remove(cal.id)) return;
      _events = _events.where((e) => e.calendarId != cal.id).toList();
      if (_defaultCalendarId == cal.id) {
        _defaultCalendarId = null;
        await _db.setAppSetting(_kDefaultCalendar, '');
      }
      await _cache.write(_events);
    }
    await _persistSelected();
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> setDefaultCalendar(DeviceCalendarMeta cal) async {
    _defaultCalendarId = cal.id;
    await _db.setAppSetting(_kDefaultCalendar, cal.id);
    notifyListeners();
  }

  Future<void> clearDefaultCalendar() async {
    _defaultCalendarId = null;
    await _db.setAppSetting(_kDefaultCalendar, '');
    notifyListeners();
  }

  // ── Refresh ───────────────────────────────────────────────────────────

  static const _defaultPastDays = 365;
  static const _defaultFutureDays = 365;

  /// Serializes every fetch so they never interleave and race to overwrite
  /// `_events`.
  Future<void> _opChain = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() op) {
    final prior = _opChain;
    final done = Completer<void>();
    _opChain = done.future;
    Future<void> run() async {
      try {
        await prior;
      } catch (_) {}
      await op();
    }

    final result = run();
    result.whenComplete(done.complete);
    return result;
  }

  Future<void> refresh({DateTime? from, DateTime? to}) =>
      _enqueue(() => _refreshLocked(from: from, to: to));

  Future<void> _refreshCalendarsLocked() async {
    try {
      final cals = await _service.listCalendars();
      if (cals.isNotEmpty || _calendars.isEmpty) {
        final firstLoad = _calendars.isEmpty;
        _calendars = cals;
        await _cache.writeCalendars(cals);
        // Prune selections / default for calendars that no longer exist.
        final ids = cals.map((c) => c.id).toSet();
        if (firstLoad && _selectedIds.isEmpty) {
          _selectedIds = ids.toSet();
          await _persistSelected();
        } else {
          final before = _selectedIds.length;
          _selectedIds = _selectedIds.where(ids.contains).toSet();
          if (_selectedIds.length != before) await _persistSelected();
        }
        if (_defaultCalendarId != null && !ids.contains(_defaultCalendarId)) {
          _defaultCalendarId = null;
          await _db.setAppSetting(_kDefaultCalendar, '');
        }
      }
    } catch (e) {
      debugPrint('DeviceCalendarController.listCalendars failed: $e');
      _lastError = e.toString();
    }
  }

  Future<void> _refreshLocked({DateTime? from, DateTime? to}) async {
    if (!isAuthorized) return;
    _setLoading(true);
    _lastError = null;
    try {
      await _refreshCalendarsLocked();
      final now = DateTime.now();
      final timeMin =
          from ?? now.subtract(const Duration(days: _defaultPastDays));
      final timeMax = to ?? now.add(const Duration(days: _defaultFutureDays));
      final ids = _selectedIds.toList();
      if (ids.isEmpty) {
        _events = const [];
        await _cache.write(_events);
        notifyListeners();
        return;
      }
      // Seed from out-of-window events so previously-loaded ranges survive.
      final byKey = <String, DeviceEvent>{
        for (final e in _events) _occKey(e): e,
      };
      // EventKit returns the full set for the window; authoritative in-window:
      // drop existing in-window events first (reflects deletions), then re-add.
      byKey.removeWhere((_, e) =>
          !e.date.isBefore(timeMin) && !e.date.isAfter(timeMax));
      final fetched = await _service.fetchEvents(
        start: timeMin,
        end: timeMax,
        calendarIds: ids,
      );
      for (final ev in fetched) {
        byKey[_occKey(ev)] = ev;
      }
      _events = byKey.values.toList();
      _expandLoadedRange(timeMin, timeMax);
      _lastSyncAt = DateTime.now();
      await _db.setAppSetting(
          _kLastSyncAt, _lastSyncAt!.millisecondsSinceEpoch.toString());
      await _persistLoadedRange();
      await _cache.write(_events);
      await _rescheduleEventReminders();
      notifyListeners();
    } catch (e, st) {
      debugPrint('DeviceCalendarController.refresh failed: $e\n$st');
      _lastError = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Ensures every event in the [from, to] window is loaded. No-op if already
  /// covered; otherwise fetches the missing slice(s).
  Future<void> ensureRangeLoaded(DateTime from, DateTime to) async {
    if (!isAuthorized) return;
    final wantFrom = DateTime(from.year, from.month, 1);
    final wantTo = DateTime(to.year, to.month + 1, 1);
    if (_rangeCovers(wantFrom, wantTo)) return;

    if (_pendingRangeFetch != null) {
      try {
        await _pendingRangeFetch;
      } catch (_) {}
      if (_rangeCovers(wantFrom, wantTo)) return;
    }

    final fetch = _enqueue(() => _doRangeFetch(wantFrom, wantTo));
    _pendingRangeFetch = fetch;
    try {
      await fetch;
    } finally {
      if (identical(_pendingRangeFetch, fetch)) _pendingRangeFetch = null;
    }
  }

  Future<void>? _pendingRangeFetch;

  bool _rangeCovers(DateTime from, DateTime to) {
    final lf = _loadedFrom;
    final lt = _loadedTo;
    if (lf == null || lt == null) return false;
    return !from.isBefore(lf) && !to.isAfter(lt);
  }

  Future<void> _doRangeFetch(DateTime wantFrom, DateTime wantTo) async {
    final slices = <List<DateTime>>[];
    if (_loadedFrom == null || _loadedTo == null) {
      slices.add([wantFrom, wantTo]);
    } else {
      if (wantFrom.isBefore(_loadedFrom!)) slices.add([wantFrom, _loadedFrom!]);
      if (wantTo.isAfter(_loadedTo!)) slices.add([_loadedTo!, wantTo]);
    }
    if (slices.isEmpty) return;

    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    _setLoading(true);
    try {
      final byKey = <String, DeviceEvent>{
        for (final e in _events) _occKey(e): e,
      };
      for (final slice in slices) {
        try {
          final fetched = await _service.fetchEvents(
            start: slice[0],
            end: slice[1],
            calendarIds: ids,
          );
          for (final ev in fetched) {
            byKey[_occKey(ev)] = ev;
          }
        } catch (e) {
          debugPrint('ensureRangeLoaded failed: $e');
          _lastError = e.toString();
        }
      }
      _events = byKey.values.toList();
      _expandLoadedRange(wantFrom, wantTo);
      await _persistLoadedRange();
      await _cache.write(_events);
      await _rescheduleEventReminders();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _resetLoadedRange() {
    _loadedFrom = null;
    _loadedTo = null;
  }

  void _expandLoadedRange(DateTime from, DateTime to) {
    if (_loadedFrom == null || from.isBefore(_loadedFrom!)) _loadedFrom = from;
    if (_loadedTo == null || to.isAfter(_loadedTo!)) _loadedTo = to;
  }

  Future<void> _persistLoadedRange() async {
    await _db.setAppSetting(
        _kLoadedFrom, _loadedFrom?.millisecondsSinceEpoch.toString() ?? '');
    await _db.setAppSetting(
        _kLoadedTo, _loadedTo?.millisecondsSinceEpoch.toString() ?? '');
  }

  // ── CRUD on device events ─────────────────────────────────────────────

  Future<DeviceEvent?> createEvent(
    DeviceEventDraft draft, {
    required String calendarId,
  }) async {
    final cal = _calendars.where((c) => c.id == calendarId).firstOrNull;
    if (cal == null || !cal.canWrite) return null;
    _setLoading(true);
    try {
      final created = await _service.createEvent(draft, calendarId: calendarId);
      if (created == null) return null;
      _events = [created, ..._events];
      await _cache.write(_events);
      notifyListeners();
      return created;
    } catch (e) {
      debugPrint('DeviceCalendarController.createEvent failed: $e');
      _lastError = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<DeviceEvent?> updateEvent(DeviceEvent updated) async {
    if (updated.isReadOnly) return null;
    _setLoading(true);
    try {
      final patched = await _service.updateEvent(updated);
      if (patched == null) return null;
      // Replace the specific occurrence the user edited (matched by occurrence
      // key, not bare id — a recurring series shares one id across occurrences).
      final targetKey = _occKey(updated);
      final i = _events.indexWhere((e) => _occKey(e) == targetKey);
      if (i >= 0) {
        _events = [..._events]..[i] = patched;
      } else {
        _events = [patched, ..._events];
      }
      await _cache.write(_events);
      // Reschedule any Planom reminder if the time changed.
      final rkey = _reminderKey(patched);
      final offsets = _eventReminders[rkey];
      if (offsets != null) {
        await NotificationService.instance.scheduleRemoteEventReminders(
          key: rkey,
          title: patched.title,
          date: patched.date,
          doTime: patched.doTime,
          offsets: offsets,
        );
      }
      notifyListeners();
      return patched;
    } catch (e) {
      debugPrint('DeviceCalendarController.updateEvent failed: $e');
      _lastError = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteEvent(DeviceEvent event) async {
    if (event.isReadOnly) return false;
    _setLoading(true);
    try {
      final ok = await _service.deleteEvent(event);
      if (!ok) return false;
      final targetKey = _occKey(event);
      _events = _events.where((e) => _occKey(e) != targetKey).toList();
      await _cache.write(_events);
      final rkey = _reminderKey(event);
      if (_eventReminders.remove(rkey) != null) {
        await _persistEventReminders();
        await NotificationService.instance.cancelRemoteEventReminders(rkey);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('DeviceCalendarController.deleteEvent failed: $e');
      _lastError = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    if (_isLoading == v) return;
    _isLoading = v;
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
