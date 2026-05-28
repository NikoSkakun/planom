// Google OAuth client configuration used by [GoogleAuthService].
//
// Planom uses the installed-app OAuth 2.0 flow (authorization code + PKCE) via
// flutter_appauth. The iOS client has no client secret — the redirect back
// into the app happens over the reversed-client-ID URL scheme registered in
// ios/Runner/Info.plist. Replace the placeholders below before shipping; until
// you do, [isGoogleSignInConfigured] returns false and the Google Calendar
// settings page renders a "setup required" state instead of trying to connect.
//
// Setup steps:
//   1. Create an OAuth 2.0 Client ID in Google Cloud Console for each platform
//      you target (iOS, Android, …).
//   2. Enable the Google Calendar API for the project.
//   3. iOS: add the reversed client ID as a URL scheme in
//      ios/Runner/Info.plist (already done) — flutter_appauth uses it for the
//      OAuth redirect.

/// iOS Google OAuth 2.0 client ID. Format: `<digits>-<hash>.apps.googleusercontent.com`.
const String kGoogleIosClientId =
    '264060209270-4l2qk3d1k4ehkmtg8iikjme28590ihp3.apps.googleusercontent.com';

/// OAuth redirect URI: the reversed iOS client ID plus the conventional
/// `:/oauthredirect` path. Its scheme must match a `CFBundleURLSchemes` entry
/// in ios/Runner/Info.plist.
const String kGoogleRedirectUri =
    'com.googleusercontent.apps.264060209270-4l2qk3d1k4ehkmtg8iikjme28590ihp3:/oauthredirect';

/// Google's OAuth endpoints. Specified explicitly so we skip the discovery
/// round-trip flutter_appauth would otherwise make.
const String kGoogleAuthorizationEndpoint =
    'https://accounts.google.com/o/oauth2/v2/auth';
const String kGoogleTokenEndpoint = 'https://oauth2.googleapis.com/token';

/// Scopes for a read-write connection: create/update/delete events plus
/// listing the user's calendars.
const List<String> kGoogleCalendarReadWriteScopes = <String>[
  'https://www.googleapis.com/auth/calendar.events',
  'https://www.googleapis.com/auth/calendar.readonly',
];

/// Scopes for a read-only connection: list calendars and read events, no
/// write access. `calendar.readonly` alone covers both.
const List<String> kGoogleCalendarReadOnlyScopes = <String>[
  'https://www.googleapis.com/auth/calendar.readonly',
];

/// Scopes to request for a connection of the given mode.
List<String> googleScopesFor({required bool readOnly}) =>
    readOnly ? kGoogleCalendarReadOnlyScopes : kGoogleCalendarReadWriteScopes;

/// True when the OAuth client is wired up. Gates the settings UI.
bool get isGoogleSignInConfigured =>
    kGoogleIosClientId.isNotEmpty && kGoogleRedirectUri.isNotEmpty;
