import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the E2E encryption passphrase out of the SQLite DB and out of
/// regular SharedPreferences. iOS Keychain / Android Keystore-backed via
/// flutter_secure_storage so the secret survives reinstalls only when the
/// device backup includes the Keychain, and is excluded from app backups.
///
/// We deliberately do not put the passphrase in `app_settings` (alongside the
/// app-lock PIN) because that table is what BackupService exports — even with
/// the auth_* allowlist, treating sync secrets as keychain material is the
/// safer separation of concerns.
class SyncSecrets {
  SyncSecrets({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kPassphrase = 'planom_sync_passphrase';

  /// Reads the passphrase. Returns null when sync is not set up or the
  /// secure storage is locked.
  Future<String?> readPassphrase() async {
    try {
      return await _storage.read(key: _kPassphrase);
    } catch (e, st) {
      debugPrint('SyncSecrets.read failed: $e\n$st');
      return null;
    }
  }

  Future<void> writePassphrase(String passphrase) async {
    await _storage.write(key: _kPassphrase, value: passphrase);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kPassphrase);
  }

  Future<bool> hasPassphrase() async {
    final p = await readPassphrase();
    return p != null && p.isNotEmpty;
  }
}
