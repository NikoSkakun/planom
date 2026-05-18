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
import '../tasks/task_controller.dart';
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

  Future<void> exportBackup() async {
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
      'folders': folders,
      'app_lists': lists,
      'note_folders': noteFolders,
      'notes': await db.exportNotes(),
      'routines': await db.exportRoutines(),
      'routine_entries': await db.exportRoutineEntries(),
      'events': await db.exportEvents(),
      'app_settings': await db.exportAppSettings(),
      // Smart-list visibility + hideTabLabels live in a JSON file in the docs
      // directory, not the DB, so we include their raw map here.
      'smart_list_prefs': settingsController.smartListPrefs.toJson(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final name =
        'planom_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.planom';
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(json, encoding: utf8);

    await Share.shareXFiles([XFile(file.path)], subject: 'Planom Backup');
  }

  // Returns true on success, false if file was invalid or picker cancelled.
  Future<bool> importBackup() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return false;

    final path = result.files.single.path;
    if (path == null) return false;

    final content = await File(path).readAsString(encoding: utf8);

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }

    if (data['version'] != 1) return false;

    // Restore custom icon files first so DB records can reference them.
    final docsPath = (await getApplicationDocumentsDirectory()).path;
    final iconsDir = Directory('$docsPath/icons');
    if (!iconsDir.existsSync()) iconsDir.createSync(recursive: true);

    final customIcons =
        (data['customIcons'] as Map<String, dynamic>?) ?? {};
    for (final entry in customIcons.entries) {
      final relPath = entry.key; // 'icons/filename.ext'
      final bytes = base64Decode(entry.value as String);
      await File('$docsPath/$relPath').writeAsBytes(bytes);
    }

    List<Map<String, dynamic>> asMaps(dynamic value) {
      if (value == null) return [];
      return (value as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    await db.clearAllData();
    await db.importTasks(asMaps(data['tasks']));
    await db.importFolders(asMaps(data['folders']));
    await db.importLists(asMaps(data['app_lists']));
    await db.importNoteFolders(asMaps(data['note_folders']));
    await db.importNotes(asMaps(data['notes']));
    await db.importRoutines(asMaps(data['routines']));
    await db.importRoutineEntries(asMaps(data['routine_entries']));
    await db.importEvents(asMaps(data['events']));
    await db.importAppSettings(asMaps(data['app_settings']));

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
