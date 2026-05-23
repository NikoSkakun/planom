import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/database/database_service.dart';
import 'src/folders/folder_icon_picker.dart';
import 'src/notifications/notification_service.dart';
import 'src/security/security_service.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/spaces/space_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initFolderIconService();
  await NotificationService.initTimezone();
  await NotificationService.instance.init();

  // Global DB — only for app_settings (tab visibility, etc.) via
  // SettingsController. Per-space data lives in space-specific DB files.
  final globalDb = DatabaseService();

  final settingsController = SettingsController(SettingsService(), globalDb);
  await settingsController.loadSettings();

  final securityService = SecurityService(globalDb);
  await securityService.load();

  final spaceManager = SpaceManager(settingsController: settingsController);
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
