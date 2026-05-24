import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'oauth_config.dart';

/// Wraps `google_sign_in` so the rest of the app can ask "is the user signed
/// in?" / "give me an authenticated HTTP client" without depending on the
/// plugin directly.
///
/// The plugin handles native consent UI on iOS / Android / macOS, persists
/// the refresh-token bookkeeping in the platform's secure storage, and
/// silently restores the previous session when the app launches.
class GoogleAuthService {
  GoogleAuthService()
      : _signIn = GoogleSignIn(
          scopes: kGoogleCalendarScopes,
          clientId: kGoogleIosClientId.isEmpty ? null : kGoogleIosClientId,
          serverClientId:
              kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
        );

  final GoogleSignIn _signIn;

  GoogleSignInAccount? _account;

  GoogleSignInAccount? get account => _account;
  bool get isSignedIn => _account != null;
  String? get email => _account?.email;

  /// Restores the previous session (no UI) if one exists. Safe to call before
  /// the user has ever signed in.
  Future<bool> trySilentSignIn() async {
    if (!isGoogleSignInConfigured) return false;
    try {
      _account = await _signIn.signInSilently();
      return _account != null;
    } catch (e, st) {
      debugPrint('GoogleAuthService.silent failed: $e\n$st');
      return false;
    }
  }

  /// Pops the native sign-in sheet. Returns true on success, false when the
  /// user cancels or the flow errors out.
  Future<bool> signIn() async {
    if (!isGoogleSignInConfigured) return false;
    try {
      _account = await _signIn.signIn();
      return _account != null;
    } catch (e, st) {
      debugPrint('GoogleAuthService.signIn failed: $e\n$st');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _signIn.disconnect();
    } catch (_) {
      // disconnect() can throw if there's no active session — fall through.
    }
    try {
      await _signIn.signOut();
    } catch (_) {}
    _account = null;
  }

  /// HTTP client that automatically attaches a fresh access token to every
  /// request. Returned client must be closed by the caller — we use a
  /// short-lived one per controller call.
  Future<http.Client?> authClient() async {
    final acct = _account;
    if (acct == null) return null;
    return _signIn.authenticatedClient();
  }
}
