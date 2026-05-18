import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/calendar/event_controller.dart';
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

  final db = DatabaseService();

  final settingsController = SettingsController(SettingsService(), db);
  await settingsController.loadSettings();
  final taskController = TaskController(db);
  await taskController.load();

  final folderController = FolderController(db);
  await folderController.load();

  final noteController = NoteController(db);
  await noteController.load();

  final routineController = RoutineController(db);
  await routineController.load();

  final eventController = EventController(db);
  await eventController.load();

  final backupService = BackupService(
    db: db,
    taskController: taskController,
    folderController: folderController,
    noteController: noteController,
    routineController: routineController,
    eventController: eventController,
    settingsController: settingsController,
  );

  runApp(MyApp(
    settingsController: settingsController,
    taskController: taskController,
    folderController: folderController,
    noteController: noteController,
    routineController: routineController,
    eventController: eventController,
    backupService: backupService,
  ));
}
