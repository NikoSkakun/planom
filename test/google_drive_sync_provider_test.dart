import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:planom/src/integrations/google/google_auth_service.dart';
import 'package:planom/src/sync/google_drive_sync_provider.dart';

/// Auth stub whose [clientFor] hands back a scripted [MockClient]. The provider
/// builds a real googleapis `DriveApi` over it, so we exercise the actual Drive
/// request/response plumbing without hitting the network or secure storage.
class _FakeAuth extends GoogleAuthService {
  _FakeAuth(this.client);
  final http.Client client;
  @override
  Future<http.Client?> clientFor(String accountId, List<String> scopes) async =>
      client;
}

void main() {
  test('pull returns null when no backup file exists', () async {
    final mock = MockClient((req) async {
      // files.list over the appDataFolder → empty.
      return http.Response(jsonEncode({'files': []}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final provider = GoogleDriveSyncProvider(auth: _FakeAuth(mock));
    expect(await provider.pull(), isNull);
  });

  test('push creates the file when none exists', () async {
    final calls = <String>[];
    final mock = MockClient((req) async {
      if (req.url.path.contains('/upload/')) {
        calls.add('${req.method} upload');
        return http.Response(jsonEncode({'id': 'file1'}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      // files.list → empty, so push must create.
      return http.Response(jsonEncode({'files': []}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final provider = GoogleDriveSyncProvider(auth: _FakeAuth(mock));
    await provider.push(utf8.encode('payload'));
    expect(calls, contains('POST upload'));
  });

  test('push updates the existing file in place', () async {
    final calls = <String>[];
    final mock = MockClient((req) async {
      if (req.url.path.contains('/upload/')) {
        calls.add('${req.method} upload ${req.url.path}');
        return http.Response(jsonEncode({'id': 'file1'}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      // files.list → one existing file, so push must update (PATCH).
      return http.Response(
          jsonEncode({
            'files': [
              {'id': 'file1', 'modifiedTime': '2026-01-01T00:00:00.000Z'}
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final provider = GoogleDriveSyncProvider(auth: _FakeAuth(mock));
    await provider.push(utf8.encode('payload'));
    expect(calls.single, startsWith('PATCH upload'));
    expect(calls.single, contains('file1'));
  });

  test('pull downloads the bytes of the existing file', () async {
    final mock = MockClient((req) async {
      if (req.url.queryParameters['alt'] == 'media') {
        return http.Response.bytes(utf8.encode('cipher-bytes'), 200,
            headers: {'content-type': 'application/octet-stream'});
      }
      return http.Response(
          jsonEncode({
            'files': [
              {'id': 'file1', 'modifiedTime': '2026-01-01T00:00:00.000Z'}
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final provider = GoogleDriveSyncProvider(auth: _FakeAuth(mock));
    final bytes = await provider.pull();
    expect(bytes, isNotNull);
    expect(utf8.decode(bytes!), 'cipher-bytes');
  });

  test('wipeRemote is a no-op when nothing is stored', () async {
    final mock = MockClient((req) async {
      return http.Response(jsonEncode({'files': []}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final provider = GoogleDriveSyncProvider(auth: _FakeAuth(mock));
    await provider.wipeRemote(); // should not throw
  });
}
