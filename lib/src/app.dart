import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'calendar/event_controller.dart';
import 'folders/folder_controller.dart';
import 'integrations/google/google_calendar_controller.dart';
import 'localization/app_localizations.dart';
import 'home_shell.dart';
import 'notes/note_controller.dart';
import 'routines/routine_controller.dart';
import 'security/lock_screen.dart';
import 'security/security_service.dart';
import 'settings/backup_service.dart';
import 'settings/settings_controller.dart';
import 'tasks/task_controller.dart';
import 'theme/app_fonts.dart';
import 'utils/fast_route.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settingsController,
    required this.taskController,
    required this.folderController,
    required this.noteController,
    required this.routineController,
    required this.eventController,
    required this.backupService,
    this.securityService,
    required this.googleCalendarController,
  });

  final SettingsController settingsController;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final RoutineController routineController;
  final EventController eventController;
  final BackupService backupService;
  final SecurityService? securityService;
  final GoogleCalendarController googleCalendarController;

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
          locale: settingsController.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          theme: CupertinoThemeData(
            brightness: brightness,
            barBackgroundColor: CupertinoColors.systemBackground,
            textTheme: buildCupertinoTextTheme(settingsController.fontKey),
          ),
          onGenerateRoute: (settings) => FastRoute<void>(
            settings: settings,
            // Accent/completion color changes bump colorRevision (not the main
            // settings notifier), so they rebuild only this content subtree
            // instead of the whole CupertinoApp above.
            builder: (context) => ValueListenableBuilder<int>(
              valueListenable: settingsController.colorRevision,
              builder: (context, _, __) => _SecurityGate(
                securityService: securityService,
                child: HomeShell(
                  settingsController: settingsController,
                  taskController: taskController,
                  folderController: folderController,
                  noteController: noteController,
                  routineController: routineController,
                  eventController: eventController,
                  backupService: backupService,
                  securityService: securityService,
                  googleCalendarController: googleCalendarController,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SecurityGate extends StatefulWidget {
  const _SecurityGate({required this.securityService, required this.child});

  final SecurityService? securityService;
  final Widget child;

  @override
  State<_SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends State<_SecurityGate>
    with WidgetsBindingObserver {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _locked = widget.securityService?.isLocked ?? false;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (widget.securityService?.isLocked ?? false) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locked && widget.securityService != null) {
      return LockScreen(
        securityService: widget.securityService!,
        onUnlocked: () => setState(() => _locked = false),
      );
    }
    return widget.child;
  }
}
