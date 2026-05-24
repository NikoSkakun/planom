import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../settings/backup_crypto.dart';
import '../settings/backup_service.dart';
import 'icloud_sync_provider.dart';
import 'sync_provider.dart';
import 'sync_secrets.dart';
import 'sync_state.dart';

/// Top-level coordinator for sync. Owns the active [SyncProvider], the
/// passphrase store, and the public [SyncSnapshot] the UI binds to.
///
/// Architecture: this controller knows nothing about specific backends. It
/// asks [BackupService] for a payload, asks [SyncSecrets] for the passphrase,
/// runs the payload through [encryptBackup] / [decryptBackup], and hands the
/// resulting bytes to whichever [SyncProvider] the user selected. New
/// backends slot in by implementing [SyncProvider] and being registered in
/// [_providerFor].
class SyncController with ChangeNotifier {
  SyncController({
    required DatabaseService db,
    required BackupService backupService,
    SyncSecrets? secrets,
  })  : _db = db,
        _backupService = backupService,
        _secrets = secrets ?? SyncSecrets();

  final DatabaseService _db;
  final BackupService _backupService;
  final SyncSecrets _secrets;

  static const _kBackendKey = 'sync_backend';

  SyncSnapshot _snapshot = SyncSnapshot.initial;
  SyncSnapshot get snapshot => _snapshot;
  SyncProvider? _provider;

  Future<void> load() async {
    // Restore the selected backend across launches. The passphrase is in
    // secure storage, so on app start we know which backend the user picked
    // but may not have the passphrase ready until they unlock the device.
    final rows = await _db.getAppSettings();
    for (final r in rows) {
      if (r['key'] == _kBackendKey) {
        final backend = SyncBackendX.fromId(r['value'] as String?);
        _provider = _providerFor(backend);
        _snapshot = _snapshot.copyWith(backend: backend);
      }
    }
    if (_provider != null && !await _provider!.isConfigured()) {
      _snapshot = _snapshot.copyWith(status: SyncStatus.notConfigured);
    }
    notifyListeners();
  }

  /// Switch backend (or turn sync off). Wipes the cached provider so the
  /// next push uses the new one.
  Future<void> setBackend(SyncBackend backend) async {
    await _db.setAppSetting(_kBackendKey, backend.id);
    _provider = _providerFor(backend);
    _snapshot = _snapshot.copyWith(
      backend: backend,
      status: SyncStatus.idle,
      clearError: true,
    );
    notifyListeners();

    // Re-check availability/configuration so the UI shows the right CTA
    // immediately after switching, not on the next manual sync.
    if (_provider != null) {
      if (!await _provider!.isAvailable()) {
        _snapshot = _snapshot.copyWith(status: SyncStatus.notAvailable);
      } else if (!await _provider!.isConfigured()) {
        _snapshot = _snapshot.copyWith(status: SyncStatus.notConfigured);
      }
      notifyListeners();
    }
  }

  /// Sets the E2E passphrase. Validates non-empty so the empty string can't
  /// silently encrypt nothing.
  Future<void> setPassphrase(String passphrase) async {
    if (passphrase.isEmpty) {
      throw SyncException('Passphrase cannot be empty.');
    }
    await _secrets.writePassphrase(passphrase);
    notifyListeners();
  }

  Future<bool> hasPassphrase() => _secrets.hasPassphrase();

  Future<void> clearPassphrase() => _secrets.clear();

