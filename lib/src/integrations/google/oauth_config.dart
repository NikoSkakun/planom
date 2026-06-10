// Google OAuth client configuration used by [GoogleAuthService].
//
// Planom uses the installed-app OAuth 2.0 flow (authorization code + PKCE) via
// flutter_appauth. The native clients have no client secret — the redirect back
// into the app happens over the reversed-client-ID URL scheme registered in
// ios/Runner/Info.plist (iOS) / android/app/build.gradle (Android). Replace the
// placeholders below before shipping; until you do, [isGoogleSignInConfigured]
// returns false and the Google Calendar / Google Drive sync settings pages
// render a "setup required" state instead of trying to connect.
//
// Setup steps:
//   1. Create an OAuth 2.0 Client ID in Google Cloud Console for each platform
//      you target (iOS, Android, …).
//   2. Enable the Google Calendar API AND the Google Drive API for the project
//      (Drive is needed for Settings → Sync → Google Drive). Add the
//      `drive.appdata` scope to the OAuth consent screen.
//   3. iOS: add the reversed client ID as a URL scheme in
//      ios/Runner/Info.plist (already done) — flutter_appauth uses it for the
//      OAuth redirect.
//   4. Android: create an Android OAuth client (package name + signing SHA-1),
//      set [kGoogleAndroidClientId] below, and add the reversed-client-ID
//      redirect scheme to android/app/build.gradle:
//        manifestPlaceholders += [appAuthRedirectScheme:
//            'com.googleusercontent.apps.<android-client-digits-hash>']

import 'dart:io' show Platform;

/// iOS Google OAuth 2.0 client ID. Format: `<digits>-<hash>.apps.googleusercontent.com`.
const String kGoogleIosClientId =
    '264060209270-4l2qk3d1k4ehkmtg8iikjme28590ihp3.apps.googleusercontent.com';

/// Android Google OAuth 2.0 client ID. Leave empty until an Android OAuth
/// client is created in Google Cloud Console; while empty,
/// [isGoogleSignInConfigured] is false on Android and the Google features show
/// their "setup required" state.
const String kGoogleAndroidClientId = '';

/// OAuth redirect URI for the current platform: the reversed client ID plus the
/// conventional `:/oauthredirect` path. Its scheme must match a
/// `CFBundleURLSchemes` entry in ios/Runner/Info.plist (iOS) / the
/// `appAuthRedirectScheme` manifest placeholder (Android).
String get kGoogleRedirectUri {
  final reversed = _reverseClientId(kGoogleClientId);
  return '$reversed:/oauthredirect';
}

/// The OAuth client ID to use on the current platform.
String get kGoogleClientId {
  if (Platform.isAndroid) return kGoogleAndroidClientId;
  return kGoogleIosClientId; // iOS + macOS share the iOS client.
}

/// Turns `<digits>-<hash>.apps.googleusercontent.com` into its reversed form
/// `com.googleusercontent.apps.<digits>-<hash>` (the OAuth redirect scheme).
String _reverseClientId(String clientId) {
  const suffix = '.apps.googleusercontent.com';
  final core = clientId.endsWith(suffix)
      ? clientId.substring(0, clientId.length - suffix.length)
      : clientId;
  return 'com.googleusercontent.apps.$core';
}

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

/// Scope for Google Drive sync: the app-private hidden `appDataFolder`. This is
/// the narrowest Drive scope — it can only see files Planom itself created in
/// its own hidden folder, never the user's other Drive files.
const List<String> kGoogleDriveScopes = <String>[
  'https://www.googleapis.com/auth/drive.appdata',
];

/// True when the OAuth client for the current platform is wired up. Gates the
/// Google settings UI.
bool get isGoogleSignInConfigured => kGoogleClientId.isNotEmpty;
