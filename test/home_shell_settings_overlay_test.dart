import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:planom/src/calendar/event_controller.dart';
import 'package:planom/src/contacts/contact_controller.dart';
import 'package:planom/src/folders/folder_controller.dart';
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
import 'package:planom/src/settings/settings_view.dart';
import 'package:planom/src/spaces/space_manager.dart';
import 'package:planom/src/tasks/task_controller.dart';

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

/// Regression coverage for hiding the Settings tab while the user is inside
/// Settings. The Settings content must stay put (no full-screen transition
/// that covers the bar), the tab bar / sidebar must remain visible, and
/// leaving Settings must work.
///
/// Tests run on the Linux VM, where `PlatformCapabilities.isDesktop` is true,
/// so the shell always uses the wide sidebar layout. The same overlay
/// mechanism drives both layouts; here we exercise the sidebar path.
void main() {
  initTestDatabaseFactory();

  testWidgets('hiding the Settings tab while in it keeps the sidebar and the '
      'Settings content', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('planom_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() => tmp.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = freshDb();
    final task = TaskController(db);
    final folder = FolderController(db);
    final note = NoteController(db);
    final routine = RoutineController(db);
    final event = EventController(db);
    final contact = ContactController(db);
    final settings = SettingsController(SettingsService(), db);
    final backup = BackupService(
      db: db,
      taskController: task,
      folderController: folder,
      noteController: note,
      routineController: routine,
      eventController: event,
      contactController: contact,
      settingsController: settings,
    );
    final sm = SpaceManager(settingsController: settings, globalDb: db);

    await tester.runAsync(() async {
      await task.load();
      await folder.load();
      await note.load();
      await routine.load();
      await event.load();
      await contact.load();
      await settings.loadSettings();
      await sm.load();
    });

    await tester.pumpWidget(CupertinoApp(
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
          backupService: backup,
          securityService: SecurityService(db),
          googleCalendarController: GoogleCalendarController(db: db),
          deviceCalendarController: DeviceCalendarController(db: db),
        ),
      ),
    ));

    Future<void> beat() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await beat();
    expect(find.text('Inbox'), findsWidgets, reason: 'Tasks root visible');

    // Open Settings from the sidebar.
    await tester.tap(find.text('Settings').first);
    await beat();
    expect(find.byType(SettingsView), findsOneWidget,
        reason: 'Settings is active');
    // "Settings" now appears twice: the sidebar tile + the page title.
    expect(find.text('Settings'), findsNWidgets(2));

    // Now hide the Settings tab from within Settings (Settings is item 4 on
    // page 0 of the default layout).
    await tester.runAsync(() => settings.updateTabBarConfig(
        settings.tabBarConfig.setItemEnabled(0, 4, false)));
    await beat();

    // Settings content stays on screen — exactly one SettingsView (no
    // duplicate from a botched reparent), no full-screen route.
    expect(find.byType(SettingsView), findsOneWidget,
        reason: 'still inside Settings (single instance) after hiding its tab');
    // The sidebar is still there with the remaining tabs.
    expect(find.text('Tasks'), findsWidgets,
        reason: 'sidebar must remain visible');
    expect(find.text('Routines'), findsWidgets,
        reason: 'remaining tabs still in the sidebar');

    // Leave Settings via its close button → returns to the underlying tab.
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await beat();
    expect(find.byType(SettingsView), findsNothing,
        reason: 'closed the Settings overlay');
    expect(find.text('Inbox'), findsWidgets,
        reason: 'back on the fallback (Tasks) tab');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('opening Settings from a tab keeps the sidebar and returns on '
      'close', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('planom_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() => tmp.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = freshDb();
    final task = TaskController(db);
    final folder = FolderController(db);
    final note = NoteController(db);
    final routine = RoutineController(db);
    final event = EventController(db);
    final contact = ContactController(db);
    final settings = SettingsController(SettingsService(), db);
    final backup = BackupService(
      db: db,
      taskController: task,
      folderController: folder,
      noteController: note,
      routineController: routine,
      eventController: event,
      contactController: contact,
      settingsController: settings,
    );
    final sm = SpaceManager(settingsController: settings, globalDb: db);

    await tester.runAsync(() async {
      await task.load();
      await folder.load();
      await note.load();
      await routine.load();
      await event.load();
      await contact.load();
      await settings.loadSettings();
      // Hide the Settings tab up front so it's reached only via the overlay.
      await settings.updateTabBarConfig(
          settings.tabBarConfig.setItemEnabled(0, 4, false));
      await sm.load();
    });

    await tester.pumpWidget(CupertinoApp(
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
          backupService: backup,
          securityService: SecurityService(db),
          googleCalendarController: GoogleCalendarController(db: db),
          deviceCalendarController: DeviceCalendarController(db: db),
        ),
      ),
    ));

    Future<void> beat() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await beat();
    expect(find.text('Inbox'), findsWidgets);
    expect(find.byType(SettingsView), findsNothing,
        reason: 'Settings tab hidden, overlay not open');

    // Open Settings via the global overlay (as the tab ⋯ menu does).
    // openGlobalSettings searches ancestors, so pass a context below
    // HomeShell.
    HomeShell.openGlobalSettings(tester.element(find.text('Inbox').first));
    await beat();
    expect(find.byType(SettingsView), findsOneWidget,
        reason: 'Settings overlay opened');
    // Sidebar still shows the underlying tabs.
    expect(find.text('Tasks'), findsWidgets,
        reason: 'sidebar stays visible behind the overlay');

    // Close → back to the Tasks tab.
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await beat();
    expect(find.byType(SettingsView), findsNothing);
    expect(find.text('Inbox'), findsWidgets);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
