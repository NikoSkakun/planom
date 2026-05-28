import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../database/database_service.dart';
import 'google_account.dart';
import 'google_auth_service.dart';
import 'google_calendar_api.dart';
import 'google_calendar_cache.dart';
import 'oauth_config.dart';
import 'remote_event.dart';

/// Global controller for the Google Calendar integration.
///
/// Supports any number of connected accounts, each in read-only or read-write
/// mode. Source-of-truth invariant: a Google event lives only in Google;
/// Planom keeps an in-memory view + on-disk cache and never writes remote
/// events into the local `events` table.
///
/// State persisted in the global `planom.db` `app_settings` table (all keys
/// start with `gcal_`, so [isReservedKey] excludes them from backups):
///   `gcal_accounts`            — JSON list of [GoogleAccount]
///   `gcal_selected`            — JSON list of selected calendar keys
///   `gcal_default_account`     — account id new events default to
///   `gcal_default_calendar`    — calendar id new events default to
///   `gcal_loaded_from/to`      — fetched time window (ms since epoch)
///   `gcal_synctoken_<calKey>`  — incremental-sync token per account+calendar
/// Refresh tokens live in secure storage, not the DB.
class GoogleCalendarController with ChangeNotifier {
  GoogleCalendarController({
    required DatabaseService db,
    GoogleAuthService? auth,
    GoogleCalendarCache? cache,
    GoogleCalendarApi? api,
  })  : _db = db,
        _auth = auth ?? GoogleAuthService(),
        _cache = cache ?? GoogleCalendarCache() {
    _api = api ?? GoogleCalendarApi(_auth);
  }

  final DatabaseService _db;
  final GoogleAuthService _auth;
  final GoogleCalendarCache _cache;
  late final GoogleCalendarApi _api;

  // ── Settings keys ──────────────────────────────────────────────────────
  static const _kAccounts = 'gcal_accounts';
  static const _kSelected = 'gcal_selected';
  static const _kDefaultAccount = 'gcal_default_account';
  static const _kDefaultCalendar = 'gcal_default_calendar';
  static const _kLastSyncAt = 'gcal_last_sync_at';
  static const _kLoadedFrom = 'gcal_loaded_from';
  static const _kLoadedTo = 'gcal_loaded_to';
  static const _syncTokenPrefix = 'gcal_synctoken_';

  /// Every key this controller owns is `gcal_`-prefixed; backups exclude them.
  static bool isReservedKey(String key) => key.startsWith('gcal_');

  // ── In-memory state ───────────────────────────────────────────────────

  final bool _isConfigured = isGoogleSignInConfigured;
  bool get isConfigured => _isConfigured;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  List<GoogleAccount> _accounts = const [];
  List<GoogleAccount> get accounts => List.unmodifiable(_accounts);
  bool get isConnected => _accounts.isNotEmpty;
  int get accountCount => _accounts.length;

  /// First account's email — used for the compact "Google Calendar · email"
  /// settings-row subtitle.
  String? get email => _accounts.isEmpty ? null : _accounts.first.email;

  /// accountId -> that account's calendars.
  final Map<String, List<GoogleCalendarMeta>> _calendarsByAccount = {};

  List<GoogleCalendarMeta> calendarsForAccount(String accountId) =>
      _calendarsByAccount[accountId] ?? const [];

  /// All calendars across every account, flattened.
  List<GoogleCalendarMeta> get availableCalendars =>
      _accounts.expand((a) => calendarsForAccount(a.id)).toList();

  Set<String> _selectedKeys = <String>{};
  Set<String> get selectedCalendarKeys => Set.unmodifiable(_selectedKeys);
  bool isCalendarSelected(GoogleCalendarMeta cal) =>
      _selectedKeys.contains(cal.key);

