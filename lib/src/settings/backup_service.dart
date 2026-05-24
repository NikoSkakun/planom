import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../calendar/event_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../folders/folder_icon_picker.dart';
import '../notes/note_controller.dart';
import '../routines/routine_controller.dart';
import '../security/security_service.dart';
import '../tasks/task_controller.dart';
import 'backup_crypto.dart';
import 'settings_controller.dart';

class BackupService {
  BackupService({
    required this.db,
    required this.taskController,
    required this.folderController,
    required this.noteController,
    required this.routineController,
    required this.eventController,
    required this.settingsController,
  });

  final DatabaseService db;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final RoutineController routineController;
  final EventController eventController;
  final SettingsController settingsController;

  /// Exports the active space. If [passphrase] is non-null and non-empty, the
  /// payload is AES-GCM-256 encrypted under a key derived from it (PBKDF2-
  /// SHA256, 100k iterations); the resulting `.planom` file is unreadable
  /// without the same passphrase.
  Future<void> exportBackup({String? passphrase}) async {
    final docsPath = (await getApplicationDocumentsDirectory()).path;

    // Fetch raw DB maps for tables that may have custom icon paths.
    var folders = await db.exportFolders();
    var lists = await db.exportLists();
    var noteFolders = await db.exportNoteFolders();

    // Collect image bytes keyed by relative path; normalize absolute paths.
    final customIcons = <String, String>{};
    folders = await _inlineIcons(folders, 'iconId', docsPath, customIcons);
    lists = await _inlineIcons(lists, 'iconId', docsPath, customIcons);
    noteFolders =
        await _inlineIcons(noteFolders, 'iconId', docsPath, customIcons);

    final payload = <String, dynamic>{
      'version': 1,
      'exportDate': DateTime.now().millisecondsSinceEpoch,
      'customIcons': customIcons,
      'tasks': await db.exportTasks(),
      'tags': await db.exportTags(),
      'folders': folders,
      'app_lists': lists,
      'note_folders': noteFolders,
      'notes': await db.exportNotes(),
      'routines': await db.exportRoutines(),
      'routine_entries': await db.exportRoutineEntries(),
      'events': await db.exportEvents(),
      // Exclude the local passcode (auth_*) so it never leaves the device.
      'app_settings': (await db.exportAppSettings())
          .where((r) => !SecurityService.authSettingKeys.contains(r['key']))
          .toList(),
      // Smart-list visibility + hideTabLabels live in a JSON file in the docs
      // directory, not the DB, so we include their raw map here.
      'smart_list_prefs': settingsController.smartListPrefs.toJson(),
    };

    final plainJson = const JsonEncoder.withIndent('  ').convert(payload);
    final fileContent = (passphrase != null && passphrase.isNotEmpty)
        ? await encryptBackup(plainJson, passphrase)
        : plainJson;

    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final name =
        'planom_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.planom';
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(fileContent, encoding: utf8);

    try {
      await Share.shareXFiles([XFile(file.path)], subject: 'Planom Backup');
    } finally {
      // The share sheet has copied/handed off the file by the time this
      // returns, so clean up the temp copy rather than letting it accumulate.
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  /// Returns true on success, false if file was invalid or picker cancelled.
  /// When the backup is encrypted, [passphraseProvider] is awaited to ask the
  /// user for the passphrase; returning null cancels the import.
  Future<bool> importBackup({
    Future<String?> Function()? passphraseProvider,
  }) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return false;

    final path = result.files.single.path;
    if (path == null) return false;

    final content = await File(path).readAsString(encoding: utf8);

    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }

    // Encrypted (v2): ask the caller for the passphrase, decrypt to the
    // plain v1 JSON, then fall through to the normal import path.
    Map<String, dynamic> data = envelope;
    if (isEncryptedBackup(envelope)) {
      if (passphraseProvider == null) return false;
      final pass = await passphraseProvider();
      if (pass == null || pass.isEmpty) return false;
      try {
        final plain = await decryptBackup(envelope, pass);
        data = jsonDecode(plain) as Map<String, dynamic>;
      } catch (_) {
        // Wrong passphrase or corrupt envelope — leave existing data alone.
        return false;
      }
    }

    if (data['version'] != 1) return false;

    List<Map<String, dynamic>> asMaps(dynamic value) {
      if (value == null) return [];
      return (value as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    // Keep the device's local passcode and never let an imported backup change
    // it: preserve our own auth_* rows and drop any the backup carries.
    final localAuth = (await db.exportAppSettings())
        .where((r) => SecurityService.authSettingKeys.contains(r['key']))
        .toList();

    // Fully parse and validate the payload BEFORE touching any data. If the
    // backup is malformed, we return early with everything still intact.
    final Map<String, dynamic> customIcons;
    final Map<String, List<Map<String, dynamic>>> tables;
    try {
      customIcons = (data['customIcons'] as Map<String, dynamic>?) ?? {};
      tables = {
        'tasks': asMaps(data['tasks']),
        'tags': asMaps(data['tags']),
        'folders': asMaps(data['folders']),
        'app_lists': asMaps(data['app_lists']),
        'note_folders': asMaps(data['note_folders']),
        'notes': asMaps(data['notes']),
        'routines': asMaps(data['routines']),
        'routine_entries': asMaps(data['routine_entries']),
        'events': asMaps(data['events']),
        'app_settings': [
          ...asMaps(data['app_settings']).where(
              (r) => !SecurityService.authSettingKeys.contains(r['key'])),
          ...localAuth,
        ],
      };
    } catch (_) {
      return false;
    }

    // Restore custom icon files first so DB records can reference them. These
    // are written before the DB transaction; orphaned files are harmless if
    // the import is later aborted.
    final docsPath = (await getApplicationDocumentsDirectory()).path;
    final iconsDir = Directory('$docsPath/icons');
    if (!iconsDir.existsSync()) iconsDir.createSync(recursive: true);
    for (final entry in customIcons.entries) {
      final relPath = entry.key; // 'icons/filename.ext'
      final bytes = base64Decode(entry.value as String);
      await File('$docsPath/$relPath').writeAsBytes(bytes);
    }

    // Atomic clear + insert: on any failure the transaction rolls back and the
    // user's existing data is preserved (no half-imported state).
    try {
      await db.replaceAllData(tables);
    } catch (_) {
      return false;
    }

    // Smart-list prefs were added in a later format revision; ignore if absent.
    final smartListMap = data['smart_list_prefs'];
    if (smartListMap is Map<String, dynamic>) {
      await settingsController.importSmartListPrefs(smartListMap);
    }

    await taskController.load();
    await folderController.load();
    await noteController.load();
    await routineController.load();
    await eventController.load();
    await settingsController.loadSettings();

    return true;
  }

  Future<void> hardReset() async {
    await db.resetUserData();
    await taskController.load();
    await folderController.load();
    await noteController.load();
    await routineController.load();
    await eventController.load();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// For each row whose [iconColumn] is a custom image path, reads the image
  /// file, encodes it as base64 in [customIcons], and normalises the iconId
  /// to a relative path (`icons/<filename>`) for portability.
  Future<List<Map<String, dynamic>>> _inlineIcons(
    List<Map<String, dynamic>> rows,
    String iconColumn,
    String docsPath,
    Map<String, String> customIcons,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      final iconId = row[iconColumn] as String?;
      if (iconId != null && isCustomIconId(iconId)) {
        final normalized = await _exportIcon(iconId, docsPath, customIcons);
        if (normalized != null) map[iconColumn] = normalized;
      }
      result.add(map);
    }
    return result;
  }

  /// Reads the image for [iconId], stores base64 bytes in [customIcons],
  /// and returns the normalised relative key (or null if file not found).
  Future<String?> _exportIcon(
    String iconId,
    String docsPath,
    Map<String, String> customIcons,
  ) async {
    String absPath;
    String relKey;

    if (iconId.startsWith('/')) {
      // Legacy absolute path — derive relative key from basename.
      absPath = iconId;
      relKey = 'icons/${p.basename(iconId)}';
    } else if (iconId.startsWith('icons/')) {
      absPath = '$docsPath/$iconId';
      relKey = iconId;
    } else {
      return null; // SF-symbol, nothing to do
    }

    final file = File(absPath);
    if (!await file.exists()) return null;

    if (!customIcons.containsKey(relKey)) {
      customIcons[relKey] = base64Encode(await file.readAsBytes());
    }
    return relKey;
  }
}
