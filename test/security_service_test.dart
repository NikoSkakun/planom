import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/security/security_service.dart';

import 'support/test_db.dart';

void main() {
  initTestDatabaseFactory();

  late DatabaseService db;
  late SecurityService service;

  setUp(() async {
    db = freshDb();
    service = SecurityService(db);
    await service.load();
  });

  test('fresh service has no passcode', () async {
    expect(service.type, PasswordType.none);
    expect(service.isLocked, isFalse);
  });

  test('setPassword then verify correct/wrong', () async {
    await service.setPassword('1234', PasswordType.pin4);
    expect(service.type, PasswordType.pin4);
    expect(service.isLocked, isTrue);

    expect(await service.verify('1234'), isTrue);
    expect(await service.verify('0000'), isFalse);
  });

  test('configured type persists for a fresh service on the same DB', () async {
    await service.setPassword('4321', PasswordType.pin4);

    final second = SecurityService(db);
    await second.load();
    expect(second.type, PasswordType.pin4);
    expect(second.isLocked, isTrue);
    // The second instance verifies against the persisted hash + salt.
    expect(await second.verify('4321'), isTrue);
    expect(await second.verify('1111'), isFalse);
  });

  test('removePassword resets type to none; verify returns false', () async {
    await service.setPassword('1234', PasswordType.pin4);
    await service.removePassword();

    expect(service.type, PasswordType.none);
    expect(service.isLocked, isFalse);
    // Hash was cleared, so verify always returns false.
    expect(await service.verify('1234'), isFalse);
    expect(await service.verify(''), isFalse);
  });

  test('setBiometricEnabled persists the flag', () async {
    expect(service.biometricEnabled, isFalse);
    await service.setBiometricEnabled(true);
    expect(service.biometricEnabled, isTrue);

    final second = SecurityService(db);
    await second.load();
    expect(second.biometricEnabled, isTrue);

    await service.setBiometricEnabled(false);
    final third = SecurityService(db);
    await third.load();
    expect(third.biometricEnabled, isFalse);
  });

  test('stored hash differs from plaintext password', () async {
    await service.setPassword('secret', PasswordType.custom);
    final rows = await db.getAppSettings();
    final hashRow =
        rows.firstWhere((r) => r['key'] == 'auth_hash');
    final stored = hashRow['value'] as String;
    expect(stored, isNotEmpty);
    expect(stored, isNot('secret'));
  });

  test('two different passwords do not both verify', () async {
    await service.setPassword('aaaa', PasswordType.pin4);
    expect(await service.verify('aaaa'), isTrue);
    expect(await service.verify('bbbb'), isFalse);

    // Reset to a different password; the old one must stop verifying.
    await service.setPassword('bbbb', PasswordType.pin4);
    expect(await service.verify('bbbb'), isTrue);
    expect(await service.verify('aaaa'), isFalse);
  });
}
