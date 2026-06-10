import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'oauth_config.dart';

/// Result of a fresh authorization: tokens for a newly-connected account.
class GoogleAuthResult {
  GoogleAuthResult({
    required this.accessToken,
    required this.refreshToken,
    this.expiry,
    this.idToken,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiry;
  final String? idToken;
}

/// Multi-account Google OAuth via flutter_appauth (authorization code + PKCE).
///
/// Each connected account's refresh token lives in [FlutterSecureStorage]
/// keyed by the account id (its email). Access tokens are short-lived and kept
/// only in memory, refreshed on demand from the stored refresh token. Nothing
/// here is persisted to the app database, so tokens never end up in a backup.
class GoogleAuthService {
  GoogleAuthService({
    FlutterAppAuth? appAuth,
    FlutterSecureStorage? secureStorage,
  })  : _appAuth = appAuth ?? const FlutterAppAuth(),
        _secure = secureStorage ?? const FlutterSecureStorage();

  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _secure;

  static const _refreshKeyPrefix = 'gcal_refresh_';

  static const _serviceConfig = AuthorizationServiceConfiguration(
    authorizationEndpoint: kGoogleAuthorizationEndpoint,
    tokenEndpoint: kGoogleTokenEndpoint,
  );

  /// accountId -> cached access token + expiry.
  final Map<String, _CachedToken> _tokens = {};

  /// Runs the consent flow for the given [scopes]. Returns null if the user
  /// cancels. Throws on hard errors (network etc.).
  Future<GoogleAuthResult?> authorize(List<String> scopes) async {
    if (!isGoogleSignInConfigured) return null;
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          kGoogleClientId,
          kGoogleRedirectUri,
          serviceConfiguration: _serviceConfig,
          scopes: scopes,
          // Force the consent screen so Google always returns a refresh token,
          // and ask for offline access so it's a long-lived one.
          promptValues: const ['consent'],
          additionalParameters: const {'access_type': 'offline'},
        ),
      );
      final access = result.accessToken;
      if (access == null) return null;
      return GoogleAuthResult(
        accessToken: access,
        refreshToken: result.refreshToken,
        expiry: result.accessTokenExpirationDateTime,
        idToken: result.idToken,
      );
    } on FlutterAppAuthUserCancelledException {
      return null;
    } catch (e, st) {
      debugPrint('GoogleAuthService.authorize failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> storeRefreshToken(String accountId, String? token) async {
    if (token == null) return;
    await _secure.write(key: _refreshKeyPrefix + accountId, value: token);
  }

  Future<String?> _readRefreshToken(String accountId) =>
      _secure.read(key: _refreshKeyPrefix + accountId);

  /// Forgets an account's tokens (in-memory + persisted refresh token).
  Future<void> forget(String accountId) async {
    _tokens.remove(accountId);
    await _secure.delete(key: _refreshKeyPrefix + accountId);
  }

  /// Seeds the in-memory access-token cache right after [authorize] so the
  /// first API call doesn't need an immediate refresh.
  void cacheAccessToken(String accountId, String token, DateTime? expiry) {
    _tokens[accountId] = _CachedToken(token, expiry);
  }

  /// Returns a valid access token for [accountId], refreshing via the stored
  /// refresh token when the cached one is missing or near expiry. Null when no
  /// refresh token is stored or the refresh fails.
  Future<String?> accessToken(String accountId, List<String> scopes) async {
    final cached = _tokens[accountId];
    if (cached != null && !cached.isExpired) return cached.token;

    final refresh = await _readRefreshToken(accountId);
    if (refresh == null) return null;
    try {
      final result = await _appAuth.token(
        TokenRequest(
          kGoogleClientId,
          kGoogleRedirectUri,
          serviceConfiguration: _serviceConfig,
          refreshToken: refresh,
          scopes: scopes,
        ),
      );
      final access = result.accessToken;
      if (access == null) return null;
      _tokens[accountId] =
          _CachedToken(access, result.accessTokenExpirationDateTime);
      // Google occasionally rotates the refresh token.
      if (result.refreshToken != null && result.refreshToken != refresh) {
        await storeRefreshToken(accountId, result.refreshToken);
      }
      return access;
    } catch (e, st) {
      debugPrint('GoogleAuthService.accessToken($accountId) failed: $e\n$st');
      return null;
    }
  }

  /// HTTP client that attaches a fresh bearer token for [accountId] to each
  /// request. Null when the account can't produce a token.
  Future<http.Client?> clientFor(String accountId, List<String> scopes) async {
    final token = await accessToken(accountId, scopes);
    if (token == null) return null;
    return _BearerClient(token);
  }
}

class _CachedToken {
  _CachedToken(this.token, this.expiry);
  final String token;
  final DateTime? expiry;

  /// Treat tokens within a minute of expiry as expired to avoid mid-call
  /// failures.
  bool get isExpired {
    final e = expiry;
    if (e == null) return false;
    return DateTime.now().isAfter(e.subtract(const Duration(minutes: 1)));
  }
}

/// Minimal client that adds `Authorization: Bearer <token>` to every request.
class _BearerClient extends http.BaseClient {
  _BearerClient(this._token);
  final String _token;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
