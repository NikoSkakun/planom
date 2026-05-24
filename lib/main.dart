import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'src/app.dart';
import 'src/database/database_service.dart';
import 'src/folders/folder_icon_picker.dart';
import 'src/notifications/notification_service.dart';
import 'src/security/security_service.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/spaces/space_manager.dart';
import 'src/utils/platform_capabilities.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Linux/Windows have no native sqflite backend; swap in the FFI factory
  // before any controller opens a database. macOS uses the native plugin.
  if (PlatformCapabilities.sqfliteNeedsFfi) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (PlatformCapabilities.supportsOrientationLock) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      // iPad opens to a sidebar+detail layout in HomeShell; allowing landscape
      // here lets users actually use that extra room. Phone bottom-tab layout
      // still works in landscape too.
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  await initFolderIconService();
  await NotificationService.initTimezone();
  await NotificationService.instance.init();

  // Shared planom.db handle: holds app_settings (tab visibility, appearance,
  // passcode) read by SettingsController/SecurityService, and is reused as the
  // default space's data DB. Non-default spaces use their own DB files. One
  // handle per file — never open planom.db twice.
  final globalDb = DatabaseService();

  final settingsController = SettingsController(SettingsService(), globalDb);
  await settingsController.loadSettings();

  final securityService = SecurityService(globalDb);
  await securityService.load();

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
          backupService: spaceManager.backupService,
          securityService: securityService,
        ),
      ),
    ),
  );
}
