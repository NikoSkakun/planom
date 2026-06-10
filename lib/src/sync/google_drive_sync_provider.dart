import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;

import '../integrations/google/google_auth_service.dart';
import '../integrations/google/oauth_config.dart';
import 'sync_provider.dart';
import 'sync_state.dart';

/// Google Drive sync. Stores a single E2E-encrypted backup file in the app's
/// private, hidden `appDataFolder` — a per-app sandbox the user never sees in
/// their Drive and other apps can't read. The `drive.appdata` scope can only
/// touch files Planom itself created there, never the user's other files.
///
/// Independent from the Google Calendar connection: it runs its own OAuth
/// consent (Drive scope only) under a dedicated account id, so a user can sync
/// without ever connecting Calendar. The refresh token lives in
/// [FlutterSecureStorage] via [GoogleAuthService]; the connected email is kept
/// under [_kEmailKey] so connection state is global (survives space switches)
/// and is the source of truth for [isConfigured].
///
/// REQUIRES (one-time, in Google Cloud Console — see oauth_config.dart):
///   1. Enable the Google Drive API for the project.
///   2. Add the `drive.appdata` scope to the OAuth consent screen.
///   3. iOS: existing client ID + reversed URL scheme already cover this.
///   4. Android: create an Android OAuth client and wire the redirect scheme.
class GoogleDriveSyncProvider extends SyncProvider {
  GoogleDriveSyncProvider({
    GoogleAuthService? auth,
    FlutterSecureStorage? secureStorage,
  })  : _auth = auth ?? GoogleAuthService(),
        _secure = secureStorage ?? const FlutterSecureStorage();

  final GoogleAuthService _auth;
  final FlutterSecureStorage _secure;

  /// Fixed account id for the sync connection — only ever one at a time, so we
  /// don't need to key it by email like the multi-account Calendar flow does.
  static const _accountId = 'drive_sync';
  static const _kEmailKey = 'planom_drive_sync_email';
  static const _remoteFileName = 'planom.sync.enc';
  static const _appDataFolder = 'appDataFolder';

  @override
  SyncBackend get backend => SyncBackend.googleDrive;

  @override
  Future<bool> isAvailable() async {
    if (!isGoogleSignInConfigured) return false;
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  @override
  Future<bool> isConfigured() async {
    if (!await isAvailable()) return false;
    final email = await _secure.read(key: _kEmailKey);
    return email != null;
  }

  @override
  Future<bool> connect() async {
    if (!isGoogleSignInConfigured) {
      throw SyncException('Google sign-in is not set up on this build.');
    }
    final result = await _auth.authorize(kGoogleDriveScopes);
    if (result == null) return false; // user cancelled
    await _auth.storeRefreshToken(_accountId, result.refreshToken);
    _auth.cacheAccessToken(_accountId, result.accessToken, result.expiry);

    // Best-effort: discover the account email for the "Connected as …" row.
    String? email;
    try {
      final api = await _driveApi();
      final about = await api.about.get($fields: 'user/emailAddress');
      email = about.user?.emailAddress;
    } catch (_) {/* non-fatal — fall back to a generic label */}
    await _secure.write(key: _kEmailKey, value: email ?? 'Google Drive');
    return true;
  }

  @override
  Future<void> disconnect() async {
    await _auth.forget(_accountId);
    await _secure.delete(key: _kEmailKey);
  }

  @override
  Future<String?> connectedAccount() => _secure.read(key: _kEmailKey);

  @override
  Future<void> push(List<int> encryptedPayload) async {
    final api = await _driveApi();
    try {
      final existingId = await _findFileId(api);
      final media = gdrive.Media(
        Stream<List<int>>.value(encryptedPayload),
        encryptedPayload.length,
      );
      if (existingId == null) {
        final meta = gdrive.File()
          ..name = _remoteFileName
          ..parents = <String>[_appDataFolder];
        await api.files.create(meta, uploadMedia: media);
      } else {
        await api.files.update(gdrive.File(), existingId, uploadMedia: media);
      }
    } on gdrive.DetailedApiRequestError catch (e) {
      throw SyncException(_friendlyError('upload', e));
    } on SocketException {
      throw SyncException('No internet connection.');
    }
  }

  @override
  Future<List<int>?> pull() async {
    final api = await _driveApi();
    try {
      final id = await _findFileId(api);
      if (id == null) return null;
      final media = await api.files.get(
        id,
        downloadOptions: gdrive.DownloadOptions.fullMedia,
      ) as gdrive.Media;
      final out = <int>[];
      await for (final chunk in media.stream) {
        out.addAll(chunk);
      }
      return out;
    } on gdrive.DetailedApiRequestError catch (e) {
      throw SyncException(_friendlyError('download', e));
    } on SocketException {
      throw SyncException('No internet connection.');
    }
  }

  @override
  Future<DateTime?> lastRemoteUpdate() async {
    final api = await _driveApi();
    try {
      final list = await api.files.list(
        spaces: _appDataFolder,
        q: "name = '$_remoteFileName'",
        $fields: 'files(id,modifiedTime)',
      );
      final files = list.files;
      if (files == null || files.isEmpty) return null;
      return files.first.modifiedTime;
    } on gdrive.DetailedApiRequestError catch (e) {
      throw SyncException(_friendlyError('list', e));
    } on SocketException {
      throw SyncException('No internet connection.');
    }
  }

  @override
  Future<void> wipeRemote() async {
    final api = await _driveApi();
    try {
      final id = await _findFileId(api);
      if (id == null) return;
      await api.files.delete(id);
    } on gdrive.DetailedApiRequestError catch (e) {
      if (e.status == 404) return; // already gone
      throw SyncException(_friendlyError('delete', e));
    } on SocketException {
      throw SyncException('No internet connection.');
    }
  }

  // ── private ───────────────────────────────────────────────────────────────

  Future<gdrive.DriveApi> _driveApi() async {
    final client = await _auth.clientFor(_accountId, kGoogleDriveScopes);
    if (client == null) {
      throw SyncException(
          'Google Drive is not connected. Reconnect it in Settings → Sync.');
    }
    return gdrive.DriveApi(client);
  }

  Future<String?> _findFileId(gdrive.DriveApi api) async {
    final list = await api.files.list(
      spaces: _appDataFolder,
      q: "name = '$_remoteFileName'",
      $fields: 'files(id,modifiedTime)',
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }

  static String _friendlyError(String op, gdrive.DetailedApiRequestError e) {
    if (e.status == 401 || e.status == 403) {
      return 'Google Drive access was denied. Reconnect it in '
          'Settings → Sync.';
    }
    if (e.status == 404) {
      return 'No backup found in Google Drive yet.';
    }
    return 'Google Drive $op failed: ${e.message ?? e.status}';
  }
}
