// Google OAuth client identifiers used by [GoogleAuthService].
//
// These are deliberately compile-time constants so they ship inside the app
// bundle — Google's installed-app OAuth flow accepts this (the so-called
// client secret is not really a secret). Replace the placeholders below
// before shipping; until you do, [isGoogleSignInConfigured] returns false
// and the Google Calendar settings page renders a "setup required" state
// instead of attempting to sign in.
//
// Setup steps:
//   1. Create an OAuth 2.0 Client ID in Google Cloud Console for each
//      platform you target (iOS, Android, Web, macOS).
//   2. Enable the Google Calendar API for the project.
//   3. iOS only: add the reversed client ID as a URL scheme in
//      `ios/Runner/Info.plist` and a `GIDClientID` entry (see the comments
//      in that file).
//   4. Android only: register the SHA-1 fingerprint of your signing key
//      with the Android OAuth client.

/// iOS Google OAuth 2.0 client ID. Format: `<digits>-<hash>.apps.googleusercontent.com`.
const String kGoogleIosClientId =
    '264060209270-4l2qk3d1k4ehkmtg8iikjme28590ihp3.apps.googleusercontent.com';

/// Android Google OAuth 2.0 client ID. The `google_sign_in` plugin discovers
/// this automatically from the SHA-1 fingerprint you register, so leaving
/// this empty is fine on Android.
const String kGoogleAndroidClientId = '';

/// Web Google OAuth 2.0 client ID. Used for the optional `serverClientId`
/// argument so the API returns an ID token that can be verified server-side.
const String kGoogleServerClientId = '';

/// Calendar scopes requested at sign-in.
///   `calendar.events`         — read/write events on calendars the user owns
///   `calendar.readonly`       — list the user's calendars (for the picker)
const List<String> kGoogleCalendarScopes = <String>[
  'https://www.googleapis.com/auth/calendar.events',
  'https://www.googleapis.com/auth/calendar.readonly',
];

/// True when at least one platform's client ID is wired up. The auth service
/// uses platform-specific config, but for the settings UI we just need a
/// quick "is this turned on at all?" gate.
bool get isGoogleSignInConfigured =>
    kGoogleIosClientId.isNotEmpty ||
    kGoogleAndroidClientId.isNotEmpty ||
    kGoogleServerClientId.isNotEmpty;
