import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planom/src/settings/backup_crypto.dart';

void main() {
  const payload = '{"version":1,"tasks":[{"id":"a","title":"hello"}]}';
  const passphrase = 'correct horse battery staple';

  test('encrypt then decrypt round-trips the original JSON', () async {
    final envelope = await encryptBackup(payload, passphrase);
    final map = jsonDecode(envelope) as Map<String, dynamic>;
    final plain = await decryptBackup(map, passphrase);
    expect(plain, payload);
  });

  test('isEncryptedBackup distinguishes envelopes from plain payloads', () async {
    final envelope = jsonDecode(await encryptBackup(payload, passphrase))
        as Map<String, dynamic>;
    expect(isEncryptedBackup(envelope), isTrue);

    final plain = jsonDecode(payload) as Map<String, dynamic>;
    expect(isEncryptedBackup(plain), isFalse);
  });

  test('decrypt with the wrong passphrase throws', () async {
    final map =
        jsonDecode(await encryptBackup(payload, passphrase)) as Map<String, dynamic>;
    await expectLater(decryptBackup(map, 'wrong passphrase'), throwsA(anything));
  });

  test('decrypt of tampered ciphertext throws', () async {
    final map =
        jsonDecode(await encryptBackup(payload, passphrase)) as Map<String, dynamic>;
    final bytes = base64.decode(map['ciphertext'] as String);
    bytes[0] ^= 0xFF; // flip a byte so the GCM tag no longer verifies
    map['ciphertext'] = base64.encode(bytes);
    await expectLater(decryptBackup(map, passphrase), throwsA(anything));
  });
}
