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

/// End-to-end coverage for Split Screen mode: entering it shows both the Tasks
/// and Calendar content at once, and a window's ✕ button collapses back to the
/// other tab.
void main() {
  initTestDatabaseFactory();

  testWidgets('split screen shows both panes; closing one collapses to the other',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('planom_split_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() => tmp.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(420, 880);
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
    expect(find.text('Mon'), findsNothing,
        reason: 'Calendar not visible before split');

    // Enter split (Tasks host on top, Calendar below) via the public API.
    final ctx = tester.element(find.text('Inbox').first);
    HomeShell.enterSplitScreen(ctx, withTab: 2);
    await beat();

    // Both panes render simultaneously.
    expect(find.text('Inbox'), findsWidgets, reason: 'Tasks pane present');
    expect(find.text('Mon'), findsWidgets, reason: 'Calendar pane present');
    // Two pane headers → two close buttons.
    expect(find.byIcon(CupertinoIcons.xmark), findsNWidgets(2));

    // Close the top (Tasks) window → collapse to Calendar.
    await tester.tap(find.byIcon(CupertinoIcons.xmark).first);
    await beat();
    expect(find.text('Mon'), findsWidgets, reason: 'Calendar remains full-screen');
    expect(find.byIcon(CupertinoIcons.xmark), findsNothing,
        reason: 'split headers gone after exiting');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
