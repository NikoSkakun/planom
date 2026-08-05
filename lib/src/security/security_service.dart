import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../database/database_service.dart';

enum PasswordType { none, pin4, pin5, pin6, pin7, pin8, custom }

extension PasswordTypeX on PasswordType {
  int get pinLength {
    switch (this) {
      case PasswordType.pin4: return 4;
      case PasswordType.pin5: return 5;
      case PasswordType.pin6: return 6;
      case PasswordType.pin7: return 7;
      case PasswordType.pin8: return 8;
      default: return 0;
    }
  }

  bool get isPin => pinLength > 0;
}

class SecurityService {
  SecurityService(this._db);

  final DatabaseService _db;

  /// app_settings keys holding the local passcode. These are device-local and
  /// must never be written into a shared backup nor overwritten by an imported
  /// one — backup export/import filters them out via this set.
  static const authSettingKeys = {
    'auth_hash',
    'auth_type',
    'auth_salt',
    'auth_biometric',
  };

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Key-stretching rounds. Runs synchronously on the unlock path; tune (or
  /// move to an isolate) if it ever feels slow on a real device.
  static const _iterations = 100000;

  PasswordType _type = PasswordType.none;
  PasswordType get type => _type;

  /// Whether a passcode is configured at all.
  bool get isLocked => _type != PasswordType.none;

  /// Whether the user has already unlocked during this app run. The lock gate
  /// lives inside the widget tree that is rebuilt from scratch on every Space
  /// switch, so without this the app would demand the passcode again every
  /// time the user changed Space — which the tab-bar swipe makes constant.
  /// Backgrounding the app clears it (see [lock]).
  bool _unlockedThisRun = false;

  /// True when the lock screen should be shown right now.
  bool get shouldPrompt => isLocked && !_unlockedThisRun;

  /// Records a successful unlock for the rest of this app run.
  void markUnlocked() => _unlockedThisRun = true;

  /// Drops the unlocked state — called when the app leaves the foreground.
  void lock() => _unlockedThisRun = false;

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  Future<void> load() async {
    final rows = await _db.getAppSettings();
    for (final row in rows) {
      if (row['key'] == 'auth_type') {
        _type = _typeFromString(row['value'] as String?);
      }
      if (row['key'] == 'auth_biometric') {
        _biometricEnabled = row['value'] == 'true';
      }
    }
  }

  // ── Biometric ──────────────────────────────────────────────────────────────

  /// Whether the device has any enrolled biometric. Returns false on platforms
  /// without local_auth support (e.g. desktop), so callers can hide the toggle.
  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final available = await _localAuth.canCheckBiometrics;
      if (!available) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e, st) {
      debugPrint('biometric check failed: $e\n$st');
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    await _db.setAppSetting('auth_biometric', enabled ? 'true' : 'false');
  }

  /// Prompts Face ID / Touch ID. Returns true on success. Silently returns
  /// false on any error so callers can fall back to the PIN/password path.
  Future<bool> authenticateBiometric(String reason) async {
    if (!_biometricEnabled) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e, st) {
      debugPrint('biometric auth failed: $e\n$st');
      return false;
    }
  }

  Future<void> setPassword(String password, PasswordType type) async {
    final salt = _generateSalt();
    await _db.setAppSetting('auth_salt', salt);
    await _db.setAppSetting('auth_hash', _hash(password, salt));
    await _db.setAppSetting('auth_type', type.name);
    _type = type;
  }

  Future<void> removePassword() async {
    await _db.setAppSetting('auth_type', 'none');
    await _db.setAppSetting('auth_hash', '');
    await _db.setAppSetting('auth_salt', '');
    _type = PasswordType.none;
  }

  Future<bool> verify(String password) async {
    final rows = await _db.getAppSettings();
    String? storedHash;
    String? salt;
    for (final row in rows) {
      if (row['key'] == 'auth_hash') storedHash = row['value'] as String?;
      if (row['key'] == 'auth_salt') salt = row['value'] as String?;
    }
    if (storedHash == null || storedHash.isEmpty) return false;

    if (salt == null || salt.isEmpty) {
      // Legacy unsalted SHA-256 hash from before salting was added. Verify
      // against the old scheme and, on success, transparently re-store the
      // passcode in the salted + stretched form.
      if (_legacyHash(password) != storedHash) return false;
      await setPassword(password, _type);
      return true;
    }
    return _hash(password, salt) == storedHash;
  }

  static String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64.encode(bytes);
  }

  static String _hash(String password, String salt) {
    final hmac = Hmac(sha256, base64.decode(salt));
    var digest = hmac.convert(utf8.encode(password)).bytes;
    for (int i = 1; i < _iterations; i++) {
      digest = hmac.convert(digest).bytes;
    }
    return base64.encode(digest);
  }

  static String _legacyHash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  static PasswordType _typeFromString(String? s) {
    switch (s) {
      case 'pin4': return PasswordType.pin4;
      case 'pin5': return PasswordType.pin5;
      case 'pin6': return PasswordType.pin6;
      case 'pin7': return PasswordType.pin7;
      case 'pin8': return PasswordType.pin8;
      case 'custom': return PasswordType.custom;
      default: return PasswordType.none;
    }
  }
}
