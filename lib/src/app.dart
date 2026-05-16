import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'folders/folder_controller.dart';
import 'home_shell.dart';
import 'notes/note_controller.dart';
import 'routines/routine_controller.dart';
import 'settings/backup_service.dart';
import 'settings/settings_controller.dart';
import 'tasks/task_controller.dart';
import 'utils/fast_route.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settingsController,
    required this.taskController,
    required this.folderController,
    required this.noteController,
    required this.routineController,
    required this.backupService,
  });

  final SettingsController settingsController;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final RoutineController routineController;
  final BackupService backupService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        final brightness = switch (settingsController.themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          _ => null,
        };
        return CupertinoApp(
          restorationScopeId: 'app',
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', '')],
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          theme: CupertinoThemeData(
            brightness: brightness,
            barBackgroundColor: CupertinoColors.systemBackground,
          ),
          onGenerateRoute: (settings) => FastRoute<void>(
            settings: settings,
            builder: (context) => HomeShell(
              settingsController: settingsController,
              taskController: taskController,
              folderController: folderController,
              noteController: noteController,
              routineController: routineController,
              backupService: backupService,
            ),
          ),
        );
      },
    );
  }
}
