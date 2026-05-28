import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/settings/backup_crypto.dart';
import 'package:planom/src/sync/sync_controller.dart';
import 'package:planom/src/sync/sync_payload_source.dart';
import 'package:planom/src/sync/sync_provider.dart';
import 'package:planom/src/sync/sync_secrets.dart';
import 'package:planom/src/sync/sync_state.dart';

/// In-memory remote — no network, no entitlements. Always available and
/// configured so we exercise the controller's orchestration, not the gating.
class _FakeProvider extends SyncProvider {
  List<int>? stored;

  @override
  SyncBackend get backend => SyncBackend.icloud;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> isConfigured() async => true;
  @override
  Future<void> push(List<int> encryptedPayload) async {
    stored = encryptedPayload;
  }

  @override
  Future<List<int>?> pull() async => stored;
  @override
  Future<DateTime?> lastRemoteUpdate() async =>
      stored == null ? null : DateTime.now();
  @override
  Future<void> wipeRemote() async {
    stored = null;
  }
}

class _FakeBackup implements SyncPayloadSource {
  _FakeBackup(this.payload);
  String payload;
  String? importedPlain;
  bool importResult = true;

  @override
  Future<String> buildPayloadJson() async => payload;
  @override
  Future<bool> importPayloadJson(String plainJson) async {
    importedPlain = plainJson;
    return importResult;
  }
}

class _FakeSecrets extends SyncSecrets {
  String? _pass;
  @override
  Future<String?> readPassphrase() async => _pass;
  @override
  Future<void> writePassphrase(String passphrase) async => _pass = passphrase;
  @override
  Future<void> clear() async => _pass = null;
  @override
  Future<bool> hasPassphrase() async => _pass != null && _pass!.isNotEmpty;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;
  late _FakeProvider provider;
  late _FakeBackup backup;
  late _FakeSecrets secrets;

  const payload = '{"version":1,"tasks":[{"id":"a","title":"hi"}]}';

  SyncController newController() => SyncController(
        db: db,
        backupService: backup,
        secrets: secrets,
        providerFactory: (b) => b == SyncBackend.icloud ? provider : null,
      );

  setUp(() {
    db = DatabaseService(
        dbName: 'test_sync_${DateTime.now().microsecondsSinceEpoch}.db');
    provider = _FakeProvider();
    backup = _FakeBackup(payload);
    secrets = _FakeSecrets();
  });

  test('setBackend persists and load restores it', () async {
    await newController().setBackend(SyncBackend.icloud);

    final restored = newController();
    await restored.load();
    expect(restored.snapshot.backend, SyncBackend.icloud);
    expect(restored.snapshot.status, SyncStatus.idle);
  });

  test('push without passphrase stores plaintext', () async {
    final c = newController();
    await c.setBackend(SyncBackend.icloud);
    await c.pushNow();

    expect(c.snapshot.status, SyncStatus.succeeded);
    final content = utf8.decode(provider.stored!);
    expect(content, payload);
    expect(isEncryptedBackup(jsonDecode(content) as Map<String, dynamic>),
        isFalse);
  });

  test('push with passphrase stores an encrypted envelope', () async {
    final c = newController();
    await c.setBackend(SyncBackend.icloud);
    await c.setPassphrase('s3cret');
    await c.pushNow();

    expect(c.snapshot.status, SyncStatus.succeeded);
    final envelope =
        jsonDecode(utf8.decode(provider.stored!)) as Map<String, dynamic>;
    expect(isEncryptedBackup(envelope), isTrue);
    expect(await decryptBackup(envelope, 's3cret'), payload);
  });

  test('pull from empty remote returns false', () async {
    final c = newController();
    await c.setBackend(SyncBackend.icloud);
    final applied = await c.pullNow();

    expect(applied, isFalse);
    expect(backup.importedPlain, isNull);
    expect(c.snapshot.status, SyncStatus.succeeded);
  });

  test('pull of plaintext applies the payload', () async {
    final c = newController();
    await c.setBackend(SyncBackend.icloud);
    provider.stored = utf8.encode(payload);

    final applied = await c.pullNow();
    expect(applied, isTrue);
    expect(backup.importedPlain, payload);
    expect(c.snapshot.status, SyncStatus.succeeded);
  });

  test('pull of encrypted payload without a passphrase asks for one', () async {
    final c = newController();
    await c.setBackend(SyncBackend.icloud);
    provider.stored = utf8.encode(await encryptBackup(payload, 's3cret'));

    final applied = await c.pullNow();
    expect(applied, isFalse);
    expect(backup.importedPlain, isNull);
    expect(c.snapshot.status, SyncStatus.passphraseRequired);
  });

  test('pull of encrypted payload with the right passphrase applies', () async {
    final c = newController();
    await c.setBackend(SyncBackend.icloud);
    await c.setPassphrase('s3cret');
    provider.stored = utf8.encode(await encryptBackup(payload, 's3cret'));

    final applied = await c.pullNow();
    expect(applied, isTrue);
    expect(backup.importedPlain, payload);
    expect(c.snapshot.status, SyncStatus.succeeded);
  });

  test('disableAndWipeRemote clears remote, secret and backend', () async {
    final c = newController();
    await c.setBackend(SyncBackend.icloud);
    await c.setPassphrase('s3cret');
    await c.pushNow();
    expect(provider.stored, isNotNull);

    await c.disableAndWipeRemote();
    expect(provider.stored, isNull);
    expect(c.snapshot.backend, SyncBackend.none);
    expect(await secrets.hasPassphrase(), isFalse);
  });
}
