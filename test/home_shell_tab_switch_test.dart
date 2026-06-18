import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:planom/src/calendar/event_controller.dart';
import 'package:planom/src/contacts/contact_controller.dart';
import 'package:planom/src/finance/finance_controller.dart';
import 'package:planom/src/goals/goal_controller.dart';
import 'package:planom/src/folders/folder_controller.dart';
import 'package:planom/src/home_shell.dart';
import 'package:planom/src/integrations/apple/device_calendar_controller.dart';
import 'package:planom/src/integrations/google/google_calendar_controller.dart';
import 'package:planom/src/localization/app_localizations.dart';
import 'package:planom/src/models/app_folder.dart';
import 'package:planom/src/models/app_list.dart';
import 'package:planom/src/notes/note_controller.dart';
import 'package:planom/src/routines/routine_controller.dart';
import 'package:planom/src/security/security_service.dart';
import 'package:planom/src/settings/backup_service.dart';
import 'package:planom/src/settings/settings_controller.dart';
import 'package:planom/src/settings/settings_service.dart';
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

/// Regression coverage for the "tab bar frozen after resetting a tab from
/// inside a folder" bug on the wide (sidebar) layout.
///
/// Repro: open a folder in Tasks, tap Tasks again to reset/pop it, then tap a
/// different sidebar tab. The wide layout's IndexedStack is driven by
/// `_lastTabIndex` through `_buildShell`, which (before the fix) wasn't
/// rebuilt by a tab tap — so the visible tab stayed put until an unrelated
/// rebuild flushed it. This test fails (stays on Tasks) without the fix.
void main() {
  initTestDatabaseFactory();

  testWidgets('sidebar tab switch works after resetting a tab from a folder',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('planom_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() => tmp.deleteSync(recursive: true));
    // Large surface → wide sidebar layout.
    tester.view.physicalSize = const Size(1400, 1000);
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
    final finance = FinanceController(db);
    final goal = GoalController(db);
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

    // Real DB / file I/O only resolves outside the fake-async clock.
    await tester.runAsync(() async {
      await task.load();
      await folder.load();
      await note.load();
      await routine.load();
      await event.load();
      await contact.load();
      await settings.loadSettings();
      await folder.addFolder(AppFolder(id: 'f1', name: 'Work'));
      await folder.addList(AppList(id: 'l1', name: 'AlphaList', folderId: 'f1'));
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
          financeController: finance,
          goalController: goal,
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

    // Open the folder, then reset the Tasks tab (tap it again), popping back.
    await tester.tap(find.text('Work').first);
    await beat();
    expect(find.text('AlphaList'), findsWidgets, reason: 'inside the folder');

    await tester.tap(find.text('Tasks').first);
    await beat();
    expect(find.text('AlphaList'), findsNothing, reason: 'folder popped');

    // Now switch to another tab — this must take effect immediately.
    await tester.tap(find.text('Calendar').first);
    await beat();
    expect(find.text('Mon'), findsWidgets,
        reason: 'Calendar must show after tapping its sidebar tab');
    expect(find.text('Inbox'), findsNothing,
        reason: 'Tasks root must no longer be shown');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