  /// Writable + selected calendars across accounts — the source list for the
  /// event-creation picker and default-calendar picker.
  List<GoogleCalendarMeta> get writableSelectedCalendars => availableCalendars
      .where((c) => c.canWrite && _selectedKeys.contains(c.key))
      .toList();

  String? _defaultAccountId;
  String? _defaultCalendarId;
  String? get defaultAccountId => _defaultAccountId;
  String? get defaultCalendarId => _defaultCalendarId;

  GoogleCalendarMeta? get defaultCalendar {
    if (_defaultAccountId == null || _defaultCalendarId == null) return null;
    for (final c in availableCalendars) {
      if (c.accountId == _defaultAccountId && c.id == _defaultCalendarId) {
        return c;
      }
    }
    return null;
  }

  DateTime? _lastSyncAt;
  DateTime? get lastSyncAt => _lastSyncAt;

  DateTime? _loadedFrom;
  DateTime? _loadedTo;
  DateTime? get loadedFrom => _loadedFrom;
  DateTime? get loadedTo => _loadedTo;

  List<RemoteEvent> _events = const [];
  List<RemoteEvent> get events => List.unmodifiable(_events);

  List<RemoteEvent> eventsForDate(DateTime date) {
    if (_accounts.isEmpty) return const [];
    return _events
        .where((e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day &&
            _selectedKeys.contains(calendarKey(e.accountId, e.calendarId)))
        .toList();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  Future<void> load() async {
    if (!_isConfigured) return;
    await _readPrefs();
    _events = await _cache.read();
    notifyListeners();
    if (_accounts.isNotEmpty) {
      // Refresh in the background — calendars + a delta since we last synced —
      // using each account's stored refresh token. The calendar paints from
      // cache meanwhile.
      unawaited(refresh());
    }
  }

  Future<void> _readPrefs() async {
    final rows = await _db.getAppSettings();
    for (final row in rows) {
      final key = row['key'] as String;
      final value = row['value'] as String?;
      if (value == null || value.isEmpty) continue;
      switch (key) {
        case _kAccounts:
          try {
            final list = (jsonDecode(value) as List<dynamic>)
                .map((e) => GoogleAccount.fromJson(e as Map<String, dynamic>))
                .toList();
            _accounts = list;
          } catch (_) {
            _accounts = const [];
          }
        case _kSelected:
          try {
            _selectedKeys =
                (jsonDecode(value) as List<dynamic>).cast<String>().toSet();
          } catch (_) {
            _selectedKeys = <String>{};
          }
        case _kDefaultAccount:
          _defaultAccountId = value;
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
      }
    }
  }

  Future<void> _persistAccounts() => _db.setAppSetting(
      _kAccounts, jsonEncode(_accounts.map((a) => a.toJson()).toList()));

  Future<void> _persistSelected() =>
      _db.setAppSetting(_kSelected, jsonEncode(_selectedKeys.toList()));

  Future<String?> _readSyncToken(String calKey) async {
    final rows = await _db.getAppSettings();
    for (final r in rows) {
      if (r['key'] == _syncTokenPrefix + calKey) {
        final v = r['value'] as String?;
        return (v == null || v.isEmpty) ? null : v;
      }
    }
    return null;
  }

  Future<void> _writeSyncToken(String calKey, String? token) async {
    if (token == null) return;
    await _db.setAppSetting(_syncTokenPrefix + calKey, token);
  }

  Future<void> _clearSyncToken(String calKey) =>
      _db.deleteAppSetting(_syncTokenPrefix + calKey);

  /// Clears every sync token for [accountId]'s calendars (used when an account
  /// is removed). A token is only valid while we hold its baseline events.
  Future<void> _clearAccountSyncTokens(String accountId) async {
    final prefix = _syncTokenPrefix + accountId; // '...gcal_synctoken_<acct>'
    final rows = await _db.getAppSettings();
    for (final r in rows) {
      final key = r['key'] as String;
      if (key.startsWith(prefix)) await _db.deleteAppSetting(key);
    }
  }

  // ── Account management ──────────────────────────────────────────────────

  /// Runs the OAuth consent flow and connects a new account in the given mode.
  /// Returns true on success, false if the user cancelled or it failed.
  Future<bool> addAccount({required bool readOnly}) async {
    if (!_isConfigured) return false;
    _setLoading(true);
    _lastError = null;
    try {
      final scopes = googleScopesFor(readOnly: readOnly);
      final auth = await _auth.authorize(scopes);
      if (auth == null) return false; // cancelled

      // We don't know the account id (email) until we call the API, so cache
      // the freshly-minted token under a temporary id, discover the primary
      // calendar, then re-key everything to the real email.
      final tempId = '__pending_${DateTime.now().microsecondsSinceEpoch}';
      _auth.cacheAccessToken(tempId, auth.accessToken, auth.expiry);
      final probe = GoogleAccount(id: tempId, email: tempId, readOnly: readOnly);
      final email = await _api.primaryCalendarId(probe);
      await _auth.forget(tempId);
      if (email == null) {
        _lastError = 'Could not read calendars for this account.';
        return false;
      }

      _auth.cacheAccessToken(email, auth.accessToken, auth.expiry);
      await _auth.storeRefreshToken(email, auth.refreshToken);

      final account = GoogleAccount(id: email, email: email, readOnly: readOnly);
      _accounts = [
        ..._accounts.where((a) => a.id != email),
        account,
      ];
      await _persistAccounts();

      // Load this account's calendars and select them all by default.
      final cals = await _api.listCalendars(account);
      _calendarsByAccount[email] = cals;
      _selectedKeys.addAll(cals.map((c) => c.key));
      await _persistSelected();

      // First writable calendar becomes the default if none is set yet.
      if (defaultCalendar == null) {
        final primary = cals.where((c) => c.primary && c.canWrite).toList();
        final pick = primary.isNotEmpty
            ? primary.first
            : cals.where((c) => c.canWrite).firstOrNull;
        if (pick != null) {
          await _setDefault(pick.accountId, pick.id);
        }
      }

      // New calendars have no events in the loaded range yet.
      _resetLoadedRange();
      await _persistLoadedRange();
      notifyListeners();
      await refresh();
      return true;
    } catch (e, st) {
      debugPrint('GoogleCalendarController.addAccount failed: $e\n$st');
      _lastError = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Disconnects a single account: forgets its token, drops its calendars,
  /// events, selection and sync tokens.
  Future<void> removeAccount(GoogleAccount account) async {
    _setLoading(true);
    try {
      await _auth.forget(account.id);
      await _clearAccountSyncTokens(account.id);
      _accounts = _accounts.where((a) => a.id != account.id).toList();
      _calendarsByAccount.remove(account.id);
      _selectedKeys
          .removeWhere((k) => k.startsWith('${account.id} '));
      _events = _events.where((e) => e.accountId != account.id).toList();
      if (_defaultAccountId == account.id) {
        _defaultAccountId = null;
        _defaultCalendarId = null;
        await _db.setAppSetting(_kDefaultAccount, '');
        await _db.setAppSetting(_kDefaultCalendar, '');
      }
      await _persistAccounts();
      await _persistSelected();
      await _cache.write(_events);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Disconnects every account.
  Future<void> disconnectAll() async {
    final all = List<GoogleAccount>.of(_accounts);
    for (final a in all) {
      await removeAccount(a);
    }
    _resetLoadedRange();
    await _persistLoadedRange();
    await _cache.clear();
  }

  // ── Calendar selection / default ────────────────────────────────────────

  Future<void> setCalendarSelected(GoogleCalendarMeta cal, bool selected) async {
    final key = cal.key;
    if (selected) {
      if (!_selectedKeys.add(key)) return;
      // A newly-selected calendar has no events loaded; reset the window so the
      // next refresh + scroll prefetches re-fetch it everywhere.
      _resetLoadedRange();
      await _persistLoadedRange();
    } else {
      if (!_selectedKeys.remove(key)) return;
      _events = _events
          .where((e) =>
              calendarKey(e.accountId, e.calendarId) != key)
          .toList();
      // Stale baseline ⇒ stale token. Clear it so re-selecting does a full
      // fetch instead of an empty incremental sync.
      await _clearSyncToken(key);
      if (_defaultAccountId == cal.accountId &&
          _defaultCalendarId == cal.id) {
        _defaultAccountId = null;
        _defaultCalendarId = null;
        await _db.setAppSetting(_kDefaultAccount, '');
        await _db.setAppSetting(_kDefaultCalendar, '');
      }
      await _cache.write(_events);
    }
    await _persistSelected();
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> setDefaultCalendar(GoogleCalendarMeta cal) =>
      _setDefault(cal.accountId, cal.id);

  Future<void> clearDefaultCalendar() async {
    _defaultAccountId = null;
    _defaultCalendarId = null;
    await _db.setAppSetting(_kDefaultAccount, '');
    await _db.setAppSetting(_kDefaultCalendar, '');
    notifyListeners();
  }

  Future<void> _setDefault(String accountId, String calendarId) async {
    _defaultAccountId = accountId;
    _defaultCalendarId = calendarId;
    await _db.setAppSetting(_kDefaultAccount, accountId);
    await _db.setAppSetting(_kDefaultCalendar, calendarId);
    notifyListeners();
  }

  // ── Refresh ───────────────────────────────────────────────────────────

  static const _defaultPastDays = 365;
  static const _defaultFutureDays = 365;

  /// Serializes every fetch (full refresh + range loads) so they never
  /// interleave and race to overwrite `_events`.
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

  /// Fetches each account's calendars (if not already loaded) so we can map
  /// selected keys back to calendar metadata.
  Future<void> _ensureCalendarsLoaded() async {
    for (final account in _accounts) {
      if (_calendarsByAccount.containsKey(account.id)) continue;
      try {
        _calendarsByAccount[account.id] =
            await _api.listCalendars(account);
      } catch (e) {
        debugPrint('listCalendars(${account.id}) failed: $e');
      }
    }
  }

  Future<void> refreshCalendars() async {
    if (_accounts.isEmpty) return;
    for (final account in _accounts) {
      try {
        _calendarsByAccount[account.id] = await _api.listCalendars(account);
      } catch (e) {
        debugPrint('refreshCalendars(${account.id}) failed: $e');
        _lastError = e.toString();
      }
    }
    notifyListeners();
  }

  String _eventKey(RemoteEvent e) =>
      '${e.accountId} ${e.calendarId} ${e.googleEventId}';

  Future<void> _refreshLocked({DateTime? from, DateTime? to}) async {
    if (_accounts.isEmpty) return;
    _setLoading(true);
    _lastError = null;
    try {
      await _ensureCalendarsLoaded();
      final now = DateTime.now();
      final timeMin =
          from ?? now.subtract(const Duration(days: _defaultPastDays));
      final timeMax = to ?? now.add(const Duration(days: _defaultFutureDays));

      // Seed from existing events so ranges fetched via ensureRangeLoaded
      // (outside the window) survive the refresh.
      final byId = <String, RemoteEvent>{
        for (final e in _events) _eventKey(e): e,
      };

      for (final account in _accounts) {
        for (final cal in calendarsForAccount(account.id)) {
          if (!_selectedKeys.contains(cal.key)) continue;
          final token = await _readSyncToken(cal.key);
          var result = await _api.listEvents(
            account: account,
            calendar: cal,
            timeMin: timeMin,
            timeMax: timeMax,
            syncToken: token,
          );
          var fullFetch = token == null;
          if (result.tokenInvalid) {
            result = await _api.listEvents(
              account: account,
              calendar: cal,
              timeMin: timeMin,
              timeMax: timeMax,
            );
            fullFetch = true;
          }
          if (fullFetch) {
            // Authoritative for [timeMin, timeMax]: drop this calendar's
            // existing in-window events (reflects deletions), keep the rest.
            byId.removeWhere((_, e) =>
                e.accountId == account.id &&
                e.calendarId == cal.id &&
                !e.date.isBefore(timeMin) &&
                !e.date.isAfter(timeMax));
          } else {
            for (final deletedId in result.deletedEventIds) {
              byId.remove('${account.id} ${cal.id} $deletedId');
            }
          }
          for (final ev in result.events) {
            byId[_eventKey(ev)] = ev;
          }
          await _writeSyncToken(cal.key, result.nextSyncToken);
        }
      }

      _events = byId.values.toList();
      _expandLoadedRange(timeMin, timeMax);
      _lastSyncAt = DateTime.now();
      await _db.setAppSetting(
          _kLastSyncAt, _lastSyncAt!.millisecondsSinceEpoch.toString());
      await _persistLoadedRange();
      await _cache.write(_events);
      notifyListeners();
    } catch (e, st) {
      debugPrint('GoogleCalendarController.refresh failed: $e\n$st');
      _lastError = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Ensures every event in the [from, to] window is loaded. No-op if already
  /// covered; otherwise fetches the missing slice(s) for each selected
  /// calendar on every account.
  Future<void> ensureRangeLoaded(DateTime from, DateTime to) async {
    if (_accounts.isEmpty) return;
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

    _setLoading(true);
    try {
      await _ensureCalendarsLoaded();
      final byId = <String, RemoteEvent>{
        for (final e in _events) _eventKey(e): e,
      };
      for (final account in _accounts) {
        for (final cal in calendarsForAccount(account.id)) {
          if (!_selectedKeys.contains(cal.key)) continue;
          for (final slice in slices) {
            try {
              // No sync token: one-shot expansion fetch.
              final result = await _api.listEvents(
                account: account,
                calendar: cal,
                timeMin: slice[0],
                timeMax: slice[1],
              );
              for (final ev in result.events) {
                byId[_eventKey(ev)] = ev;
              }
            } catch (e) {
              debugPrint('ensureRangeLoaded ${cal.key} failed: $e');
              _lastError = e.toString();
            }
          }
        }
      }
      _events = byId.values.toList();
      _expandLoadedRange(wantFrom, wantTo);
      await _persistLoadedRange();
      await _cache.write(_events);
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

  // ── CRUD on remote events ─────────────────────────────────────────────

  /// Creates an event in the given account+calendar. Returns the new event or
  /// null on failure.
  Future<RemoteEvent?> createEvent(
    RemoteEventDraft draft, {
    required String accountId,
    required String calendarId,
  }) async {
    final account = _accountById(accountId);
    if (account == null) return null;
    final cal = calendarsForAccount(accountId)
        .where((c) => c.id == calendarId)
        .firstOrNull;
    if (cal == null || !cal.canWrite) return null;
    _setLoading(true);
    try {
      final created = await _api.insertEvent(
          account: account, calendar: cal, draft: draft);
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
    if (updated.isReadOnly) return null;
    final account = _accountById(updated.accountId);
    if (account == null) return null;
    _setLoading(true);
    try {
      final patched = await _api.patchEvent(account, updated);
      if (patched == null) return null;
      final key = _eventKey(updated);
      final i = _events.indexWhere((e) => _eventKey(e) == key);
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
    if (event.isReadOnly) return false;
    final account = _accountById(event.accountId);
    if (account == null) return false;
    _setLoading(true);
    try {
      await _api.deleteEvent(account, event);
      final key = _eventKey(event);
      _events = _events.where((e) => _eventKey(e) != key).toList();
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

  GoogleAccount? _accountById(String id) =>
      _accounts.where((a) => a.id == id).firstOrNull;

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
