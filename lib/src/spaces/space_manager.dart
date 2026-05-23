import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../calendar/event_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../notes/note_controller.dart';
import '../routines/routine_controller.dart';
import '../settings/backup_service.dart';
import '../settings/settings_controller.dart';
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
  late BackupService _backupService;

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
  BackupService get backupService => _backupService;

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

  Future<void> switchSpace(String id) async {
    if (id == _activeSpaceId && _initialized) return;
    _activeSpaceId = id;
    await _saveMetadata();
    await _initControllers(id);
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

    _backupService = BackupService(
      db: _db,
      taskController: _taskController,
      folderController: _folderController,
      noteController: _noteController,
      routineController: _routineController,
      eventController: _eventController,
      settingsController: settingsController,
    );

    _initialized = true;
  }

  static const _metaFile = 'spaces.json';

  Future<void> _loadMetadata() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_metaFile');
    if (!file.existsSync()) {
      _spaces = [
        Space(id: 'default', name: 'Personal', creationDate: DateTime.now()),
      ];
      _activeSpaceId = 'default';
      await _saveMetadata();
      return;
    }
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    _activeSpaceId = data['activeSpaceId'] as String? ?? 'default';
    _spaces = (data['spaces'] as List<dynamic>)
        .map((e) => Space.fromJson(e as Map<String, dynamic>))
        .toList();
    if (_spaces.isEmpty) {
      _spaces = [
        Space(id: 'default', name: 'Personal', creationDate: DateTime.now()),
      ];
      _activeSpaceId = 'default';
    }
  }

  Future<void> _saveMetadata() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_metaFile');
    await file.writeAsString(jsonEncode({
      'activeSpaceId': _activeSpaceId,
      'spaces': _spaces.map((s) => s.toJson()).toList(),
    }));
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

  @override
  bool updateShouldNotify(SpaceManagerProvider old) =>
      spaceManager != old.spaceManager;
}
