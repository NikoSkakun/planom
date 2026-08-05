import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:planom/src/calendar/event_controller.dart';
import 'package:planom/src/contacts/contact_controller.dart';
import 'package:planom/src/database/database_service.dart';
import 'package:planom/src/finance/finance_controller.dart';
import 'package:planom/src/folders/folder_controller.dart';
import 'package:planom/src/goals/goal_controller.dart';
import 'package:planom/src/home_shell.dart';
import 'package:planom/src/integrations/apple/device_calendar_controller.dart';
import 'package:planom/src/integrations/google/google_calendar_controller.dart';
import 'package:planom/src/localization/app_localizations.dart';
import 'package:planom/src/notes/note_controller.dart';
import 'package:planom/src/routines/routine_controller.dart';
import 'package:planom/src/security/security_service.dart';
import 'package:planom/src/settings/backup_service.dart';
import 'package:planom/src/settings/settings_controller.dart';
import 'package:planom/src/settings/settings_service.dart';
import 'package:planom/src/settings/tab_bar_config.dart';
import 'package:planom/src/spaces/space.dart';
import 'package:planom/src/spaces/space_manager.dart';
import 'package:planom/src/spaces/space_switch_transition.dart';
import 'package:planom/src/tasks/task_controller.dart';
import 'package:planom/src/utils/platform_capabilities.dart';

import 'support/test_db.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
  @override
  Future<String?> getLibraryPath() async => dir;
}

/// Boots the shell the way an iPhone does — narrow screen, bottom tab bar.
///
/// Every other shell test runs on the Linux VM, where `isDesktop` is true and
/// the shell builds the iPad sidebar instead, so the tab-bar layout that every
/// phone user actually sees had no coverage at all.
void main() {
  initTestDatabaseFactory();

  Future<Widget> bootShell(WidgetTester tester, DatabaseService db,
      {SpaceManager? manager, bool withTransition = false}) async {
    final task = TaskController(db);
    final folder = FolderController(db);
    final note = NoteController(db);
    final routine = RoutineController(db);
    final event = EventController(db);
    final contact = ContactController(db);
    final finance = FinanceController(db);
    final goals =
        GoalController(db, taskController: task, folderController: folder);
    final settings = SettingsController(SettingsService(), db);
    final backup = BackupService(
      db: db,
      taskController: task,
      folderController: folder,
      noteController: note,
      routineController: routine,
      eventController: event,
      contactController: contact,
      financeController: finance,
      goalController: goals,
      settingsController: settings,
    );
    final sm = manager ?? SpaceManager(settingsController: settings, globalDb: db);

    await tester.runAsync(() async {
      await task.load();
      await folder.load();
      await note.load();
      await routine.load();
      await event.load();
      await contact.load();
      await finance.load();
      await goals.load();
      await settings.loadSettings();
      await sm.load();
    });

    Widget wrap(Widget app) =>
        withTransition ? SpaceSwitchTransition(child: app) : app;

    return wrap(CupertinoApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: SpaceManagerProvider(
        spaceManager: sm,
        child: HomeShell(
          settingsController: settings,
          taskController: task,
          folderController: folder,
          noteController: note,
          routineController: routine,
          eventController: event,
          contactController: contact,
          financeController: finance,
          goalController: goals,
          backupService: backup,
          securityService: SecurityService(db),
          googleCalendarController: GoogleCalendarController(db: db),
          deviceCalendarController: DeviceCalendarController(db: db),
        ),
      ),
    ));
  }

  setUp(() {
    PlatformCapabilities.debugIsDesktopOverride = false;
  });

  tearDown(() {
    PlatformCapabilities.debugIsDesktopOverride = null;
  });

  testWidgets('the shell renders on a phone-sized screen', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('planom_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() => tmp.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await bootShell(tester, freshDb()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CupertinoTabScaffold), findsOneWidget);
    expect(find.text('Tasks'), findsWidgets);
  });

  testWidgets('the shell renders on a phone after a v37 database upgrades',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('planom_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() => tmp.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // A complete, previous-release database: build today's schema, then wind
    // the parts v38 added back to their v37 shape. Reopening it runs the real
    // upgrade against a full database rather than a stub — which is what an
    // updating user's phone actually does on first launch.
    final name = 'phone_boot_${DateTime.now().microsecondsSinceEpoch}.db';
    await tester.runAsync(() async {
      final seeded = DatabaseService(dbName: name);
      await seeded.getTasks(); // opens + creates at the current version
      await seeded.close();

      final dir = await databaseFactory.getDatabasesPath();
      final raw = await databaseFactory.openDatabase(p.join(dir, name));
      await raw.execute('DROP TABLE IF EXISTS goals');
      await raw.execute('DROP TABLE IF EXISTS finance_accounts');
      await raw.execute('DROP TABLE IF EXISTS finance_transactions');
      await raw.execute('''
        CREATE TABLE finance_transactions (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          amount INTEGER NOT NULL DEFAULT 0,
          type TEXT NOT NULL DEFAULT 'expense',
          categoryId TEXT,
          date INTEGER NOT NULL,
          note TEXT,
          creationDate INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await raw.execute('PRAGMA user_version = 37');
      await raw.close();
    });

    await tester.pumpWidget(await bootShell(tester, DatabaseService(dbName: name)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CupertinoTabScaffold), findsOneWidget);
  });

  testWidgets('swiping the tab bar moves the screen and switches Space',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('planom_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() => tmp.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = freshDb();
    final settings = SettingsController(SettingsService(), db);
    final manager = SpaceManager(settingsController: settings, globalDb: db);
    await tester.runAsync(() async {
      await settings.loadSettings();
      await settings.updateTabBarSwipeMode(TabBarSwipeMode.spaces);
      await manager.load();
      await manager.addSpace('Work');
      // addSpace switches to the new space; go back so there is one on
      // either side of us to swipe to.
      await manager.switchSpace(kDefaultSpaceId);
    });
    expect(manager.spaces.length, 2);

    await tester.pumpWidget(
        await bootShell(tester, db, manager: manager, withTransition: true));
    await tester.pumpAndSettle();

    final transition = tester.state<SpaceSwitchTransitionState>(
        find.byType(SpaceSwitchTransition));
    expect(transition.debugIsMoving, isFalse);

    // Drag left across the tab bar. The moves are incremental on purpose: the
    // first one is swallowed by the drag being recognised (touch slop), so a
    // single jump would never produce an update.
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(CupertinoTabBar)));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(-25, 0));
      await tester.pump();
    }
    expect(transition.debugIsMoving, isTrue,
        reason: 'the space moves with the finger');
    expect(transition.debugOffset, lessThan(0));

    // Carry it past the commit threshold and let go.
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(-25, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(manager.activeSpaceId, isNot(kDefaultSpaceId),
        reason: 'a committed swipe changes Space');
  });
}
