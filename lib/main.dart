import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/database/database_service.dart';
import 'src/folders/folder_controller.dart';
import 'src/notes/note_controller.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/tasks/task_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();

  final db = DatabaseService();
  final taskController = TaskController(db);
  await taskController.load();

  final folderController = FolderController(db);
  await folderController.load();

  final noteController = NoteController(db);
  await noteController.load();

  runApp(MyApp(
    settingsController: settingsController,
    taskController: taskController,
    folderController: folderController,
    noteController: noteController,
  ));
}
