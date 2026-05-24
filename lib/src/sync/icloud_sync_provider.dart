import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'sync_provider.dart';
import 'sync_state.dart';

/// iCloud Drive sync. Uses the system's ubiquitous container so Apple does
/// the heavy lifting — file presence, retry, throttling, conflict files all
/// land in the same `Documents/` folder.
///
/// REQUIRES (one-time, in Xcode — cannot be done from Dart):
///   1. Signing & Capabilities → add "iCloud" capability for Runner target.
///   2. Check "iCloud Documents".
///   3. Add a container with identifier matching [_defaultContainerId]
///      (default `iCloud.<bundle-id>`) — Xcode creates it on Apple Developer.
///   4. Add NSUbiquitousContainers to Info.plist (see iOS docs); the
///      `icloud_storage` package README has the exact snippet.
///
/// Until those Xcode steps are done, [isAvailable] returns true on iOS but
/// every operation throws — the controller surfaces that as a banner
/// telling the user to enable iCloud on the device.
class ICloudSyncProvider extends SyncProvider {
  ICloudSyncProvider({String? containerId})
      : _containerId = containerId ?? _defaultContainerId;

  // Default convention `iCloud.<bundle-id>` — matches what most apps use and
  // what the Xcode "Use default container" checkbox produces. Override via
  // the constructor if a different one is created in App Store Connect.
  static const _defaultContainerId = 'iCloud.com.planom.app';
  static const _remoteFileName = 'planom.sync.enc';

  final String _containerId;

  @override
  SyncBackend get backend => SyncBackend.icloud;

  @override
  Future<bool> isAvailable() async {
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Future<bool> isConfigured() async {
    if (!await isAvailable()) return false;
    try {
      await ICloudStorage.gather(containerId: _containerId);
      return true;
    } catch (_) {
      // gather() throws when the container isn't in the entitlements or the
      // user isn't signed into iCloud — both mean "user needs to set up".
      return false;
    }
  }

  @override
  Future<void> push(List<int> encryptedPayload) async {
    final tmp = await _writeTemp(encryptedPayload);
    try {
      await ICloudStorage.upload(
        containerId: _containerId,
        filePath: tmp.path,
        destinationRelativePath: _remoteFileName,
      );
    } on PlatformException catch (e) {
      throw SyncException(_friendlyError('upload', e));
    } finally {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<List<int>?> pull() async {
    final files = await _safeGather();
    ICloudFile? match;
    for (final f in files) {
      if (f.relativePath == _remoteFileName) {
        match = f;
        break;
      }
    }
    if (match == null) return null;

    final dest = await _tempPath();
    try {
      await ICloudStorage.download(
        containerId: _containerId,
        relativePath: _remoteFileName,
        destinationFilePath: dest,
      );
      final file = File(dest);
      final bytes = await file.readAsBytes();
      try {
        await file.delete();
      } catch (_) {}
      return bytes;
    } on PlatformException catch (e) {
      throw SyncException(_friendlyError('download', e));
    }
  }

  @override
  Future<DateTime?> lastRemoteUpdate() async {
    final files = await _safeGather();
    for (final f in files) {
      if (f.relativePath == _remoteFileName) {
        return f.contentChangeDate;
      }
    }
    return null;
  }

  @override
  Future<void> wipeRemote() async {
    try {
      await ICloudStorage.delete(
        containerId: _containerId,
        relativePath: _remoteFileName,
      );
    } on PlatformException catch (e) {
      // 404-ish "not found" is fine — the file already isn't there.
      if (e.code == PlatformExceptionCode.fileNotFound) return;
      throw SyncException(_friendlyError('delete', e));
    }
  }

  // ── private ───────────────────────────────────────────────────────────────

  Future<File> _writeTemp(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$_remoteFileName.tmp');
    await f.writeAsBytes(Uint8List.fromList(bytes), flush: true);
    return f;
  }

  Future<String> _tempPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$_remoteFileName.dl';
  }

  Future<List<ICloudFile>> _safeGather() async {
    try {
      return await ICloudStorage.gather(containerId: _containerId);
    } on PlatformException catch (e) {
      throw SyncException(_friendlyError('list', e));
    }
  }

  static String _friendlyError(String op, PlatformException e) {
    switch (e.code) {
      case PlatformExceptionCode.iCloudConnectionOrPermission:
        return 'iCloud is not set up. Sign into iCloud and enable iCloud '
            'Drive for Planom in Settings.';
      case PlatformExceptionCode.fileNotFound:
        return 'No backup found in iCloud yet.';
      default:
        return 'iCloud $op failed: ${e.message ?? e.code}';
    }
  }
}
