import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/settings/backup_crypto.dart';

void main() {
  group('backup_crypto', () {
    const plain = '{"version":1,"tasks":[{"id":"a","title":"hello"}]}';
    const passphrase = 'correct horse battery staple';

    test('encryptBackup then decryptBackup returns the original plaintext',
        () async {
      final envelopeJson = await encryptBackup(plain, passphrase);
      final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
      final out = await decryptBackup(envelope, passphrase);
      expect(out, plain);
    });

    test('envelope has the expected shape', () async {
      final envelope = jsonDecode(await encryptBackup(plain, passphrase))
          as Map<String, dynamic>;
      expect(envelope['version'], 2);
      expect(envelope['encryption'], 'aes-gcm-256/pbkdf2-sha256');
      expect(envelope['iterations'], 100000);
      expect(envelope['salt'], isA<String>());
      expect(envelope['nonce'], isA<String>());
      expect(envelope['ciphertext'], isA<String>());
      // salt is 16 bytes, nonce 12 bytes (base64-decodable).
      expect(base64.decode(envelope['salt'] as String).length, 16);
      expect(base64.decode(envelope['nonce'] as String).length, 12);
    });

    test('isEncryptedBackup is true for an envelope', () async {
      final envelope = jsonDecode(await encryptBackup(plain, passphrase))
          as Map<String, dynamic>;
      expect(isEncryptedBackup(envelope), isTrue);
    });

    test('isEncryptedBackup is false for a plaintext payload', () {
      expect(isEncryptedBackup({'version': 1}), isFalse);
      expect(
        isEncryptedBackup({'version': 1, 'tasks': <dynamic>[]}),
        isFalse,
      );
      // version 2 marker but no string ciphertext => not a valid envelope.
      expect(isEncryptedBackup({'version': 2}), isFalse);
      expect(
        isEncryptedBackup({'encryption': 'aes-gcm-256/pbkdf2-sha256'}),
        isFalse,
      );
    });

    test('wrong passphrase fails to decrypt (throws)', () async {
      final envelope = jsonDecode(await encryptBackup(plain, passphrase))
          as Map<String, dynamic>;
      await expectLater(
        decryptBackup(envelope, 'wrong passphrase'),
        throwsA(isA<Exception>()),
      );
    });

    test('decryptBackup on a non-envelope map throws', () async {
      // A plaintext payload has no salt/nonce/ciphertext, so the `as String`
      // casts inside decryptBackup throw a TypeError.
      await expectLater(
        decryptBackup({'version': 1}, passphrase),
        throwsA(isA<TypeError>()),
      );
    });

    test('decryptBackup with too-short ciphertext throws FormatException',
        () async {
      // Well-formed envelope shape but ciphertext shorter than the 16-byte tag.
      await expectLater(
        decryptBackup({
          'version': 2,
          'salt': base64.encode(List.filled(16, 0)),
          'nonce': base64.encode(List.filled(12, 0)),
          'ciphertext': base64.encode(List.filled(4, 0)),
        }, passphrase),
        throwsA(isA<FormatException>()),
      );
    });

    test('encrypting twice yields different ciphertext but both decrypt',
        () async {
      final e1 = jsonDecode(await encryptBackup(plain, passphrase))
          as Map<String, dynamic>;
      final e2 = jsonDecode(await encryptBackup(plain, passphrase))
          as Map<String, dynamic>;

      // Random salt + nonce per call => different envelopes.
      expect(e1['ciphertext'], isNot(e2['ciphertext']));
      expect(e1['salt'], isNot(e2['salt']));
      expect(e1['nonce'], isNot(e2['nonce']));

      expect(await decryptBackup(e1, passphrase), plain);
      expect(await decryptBackup(e2, passphrase), plain);
    });

    test('round-trips unicode and empty content', () async {
      for (final text in ['', 'emoji 🎉 ünïcödé 日本語', 'a']) {
        final env = jsonDecode(await encryptBackup(text, passphrase))
            as Map<String, dynamic>;
        expect(await decryptBackup(env, passphrase), text);
      }
    });
  });
}
