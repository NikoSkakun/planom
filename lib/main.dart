import 'dart:async';

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
import 'src/startup.dart';
import 'src/theme/app_background.dart';
import 'src/utils/platform_capabilities.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A build failure anywhere in the tree otherwise paints Flutter's release
  // placeholder — a featureless light-grey rectangle that is impossible to
  // tell apart from a blank app.
  installReadableErrorWidget();
  _startup();
}

/// Boots the app. Split out of [main] so a failure can be reported on screen
/// and retried, instead of leaving the platform on its launch surface — which
/// is what "the app opens to a white screen" actually is.
Future<void> _startup() async {
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
    await runOptionalStartupStep(
      'locking orientation',
      () => SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );
  }

  // These four inits are independent (two cache the documents dir, one loads
  // the timezone db, one sets up the notification plugin), so run them
  // concurrently to shorten startup. Each is wrapped on its own: none of them
  // is worth failing to launch over, and a plugin that never answers its
  // platform channel must not hold the first frame hostage either.
  await Future.wait([
    runOptionalStartupStep('preparing icons', initFolderIconService),
    runOptionalStartupStep('preparing backgrounds', initBackgroundService),
    runOptionalStartupStep('loading time zones', NotificationService.initTimezone),
    runOptionalStartupStep(
        'starting notifications', NotificationService.instance.init),
  ]);

  // Shared planom.db handle: holds app_settings (tab visibility, appearance,
  // passcode) read by SettingsController/SecurityService, and is reused as the
  // default space's data DB. Non-default spaces use their own DB files. One
  // handle per file — never open planom.db twice.
  final globalDb = DatabaseService();

  final settingsController = SettingsController(SettingsService(), globalDb);
  final securityService = SecurityService(globalDb);
  final googleCalendarController = GoogleCalendarController(db: globalDb);
  final deviceCalendarController = DeviceCalendarController(db: globalDb);
  final spaceManager =
      SpaceManager(settingsController: settingsController, globalDb: globalDb);

  // The steps the app cannot run without: reading settings (which is also what
  // opens and migrates the database) and building the active space. A failure
  // here is reported on screen with its stack, and can be retried.
  var stage = 'reading your settings';
  try {
    await settingsController.loadSettings();
    stage = 'checking the app lock';
    await securityService.load();
    stage = 'opening your spaces';
    await spaceManager.load();
  } catch (error, stack) {
    debugPrint('Planom startup failed while $stage: $error\n$stack');
    runApp(StartupErrorApp(
      label: stage,
      error: error,
      stack: stack,
      onRetry: _startup,
    ));
    return;
  }

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

  // Both calendar integrations are best-effort and, crucially, slow in ways the
  // app has no control over: Google's silent sign-in makes a network call and
  // EventKit can block on a permission prompt. Awaiting either before runApp
  // means a stalled call shows as a launch that never finishes. They run after
  // the first frame instead and repaint the calendar through their listeners
  // when they land — an expired token or an offline device just leaves them
  // disconnected.
  unawaited(runOptionalStartupStep(
    'connecting Google Calendar',
    googleCalendarController.load,
    timeout: const Duration(seconds: 30),
  ));
  unawaited(runOptionalStartupStep(
    'reading the device calendar',
    deviceCalendarController.load,
    timeout: const Duration(seconds: 30),
  ));
}
