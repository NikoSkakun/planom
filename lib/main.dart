import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/database/database_service.dart';
import 'src/folders/folder_controller.dart';
import 'src/folders/folder_icon_picker.dart';
import 'src/notes/note_controller.dart';
import 'src/routines/routine_controller.dart';
import 'src/settings/backup_service.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/tasks/task_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initFolderIconService();

  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();

  final db = DatabaseService();
  final taskController = TaskController(db);
  await taskController.load();

  final folderController = FolderController(db);
  await folderController.load();

  final noteController = NoteController(db);
  await noteController.load();

  final routineController = RoutineController(db);
  await routineController.load();

  final backupService = BackupService(
    db: db,
    taskController: taskController,
    folderController: folderController,
    noteController: noteController,
    routineController: routineController,
  );

  runApp(MyApp(
    settingsController: settingsController,
    taskController: taskController,
    folderController: folderController,
    noteController: noteController,
    routineController: routineController,
    backupService: backupService,
  ));
}
