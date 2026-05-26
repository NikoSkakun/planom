import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../calendar/event_controller.dart';
import '../contacts/contact_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../notes/note_controller.dart';
import '../routines/routine_controller.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
import '../sync/sync_controller.dart';
import '../tasks/task_controller.dart';
import 'space.dart';

class SpaceManager with ChangeNotifier {
  SpaceManager({required this.settingsController, required this.globalDb});

  final SettingsController settingsController;

  /// The shared `planom.db` handle (also used by SettingsController and
  /// SecurityService). The default space reuses this exact instance instead of
  /// opening a second handle to the same file.
  final DatabaseService globalDb;

  List<Space> _spaces = [];
  String _activeSpaceId = 'default';
  String? _prevSpaceId;
  bool _initialized = false;

  late DatabaseService _db;
  late TaskController _taskController;
  late FolderController _folderController;
  late NoteController _noteController;
  late RoutineController _routineController;
  late EventController _eventController;
  late ContactController _contactController;
  late BackupService _backupService;
  late SyncController _syncController;

  List<Space> get spaces => List.unmodifiable(_spaces);
  String get activeSpaceId => _activeSpaceId;
  Space get activeSpace => _spaces.firstWhere(
        (s) => s.id == _activeSpaceId,
        orElse: () => _spaces.first,
      );

  TaskController get taskController => _taskController;
  FolderController get folderController => _folderController;
  NoteController get noteController => _noteController;
  RoutineController get routineController => _routineController;
  EventController get eventController => _eventController;
  ContactController get contactController => _contactController;
  BackupService get backupService => _backupService;
  SyncController get syncController => _syncController;
  // Exposed for features (e.g. search) that need to query the active space's
  // DB directly. Always the current space's handle — re-grabbed by widgets
  // each time the active space switches because MyApp is keyed by space id.
  DatabaseService get db => _db;

  Future<void> load() async {
    await _loadMetadata();
    await _initControllers(_activeSpaceId);
  }

  Future<void> addSpace(String name) async {
    final id = const Uuid().v4();
    _spaces.add(Space(id: id, name: name, creationDate: DateTime.now()));
    await _saveMetadata();
    await switchSpace(id);
  }

  Future<void> renameSpace(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final index = _spaces.indexWhere((s) => s.id == id);
    if (index < 0) return;
    if (_spaces[index].name == trimmed) return;
    _spaces[index] = _spaces[index].copyWith(name: trimmed);
    await _saveMetadata();
    notifyListeners();
  }

  Future<void> switchSpace(String id) async {
    if (id == _activeSpaceId && _initialized) return;
    _activeSpaceId = id;
    await _saveMetadata();
    await _initControllers(id);
    notifyListeners();
  }

  /// Permanently deletes a space and its database file. The default space can
  /// never be deleted and at least one space always remains. If the deleted
  /// space is active, the default space becomes active first so we don't remove
  /// a database that's currently open.
  Future<void> deleteSpace(String id) async {
    if (id == 'default') return;
    if (_spaces.length <= 1) return;
    if (!_spaces.any((s) => s.id == id)) return;

    if (id == _activeSpaceId) {
      await switchSpace('default');
    }

    _spaces = _spaces.where((s) => s.id != id).toList();
    await _saveMetadata();

    final dbPath = await getDatabasesPath();
    try {
      await deleteDatabase(join(dbPath, 'planom_$id.db'));
    } catch (_) {
      // File may not exist (space never opened); deletion is best-effort.
    }

    notifyListeners();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _initControllers(String spaceId) async {
    // Close previous DB unless it was the default space — its handle is the
    // shared globalDb, still referenced by SettingsController/SecurityService.
    if (_initialized && _prevSpaceId != null && _prevSpaceId != 'default') {
      await _db.close();
    }
    _prevSpaceId = spaceId;

    // The default space shares the global handle; only non-default spaces get
    // their own DatabaseService, so a single file is never opened twice.
    _db = spaceId == 'default'
        ? globalDb
        : DatabaseService(dbName: 'planom_$spaceId.db');

    _taskController = TaskController(_db);
    await _taskController.load();

    _folderController = FolderController(_db);
    await _folderController.load();

    _noteController = NoteController(_db);
    await _noteController.load();

    _routineController = RoutineController(_db);
    await _routineController.load();

    _eventController = EventController(_db);
    await _eventController.load();

    _contactController = ContactController(_db);
    await _contactController.load();

    _backupService = BackupService(
      db: _db,
      taskController: _taskController,
      folderController: _folderController,
      noteController: _noteController,
      routineController: _routineController,
      eventController: _eventController,
      contactController: _contactController,
      settingsController: settingsController,
    );

    _syncController = SyncController(
      db: _db,
      backupService: _backupService,
    );
    await _syncController.load();

    _initialized = true;
  }

  static const _metaFile = 'spaces.json';

  Future<void> _loadMetadata() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_metaFile');
    if (file.existsSync()) {
      try {
        final data =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _spaces = (data['spaces'] as List<dynamic>)
            .map((e) => Space.fromJson(e as Map<String, dynamic>))
            .toList();
        _activeSpaceId = data['activeSpaceId'] as String? ?? 'default';
      } catch (_) {
        // Corrupt or partially-written metadata: fall back to a clean default
        // rather than throwing on launch. Existing space DB files are intact.
        _spaces = [];
        _activeSpaceId = 'default';
      }
    }

    // Self-heal into a consistent state: a default space must always exist and
    // the active id must point at a real space.
    if (!_spaces.any((s) => s.id == 'default')) {
      _spaces.insert(
        0,
        Space(id: 'default', name: 'Personal', creationDate: DateTime.now()),
      );
    }
    if (!_spaces.any((s) => s.id == _activeSpaceId)) {
      _activeSpaceId = 'default';
    }
    await _saveMetadata();
  }

  Future<void> _saveMetadata() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_metaFile');
    final tmp = File('${dir.path}/$_metaFile.tmp');
    final json = jsonEncode({
      'activeSpaceId': _activeSpaceId,
      'spaces': _spaces.map((s) => s.toJson()).toList(),
    });
    // Write to a temp file then atomically rename, so a crash mid-write can
    // never leave a half-written spaces.json that bricks the next launch.
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
  }
}

// Makes SpaceManager accessible anywhere in the tree without prop-drilling.
class SpaceManagerProvider extends InheritedWidget {
  const SpaceManagerProvider({
    super.key,
    required this.spaceManager,
    required super.child,
  });

  final SpaceManager spaceManager;

  static SpaceManager of(BuildContext context) {
    final p =
        context.dependOnInheritedWidgetOfExactType<SpaceManagerProvider>();
    assert(p != null, 'SpaceManagerProvider not found in context');
    return p!.spaceManager;
  }

  static SpaceManager? maybeOf(BuildContext context) {
    final p =
        context.dependOnInheritedWidgetOfExactType<SpaceManagerProvider>();
    return p?.spaceManager;
  }

  @override
  bool updateShouldNotify(SpaceManagerProvider old) =>
      spaceManager != old.spaceManager;
}
