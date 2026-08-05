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
import '../finance/finance_controller.dart';
import '../folders/folder_controller.dart';
import '../goals/goal_controller.dart';
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
  late FinanceController _financeController;
  late GoalController _goalController;
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
  FinanceController get financeController => _financeController;
  GoalController get goalController => _goalController;
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

  /// Returns the on-disk filename for [spaceId]. The default space lives in
  /// `planom.db`; all others live in `planom_<id>.db`. Used by storage
  /// analysis to size every space, not just the active one.
  String dbNameFor(String spaceId) =>
      spaceId == 'default' ? 'planom.db' : 'planom_$spaceId.db';

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
    // Drop the space's own settings (its tab bar layout) along with its data,
    // so nothing lingers and a later space reusing the id starts clean.
    await settingsController.forgetSpaceSettings(id);

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
    // Point the settings at this space before anything reads them: the tab bar
    // layout is per space, and the shell builds its bar from
    // `settingsController.tabBarConfig` as soon as the controllers are ready.
    settingsController.setActiveSpace(spaceId);
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

    // The controller loads are mutually independent (each reads its own
    // tables; the badge wiring below runs only after all have loaded), so kick
    // them off together. They share one DB connection so queries still
    // serialise at the SQLite layer, but this removes the per-controller await
    // round-trips and overlaps their work.
    _taskController = TaskController(_db);
    _folderController = FolderController(_db);
    _noteController = NoteController(_db);
    _routineController = RoutineController(_db);
    _eventController = EventController(_db);
    _contactController = ContactController(_db);
    _financeController = FinanceController(_db);
    // Goals resolve their tasks through the task + folder controllers, so the
    // controller is built with them (its own load only reads the goals table,
    // so it can still run in the same batch).
    _goalController = GoalController(
      _db,
      taskController: _taskController,
      folderController: _folderController,
    );
    await Future.wait([
      _taskController.load(),
      _folderController.load(),
      _noteController.load(),
      _routineController.load(),
      _eventController.load(),
      _contactController.load(),
      _financeController.load(),
      _goalController.load(),
    ]);

    // Wire the badge to the global settings + current space's events.
    // Counting "not-yet-started events today" gives the user a sense of
    // upcoming items; we include any timed event whose start moment is in
    // the future today, plus all all-day events.
    _taskController.attachBadgeContext(
      settings: settingsController,
      eventCountToday: () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        return _eventController.eventsForDate(today).where((e) {
          if (e.doTime == null) return true; // all-day
          final start =
              today.add(Duration(minutes: e.doTime!));
          return start.isAfter(now);
        }).length;
      },
      routineCountToday: () => _routineController.todayUncompletedCount,
      listIdsInFolder: (folderId) =>
          _folderController.listIdsInRecursive(folderId),
    );
    // EventController / RoutineController changes don't drive the badge
    // automatically — pump it when they change so the count stays current.
    _eventController.addListener(_taskController.refreshBadge);
    _routineController.addListener(_taskController.refreshBadge);
    // Folder/list structure changes can shift custom-badge folder counts.
    _folderController.addListener(_taskController.refreshBadge);

    _backupService = BackupService(
      db: _db,
      taskController: _taskController,
      folderController: _folderController,
      noteController: _noteController,
      routineController: _routineController,
      eventController: _eventController,
      contactController: _contactController,
      financeController: _financeController,
      goalController: _goalController,
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
