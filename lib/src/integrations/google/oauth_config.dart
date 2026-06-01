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
//   4. Android: register an Android OAuth client (package name + signing SHA-1),
//      set [kGoogleAndroidClientId] below, and make sure the
//      `appAuthRedirectScheme` manifest placeholder in android/app/build.gradle
//      matches the redirect scheme. See [kGoogleAndroidClientId] /
//      [kGoogleAndroidRedirectUri] for details.

import 'dart:io' show Platform;

/// iOS Google OAuth 2.0 client ID. Format: `<digits>-<hash>.apps.googleusercontent.com`.
const String kGoogleIosClientId =
    '264060209270-4l2qk3d1k4ehkmtg8iikjme28590ihp3.apps.googleusercontent.com';

/// OAuth redirect URI: the reversed iOS client ID plus the conventional
/// `:/oauthredirect` path. Its scheme must match a `CFBundleURLSchemes` entry
/// in ios/Runner/Info.plist.
const String kGoogleRedirectUri =
    'com.googleusercontent.apps.264060209270-4l2qk3d1k4ehkmtg8iikjme28590ihp3:/oauthredirect';

/// Android Google OAuth 2.0 client ID.
///
/// Google validates Android OAuth clients by the app's application ID
/// (`com.example.planom` today — change it for a real release) plus the signing
/// certificate SHA-1 fingerprint, so you must register a dedicated **Android**
/// client in Google Cloud Console and paste its ID here. Leaving this empty
/// falls back to the iOS client, which can work for the PKCE installed-app flow
/// but is not what Google recommends for Android.
const String kGoogleAndroidClientId = '';

/// Android OAuth redirect URI.
///
/// Defaults to the iOS reversed-client-ID scheme so the redirect is captured by
/// the `appAuthRedirectScheme` manifest placeholder already wired up in
/// android/app/build.gradle. If you register a dedicated Android client whose
/// reversed-ID scheme differs, set this to `com.googleusercontent.apps.<that
/// client id>:/oauthredirect` **and** update the manifest placeholder to match
/// (schemes must be all lowercase).
const String kGoogleAndroidRedirectUri = kGoogleRedirectUri;

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

/// The OAuth client ID to use on the current platform. On Android, prefers
/// [kGoogleAndroidClientId] and falls back to the iOS client when unset.
String get googleClientId =>
    Platform.isAndroid && kGoogleAndroidClientId.isNotEmpty
        ? kGoogleAndroidClientId
        : kGoogleIosClientId;

/// The OAuth redirect URI to use on the current platform.
String get googleRedirectUri =>
    Platform.isAndroid ? kGoogleAndroidRedirectUri : kGoogleRedirectUri;

/// True when the OAuth client is wired up. Gates the settings UI.
bool get isGoogleSignInConfigured =>
    googleClientId.isNotEmpty && googleRedirectUri.isNotEmpty;
