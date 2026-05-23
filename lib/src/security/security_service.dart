import 'dart:convert';

import 'package:crypto/crypto.dart';

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

  PasswordType _type = PasswordType.none;
  PasswordType get type => _type;
  bool get isLocked => _type != PasswordType.none;

  Future<void> load() async {
    final rows = await _db.getAppSettings();
    for (final row in rows) {
      if (row['key'] == 'auth_type') {
        _type = _typeFromString(row['value'] as String?);
      }
    }
  }

  Future<void> setPassword(String password, PasswordType type) async {
    final hash = _hash(password);
    await _db.setAppSetting('auth_hash', hash);
    await _db.setAppSetting('auth_type', type.name);
    _type = type;
  }

  Future<void> removePassword() async {
    await _db.setAppSetting('auth_type', 'none');
    await _db.setAppSetting('auth_hash', '');
    _type = PasswordType.none;
  }

  Future<bool> verify(String password) async {
    final rows = await _db.getAppSettings();
    String? storedHash;
    for (final row in rows) {
      if (row['key'] == 'auth_hash') storedHash = row['value'] as String?;
    }
    if (storedHash == null || storedHash.isEmpty) return false;
    return _hash(password) == storedHash;
  }

  static String _hash(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

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
