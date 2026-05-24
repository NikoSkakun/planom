import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../database/database_service.dart';
import 'google_auth_service.dart';
import 'google_calendar_api.dart';
import 'google_calendar_cache.dart';
import 'oauth_config.dart';
import 'remote_event.dart';

/// Global controller for the Google Calendar integration.
///
/// Source-of-truth invariant: a Google event lives only in Google; Planom
/// keeps an in-memory view + on-disk cache. The controller never writes
/// remote events into the local `events` table.
///
/// State persisted in the global `planom.db` `app_settings` table:
///   `gcal_email`                 — last signed-in account
///   `gcal_selected_calendar_ids` — JSON list<string>
///   `gcal_default_calendar_id`   — where new events default to
///   `gcal_last_sync_at`          — ms since epoch
///   `gcal_synctoken_<id>`        — incremental-sync token per calendar
class GoogleCalendarController with ChangeNotifier {
  GoogleCalendarController({
    required DatabaseService db,
    GoogleAuthService? auth,
    GoogleCalendarCache? cache,
  })  : _db = db,
        _auth = auth ?? GoogleAuthService(),
        _cache = cache ?? GoogleCalendarCache() {
    _api = GoogleCalendarApi(_auth);
  }

  final DatabaseService _db;
  final GoogleAuthService _auth;
  final GoogleCalendarCache _cache;
  late final GoogleCalendarApi _api;

  // ── Settings keys ──────────────────────────────────────────────────────
  static const _kEmail = 'gcal_email';
  static const _kSelected = 'gcal_selected_calendar_ids';
  static const _kDefault = 'gcal_default_calendar_id';
  static const _kLastSyncAt = 'gcal_last_sync_at';
  static const _syncTokenPrefix = 'gcal_synctoken_';

  /// The complete set of `app_settings` keys this controller owns. Used by
  /// [BackupService] to exclude them from exports / imports.
  static Set<String> reservedAppSettingKeys(Iterable<String> calendarIds) => {
        _kEmail,
        _kSelected,
        _kDefault,
        _kLastSyncAt,
        for (final id in calendarIds) _syncTokenPrefix + id,
      };

  /// Conservative prefix check used when we don't know the calendar id list
  /// (e.g. excluding rows from a foreign backup payload).
  static bool isReservedKey(String key) =>
      key == _kEmail ||
      key == _kSelected ||
      key == _kDefault ||
      key == _kLastSyncAt ||
      key.startsWith(_syncTokenPrefix);

  // ── In-memory state ───────────────────────────────────────────────────

  final bool _isConfigured = isGoogleSignInConfigured;
  bool get isConfigured => _isConfigured;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  String? _email;
  String? get email => _email;
  bool get isConnected => _email != null && _auth.isSignedIn;

  List<GoogleCalendarMeta> _availableCalendars = const [];
  List<GoogleCalendarMeta> get availableCalendars => _availableCalendars;

  Set<String> _selectedCalendarIds = const {};
  Set<String> get selectedCalendarIds => _selectedCalendarIds;

  String? _defaultCalendarId;
  String? get defaultCalendarId => _defaultCalendarId;

  /// Writable calendars (UI uses this for the "create new event in…" picker).
  List<GoogleCalendarMeta> get writableCalendars =>
      _availableCalendars.where((c) => c.canWrite).toList();

  /// Selected + writable, used as the source list for the default-calendar
  /// dropdown.
  List<GoogleCalendarMeta> get writableSelectedCalendars =>
      _availableCalendars
          .where((c) => c.canWrite && _selectedCalendarIds.contains(c.id))
          .toList();

  DateTime? _lastSyncAt;
  DateTime? get lastSyncAt => _lastSyncAt;

  /// All remote events currently held in memory, across every selected
  /// calendar. The day-cell / day-sheet lookups filter from this.
  List<RemoteEvent> _events = const [];
  List<RemoteEvent> get events => List.unmodifiable(_events);

