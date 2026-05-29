import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import 'google_account.dart';
import 'google_auth_service.dart';
import 'oauth_config.dart';
import 'remote_event.dart';

/// Result of a single calendar's event-list call. Carries the next-sync-token
/// so the controller can do incremental fetches on subsequent refreshes.
class CalendarListResult {
  CalendarListResult({
    required this.events,
    required this.nextSyncToken,
    required this.tokenInvalid,
    this.deletedEventIds = const {},
  });

  final List<RemoteEvent> events;
  final String? nextSyncToken;

  /// True when the API returned 410 Gone because the persisted sync token
  /// expired. The caller should retry with no token (full re-fetch).
  final bool tokenInvalid;

  /// Ids of events Google reported as `cancelled` during an incremental sync
  /// (deletion tombstones). The controller drops these from its cache so an
  /// event deleted elsewhere doesn't linger in Planom.
  final Set<String> deletedEventIds;
}

/// Thin wrapper over [gcal.CalendarApi]. Each call builds a client for the
/// relevant [GoogleAccount] via [GoogleAuthService] (a fresh authenticated
/// HTTP client, since tokens are per-account and short-lived).
class GoogleCalendarApi {
  GoogleCalendarApi(this._auth);

  final GoogleAuthService _auth;

  List<String> _scopes(GoogleAccount account) =>
      googleScopesFor(readOnly: account.readOnly);

  Future<gcal.CalendarApi?> _apiFor(GoogleAccount account) async {
    final client = await _auth.clientFor(account.id, _scopes(account));
    if (client == null) return null;
    return gcal.CalendarApi(client);
  }

  // ── Calendars ──────────────────────────────────────────────────────────

  /// Lists the account's calendars. Each is tagged with the account id and
  /// whether the account is read-only.
  Future<List<GoogleCalendarMeta>> listCalendars(GoogleAccount account) async {
    final api = await _apiFor(account);
    if (api == null) return const [];
    final list = await api.calendarList.list();
    final items = list.items ?? const [];
    return items
        .map((c) => GoogleCalendarMeta(
              accountId: account.id,
              id: c.id ?? '',
              summary: c.summaryOverride ?? c.summary ?? c.id ?? '',
              color: _parseHexColor(c.backgroundColor) ?? 0xFF0A84FF,
              accessRole: c.accessRole ?? 'reader',
              primary: c.primary ?? false,
              accountReadOnly: account.readOnly,
            ))
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  /// Returns the account's primary calendar id (its email address), used as
  /// the stable account identity. Null if it can't be determined.
  Future<String?> primaryCalendarId(GoogleAccount account) async {
    final cals = await listCalendars(account);
    for (final c in cals) {
      if (c.primary) return c.id;
    }
    return cals.isNotEmpty ? cals.first.id : null;
  }

  // ── Events ─────────────────────────────────────────────────────────────

  /// Pulls events for a single calendar in the [timeMin, timeMax] window.
  /// When [syncToken] is supplied, runs an incremental sync (Google returns
  /// only the deltas since the previous sync); on 410 Gone, the caller
  /// should retry without a token.
  Future<CalendarListResult> listEvents({
    required GoogleAccount account,
    required GoogleCalendarMeta calendar,
    DateTime? timeMin,
    DateTime? timeMax,
    String? syncToken,
  }) async {
    final api = await _apiFor(account);
    if (api == null) {
      return CalendarListResult(
        events: const [],
        nextSyncToken: null,
        tokenInvalid: false,
      );
    }

    final events = <RemoteEvent>[];
    final deletedEventIds = <String>{};
    String? pageToken;
    String? newSyncToken;
    bool tokenInvalid = false;

    do {
      try {
        final page = await api.events.list(
          calendar.id,
          // syncToken can't be combined with timeMin/timeMax/orderBy.
          timeMin: syncToken == null ? timeMin?.toUtc() : null,
          timeMax: syncToken == null ? timeMax?.toUtc() : null,
          singleEvents: true,
          maxResults: 250,
          pageToken: pageToken,
          syncToken: syncToken,
        );
        for (final ge in page.items ?? const <gcal.Event>[]) {
          // Incremental sync returns cancelled events as tombstones; record
          // their ids so the controller can evict the stale copy.
          if (ge.status == 'cancelled') {
            if (ge.id != null) deletedEventIds.add(ge.id!);
            continue;
          }
          final re = RemoteEvent.fromGoogle(
            ge,
            accountId: account.id,
            calendarId: calendar.id,
            calendarName: calendar.summary,
            calendarColor: calendar.color,
            isReadOnly: !calendar.canWrite,
          );
          if (re != null) events.add(re);
        }
        pageToken = page.nextPageToken;
        if (page.nextSyncToken != null) newSyncToken = page.nextSyncToken;
      } on gcal.DetailedApiRequestError catch (e) {
        if (e.status == 410) {
          tokenInvalid = true;
          break;
        }
        debugPrint('GoogleCalendarApi.list failed: $e');
        rethrow;
      }
    } while (pageToken != null);

    return CalendarListResult(
      events: events,
      nextSyncToken: newSyncToken,
      tokenInvalid: tokenInvalid,
      deletedEventIds: deletedEventIds,
    );
  }

  Future<RemoteEvent?> insertEvent({
    required GoogleAccount account,
    required GoogleCalendarMeta calendar,
    required RemoteEventDraft draft,
  }) async {
    final api = await _apiFor(account);
    if (api == null) return null;
    final created = await api.events.insert(draft.toGoogle(), calendar.id);
    return RemoteEvent.fromGoogle(
      created,
      accountId: account.id,
      calendarId: calendar.id,
      calendarName: calendar.summary,
      calendarColor: calendar.color,
      isReadOnly: !calendar.canWrite,
    );
  }

  Future<RemoteEvent?> patchEvent(
      GoogleAccount account, RemoteEvent updated) async {
    final api = await _apiFor(account);
    if (api == null) return null;
    final patched = await api.events.patch(
      updated.toGoogle(),
      updated.calendarId,
      updated.googleEventId,
    );
    return RemoteEvent.fromGoogle(
      patched,
      accountId: account.id,
      calendarId: updated.calendarId,
      calendarName: updated.calendarName,
      calendarColor: updated.calendarColor,
      isReadOnly: updated.isReadOnly,
    );
  }

  Future<void> deleteEvent(GoogleAccount account, RemoteEvent event) async {
    final api = await _apiFor(account);
    if (api == null) return;
    await api.events.delete(event.calendarId, event.googleEventId);
  }

  // ── helpers ────────────────────────────────────────────────────────────

  int? _parseHexColor(String? hex) {
    if (hex == null) return null;
    final s = hex.replaceFirst('#', '');
    if (s.length != 6) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return 0xFF000000 | v;
  }
}
