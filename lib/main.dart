import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'src/app.dart';
import 'src/database/database_service.dart';
import 'src/folders/folder_icon_picker.dart';
import 'src/integrations/apple/device_calendar_controller.dart';
import 'src/integrations/google/google_calendar_controller.dart';
import 'src/notifications/notification_service.dart';
import 'src/security/security_service.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/spaces/space_manager.dart';
import 'src/theme/app_background.dart';
import 'src/utils/platform_capabilities.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Swap in the FFI factory (backed by the SQLite the `sqlite3` package bundles,
  // built with FTS5) before any controller opens a database. Linux/Windows have
  // no native sqflite backend; Android has one but its system SQLite often lacks
  // the FTS5 module search needs, so it uses the bundled SQLite too. iOS/macOS
  // use the native plugin. See PlatformCapabilities.sqfliteNeedsFfi.
  if (PlatformCapabilities.sqfliteNeedsFfi) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (PlatformCapabilities.supportsOrientationLock) {
    // Landscape is temporarily disabled — portrait only on phone/tablet for now.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // These four inits are independent (two cache the documents dir, one loads
  // the timezone db, one sets up the notification plugin), so run them
  // concurrently to shorten startup. Behaviour is identical to awaiting each
  // in turn — they share no state and none reads another's result.
  await Future.wait([
    initFolderIconService(),
    initBackgroundService(),
    NotificationService.initTimezone(),
    NotificationService.instance.init(),
  ]);

  // Shared planom.db handle: holds app_settings (tab visibility, appearance,
  // passcode) read by SettingsController/SecurityService, and is reused as the
  // default space's data DB. Non-default spaces use their own DB files. One
  // handle per file — never open planom.db twice.
  final globalDb = DatabaseService();

  final settingsController = SettingsController(SettingsService(), globalDb);
  await settingsController.loadSettings();

  final securityService = SecurityService(globalDb);
  await securityService.load();

  // Google Calendar integration is global (lives outside any space) so the
  // same connection appears in every space. Initialisation is best-effort —
  // a missing client ID or offline state just leaves the controller in its
  // disconnected default and the rest of the app continues to work.
  final googleCalendarController =
      GoogleCalendarController(db: globalDb);
  await googleCalendarController.load();

  // Native Apple Calendar (EventKit) integration — also global, iOS/macOS only.
  // Off those platforms `load()` is a no-op and the controller stays inert.
  final deviceCalendarController =
      DeviceCalendarController(db: globalDb);
  await deviceCalendarController.load();

  final spaceManager =
      SpaceManager(settingsController: settingsController, globalDb: globalDb);
  await spaceManager.load();

  runApp(
    ListenableBuilder(
      listenable: spaceManager,
      builder: (context, _) => SpaceManagerProvider(
        spaceManager: spaceManager,
        child: MyApp(
          // New key on every space switch forces a full widget-tree rebuild,
          // giving each space a completely fresh navigator + scroll state.
          key: ValueKey(spaceManager.activeSpaceId),
          settingsController: settingsController,
          taskController: spaceManager.taskController,
          folderController: spaceManager.folderController,
          noteController: spaceManager.noteController,
          routineController: spaceManager.routineController,
          eventController: spaceManager.eventController,
          contactController: spaceManager.contactController,
          financeController: spaceManager.financeController,
          goalController: spaceManager.goalController,
          backupService: spaceManager.backupService,
          securityService: securityService,
          googleCalendarController: googleCalendarController,
          deviceCalendarController: deviceCalendarController,
        ),
      ),
    ),
  );
}
