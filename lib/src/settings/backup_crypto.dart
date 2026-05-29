import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// On-disk envelope written when the user opts into a passphrase-protected
/// backup. Plain (version-1) backups are still produced when no passphrase is
/// provided — both formats round-trip cleanly through [BackupService].
///
/// Format (JSON, written as `.planom`):
///   {
///     "version": 2,
///     "encryption": "aes-gcm-256/pbkdf2-sha256",
///     "iterations": 100000,
///     "salt": <base64 16B>,
///     "nonce": <base64 12B>,
///     "ciphertext": <base64 ciphertext + 16B tag concatenated>,
///   }
const int _kdfIterations = 100000;
const int _saltBytes = 16;

/// Encrypts [plainJson] with [passphrase] and returns the envelope as a JSON
/// string suitable to write to disk.
Future<String> encryptBackup(String plainJson, String passphrase) async {
  final salt = _randomBytes(_saltBytes);
  final key = await _deriveKey(passphrase, salt);

  final algo = AesGcm.with256bits();
  final nonce = algo.newNonce();
  final secretBox = await algo.encrypt(
    utf8.encode(plainJson),
    secretKey: key,
    nonce: nonce,
  );

  // AES-GCM tag is verified on decrypt — concatenate ciphertext+tag so the
  // envelope stays a single base64 blob.
  final ct = Uint8List.fromList([...secretBox.cipherText, ...secretBox.mac.bytes]);

  return const JsonEncoder.withIndent('  ').convert({
    'version': 2,
    'encryption': 'aes-gcm-256/pbkdf2-sha256',
    'iterations': _kdfIterations,
    'salt': base64.encode(salt),
    'nonce': base64.encode(nonce),
    'ciphertext': base64.encode(ct),
  });
}

/// Decrypts an envelope produced by [encryptBackup] back to the original
/// plain JSON. Throws if the passphrase is wrong (AES-GCM auth fail) or the
/// envelope is malformed.
Future<String> decryptBackup(
  Map<String, dynamic> envelope,
  String passphrase,
) async {
  final salt = base64.decode(envelope['salt'] as String);
  final nonce = base64.decode(envelope['nonce'] as String);
  final blob = base64.decode(envelope['ciphertext'] as String);
  if (blob.length < 16) {
    throw const FormatException('Ciphertext too short to contain GCM tag.');
  }
  final ct = blob.sublist(0, blob.length - 16);
  final tag = blob.sublist(blob.length - 16);

  final key = await _deriveKey(passphrase, salt);
  final algo = AesGcm.with256bits();
  final secretBox = SecretBox(ct, nonce: nonce, mac: Mac(tag));
  final plain = await algo.decrypt(secretBox, secretKey: key);
  return utf8.decode(plain);
}

/// True when the file looks like a v2 encrypted envelope so the importer
/// knows to prompt for a passphrase.
bool isEncryptedBackup(Map<String, dynamic> envelope) =>
    envelope['version'] == 2 && envelope['ciphertext'] is String;

Future<SecretKey> _deriveKey(String passphrase, List<int> salt) async {
  final kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _kdfIterations,
    bits: 256,
  );
  return kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(passphrase)),
    nonce: salt,
  );
}

List<int> _randomBytes(int len) {
  final r = Random.secure();
  return List<int>.generate(len, (_) => r.nextInt(256));
}