  /// Encrypts (when a passphrase is set) and uploads the active space's
  /// current state. When no passphrase is set the payload goes up as plain
  /// JSON — Apple's iCloud encryption-at-rest still applies, but Apple holds
  /// the keys. Users can opt into client-side E2E later by setting a
  /// passphrase from Settings → Sync.
  Future<void> pushNow() async {
    final provider = _provider;
    if (provider == null) return;

    _setStatus(SyncStatus.pushing);
    try {
      final plain = await _backupService.buildPayloadJson();
      final passphrase = await _secrets.readPassphrase();
      final payload = (passphrase != null && passphrase.isNotEmpty)
          ? await encryptBackup(plain, passphrase)
          : plain;
      await provider.push(utf8.encode(payload));
      _snapshot = _snapshot.copyWith(
        status: SyncStatus.succeeded,
        lastSyncAt: DateTime.now(),
        clearError: true,
      );
    } on SyncException catch (e) {
      _snapshot = _snapshot.copyWith(
          status: SyncStatus.failed, lastError: e.message);
    } catch (e, st) {
      debugPrint('push failed: $e\n$st');
      _snapshot = _snapshot.copyWith(
          status: SyncStatus.failed, lastError: 'Push failed: $e');
    }
    notifyListeners();
  }

  /// Pulls the remote snapshot and replaces local data with it. Returns
  /// `true` when something was actually applied.
  Future<bool> pullNow() async {
    final provider = _provider;
    if (provider == null) return false;

    _setStatus(SyncStatus.pulling);
    try {
      final bytes = await provider.pull();
      if (bytes == null) {
        _snapshot = _snapshot.copyWith(
          status: SyncStatus.succeeded,
          lastSyncAt: DateTime.now(),
          clearError: true,
        );
        notifyListeners();
        return false;
      }

      final content = utf8.decode(bytes);
      Map<String, dynamic> envelope;
      try {
        envelope = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        throw SyncException('Remote backup is corrupted.');
      }

      // Two payload shapes share the same iCloud filename: encrypted (v2
      // envelope) when the producer had a passphrase, plain (v1) otherwise.
      // Sniff which one we got and route accordingly — a device that never
      // set a passphrase can still pull a plain payload someone else pushed.
      String plain;
      if (isEncryptedBackup(envelope)) {
        final pass = await _secrets.readPassphrase();
        if (pass == null || pass.isEmpty) {
          _snapshot = _snapshot.copyWith(
            status: SyncStatus.passphraseRequired,
            lastError:
                'The cloud backup is encrypted. Set the matching passphrase '
                'in Settings → Sync → Encryption to pull it.',
          );
          notifyListeners();
          return false;
        }
        plain = await decryptBackup(envelope, pass);
      } else {
        plain = content;
      }

      final applied = await _backupService.importPayloadJson(plain);
      _snapshot = _snapshot.copyWith(
        status: applied ? SyncStatus.succeeded : SyncStatus.failed,
        lastSyncAt: applied ? DateTime.now() : _snapshot.lastSyncAt,
        lastError: applied ? null : 'Imported data was rejected.',
        clearError: applied,
      );
      notifyListeners();
      return applied;
    } on SyncException catch (e) {
      _snapshot = _snapshot.copyWith(
          status: SyncStatus.failed, lastError: e.message);
      notifyListeners();
      return false;
    } catch (e, st) {
      debugPrint('pull failed: $e\n$st');
      _snapshot = _snapshot.copyWith(
          status: SyncStatus.failed,
          lastError: 'Pull failed. Wrong passphrase?');
      notifyListeners();
      return false;
    }
  }

  /// Removes the remote payload (e.g. user disabling sync) and clears local
  /// sync state. Does NOT delete local user data.
  Future<void> disableAndWipeRemote() async {
    final provider = _provider;
    if (provider != null) {
      try {
        await provider.wipeRemote();
      } catch (_) {/* best effort */}
    }
    await _secrets.clear();
    await setBackend(SyncBackend.none);
  }

  // ── private ───────────────────────────────────────────────────────────────

  void _setStatus(SyncStatus status) {
    _snapshot = _snapshot.copyWith(status: status, clearError: true);
    notifyListeners();
  }

  SyncProvider? _providerFor(SyncBackend backend) {
    switch (backend) {
      case SyncBackend.none:
        return null;
      case SyncBackend.icloud:
        return ICloudSyncProvider();
      case SyncBackend.planom:
      case SyncBackend.custom:
        // Planom-hosted + custom-server providers slot in here — the rest of
        // the controller doesn't change. Tracked as "coming soon" in the UI.
        return null;
    }
  }
}