  List<RemoteEvent> eventsForDate(DateTime date) {
    if (!isConnected) return const [];
    return _events
        .where((e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day &&
            _selectedCalendarIds.contains(e.calendarId))
        .toList();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Restores connection state from the DB + secure storage, hydrates the
  /// event cache, then triggers a background refresh. Safe no-op when the
  /// integration is unconfigured.
  Future<void> load() async {
    if (!_isConfigured) return;
    await _readPrefs();
    _events = await _cache.read();
    notifyListeners();

    if (await _auth.trySilentSignIn()) {
      _email = _auth.email;
      notifyListeners();
      // Don't await — let the calendar paint cached state while we refresh.
      unawaited(refresh());
    }
  }

  Future<void> _readPrefs() async {
    final rows = await _db.getAppSettings();
    for (final row in rows) {
      final key = row['key'] as String;
      final value = row['value'] as String?;
      if (value == null) continue;
      switch (key) {
        case _kEmail:
          _email = value;
        case _kSelected:
          try {
            final list = (jsonDecode(value) as List<dynamic>).cast<String>();
            _selectedCalendarIds = list.toSet();
          } catch (_) {
            _selectedCalendarIds = const {};
          }
        case _kDefault:
          _defaultCalendarId = value;
        case _kLastSyncAt:
          final ms = int.tryParse(value);
          if (ms != null) _lastSyncAt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
  }

  Future<String?> _readSyncToken(String calendarId) async {
    final rows = await _db.getAppSettings();
    for (final r in rows) {
      if (r['key'] == _syncTokenPrefix + calendarId) {
        return r['value'] as String?;
      }
    }
    return null;
  }

  Future<void> _writeSyncToken(String calendarId, String? token) async {
    if (token == null) return;
    await _db.setAppSetting(_syncTokenPrefix + calendarId, token);
  }

  // ── Auth ──────────────────────────────────────────────────────────────

  Future<bool> connect() async {
    if (!_isConfigured) return false;
    _setLoading(true);
    _lastError = null;
    try {
      final ok = await _auth.signIn();
      if (!ok) return false;
      _email = _auth.email;
      if (_email != null) {
        await _db.setAppSetting(_kEmail, _email!);
      }
      await refreshCalendars();
      // First-time setup: select every calendar by default so the user sees
      // something immediately, with the primary as default.
      if (_selectedCalendarIds.isEmpty) {
        final defaults = _availableCalendars.map((c) => c.id).toSet();
        await setSelectedCalendars(defaults);
      }
      if (_defaultCalendarId == null) {
        final primary =
            _availableCalendars.where((c) => c.primary && c.canWrite).toList();
        if (primary.isNotEmpty) {
          await setDefaultCalendar(primary.first.id);
        } else {
          final writable = writableCalendars;
          if (writable.isNotEmpty) {
            await setDefaultCalendar(writable.first.id);
          }
        }
      }
      await refresh();
      return true;
    } catch (e, st) {
      debugPrint('GoogleCalendarController.connect failed: $e\n$st');
      _lastError = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> disconnect() async {
    _setLoading(true);
    try {
      await _auth.signOut();
      _email = null;
      _availableCalendars = const [];
      _events = const [];
      _selectedCalendarIds = const {};
      _defaultCalendarId = null;
      _lastSyncAt = null;
      await _db.setAppSetting(_kEmail, '');
      await _db.setAppSetting(_kSelected, '[]');
      await _db.setAppSetting(_kDefault, '');
      await _db.setAppSetting(_kLastSyncAt, '');
      await _cache.clear();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ── Calendar selection ────────────────────────────────────────────────

  Future<void> refreshCalendars() async {
    if (!isConnected) return;
    try {
      _availableCalendars = await _api.listCalendars();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshCalendars failed: $e');
      _lastError = e.toString();
    }
  }

  Future<void> setSelectedCalendars(Set<String> ids) async {
    _selectedCalendarIds = ids;
    await _db.setAppSetting(_kSelected, jsonEncode(ids.toList()));
    // Drop cached events for newly-deselected calendars so the UI updates
    // immediately without waiting for the next refresh.
    _events = _events.where((e) => ids.contains(e.calendarId)).toList();
    await _cache.write(_events);
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> setDefaultCalendar(String calendarId) async {
    _defaultCalendarId = calendarId;
    await _db.setAppSetting(_kDefault, calendarId);
    notifyListeners();
  }

  // ── Refresh ───────────────────────────────────────────────────────────

  /// Default refresh window: 6 months back, 18 months forward. Calendar
  /// view scrolls outside this only for distant history; users in that
  /// region can pull-to-refresh which expands the window on demand.
  static const _defaultPastDays = 6 * 30;
  static const _defaultFutureDays = 18 * 30;

  Future<void> refresh({DateTime? from, DateTime? to}) async {
    if (!isConnected) return;
    _setLoading(true);
    _lastError = null;
    try {
      if (_availableCalendars.isEmpty) {
        await refreshCalendars();
      }
      final now = DateTime.now();
      final timeMin =
          from ?? now.subtract(const Duration(days: _defaultPastDays));
      final timeMax =
          to ?? now.add(const Duration(days: _defaultFutureDays));

      final keepIds = _selectedCalendarIds;
      // Events from non-selected calendars get dropped here.
      final next = <RemoteEvent>[];
      for (final cal in _availableCalendars) {
        if (!keepIds.contains(cal.id)) continue;
        final token = await _readSyncToken(cal.id);
        var result = await _api.listEvents(
          calendar: cal,
          timeMin: timeMin,
          timeMax: timeMax,
          syncToken: token,
        );
        if (result.tokenInvalid) {
          // Stored token expired: full re-fetch in the window.
          result = await _api.listEvents(
            calendar: cal,
            timeMin: timeMin,
            timeMax: timeMax,
          );
        }
        if (token != null && !result.tokenInvalid) {
          // Incremental: merge deltas with existing events for this calendar.
          final keep = _events.where((e) => e.calendarId != cal.id).toList();
          final byId = <String, RemoteEvent>{
            for (final e in _events.where((e) => e.calendarId == cal.id))
              e.googleEventId: e,
          };
          for (final delta in result.events) {
            byId[delta.googleEventId] = delta;
          }
          next.addAll(keep.where((e) => e.calendarId == cal.id));
          next.addAll(byId.values);
        } else {
          next.addAll(result.events);
        }
        await _writeSyncToken(cal.id, result.nextSyncToken);
      }

      _events = next;
      _lastSyncAt = DateTime.now();
      await _db.setAppSetting(
        _kLastSyncAt,
        _lastSyncAt!.millisecondsSinceEpoch.toString(),
      );
      await _cache.write(_events);
      notifyListeners();
    } catch (e, st) {
      debugPrint('GoogleCalendarController.refresh failed: $e\n$st');
      _lastError = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── CRUD on remote events ─────────────────────────────────────────────

  /// Creates an event in [calendarId]. Returns the new [RemoteEvent] or null
  /// on failure.
  Future<RemoteEvent?> createEvent(
    RemoteEventDraft draft, {
    required String calendarId,
  }) async {
    if (!isConnected) return null;
    final cal =
        _availableCalendars.where((c) => c.id == calendarId).firstOrNull;
    if (cal == null) return null;
    if (!cal.canWrite) return null;
    _setLoading(true);
    try {
      final created = await _api.insertEvent(calendar: cal, draft: draft);
      if (created == null) return null;
      _events = [created, ..._events];
      await _cache.write(_events);
      notifyListeners();
      return created;
    } catch (e) {
      debugPrint('createEvent failed: $e');
      _lastError = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<RemoteEvent?> updateEvent(RemoteEvent updated) async {
    if (!isConnected || updated.isReadOnly) return null;
    _setLoading(true);
    try {
      final patched = await _api.patchEvent(updated);
      if (patched == null) return null;
      final i = _events
          .indexWhere((e) => e.googleEventId == updated.googleEventId);
      if (i >= 0) {
        _events = [..._events]..[i] = patched;
      } else {
        _events = [patched, ..._events];
      }
      await _cache.write(_events);
      notifyListeners();
      return patched;
    } catch (e) {
      debugPrint('updateEvent failed: $e');
      _lastError = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteEvent(RemoteEvent event) async {
    if (!isConnected || event.isReadOnly) return false;
    _setLoading(true);
    try {
      await _api.deleteEvent(event);
      _events = _events
          .where((e) => e.googleEventId != event.googleEventId)
          .toList();
      await _cache.write(_events);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('deleteEvent failed: $e');
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
