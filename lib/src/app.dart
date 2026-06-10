import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'calendar/event_controller.dart';
import 'contacts/contact_controller.dart';
import 'folders/folder_controller.dart';
import 'integrations/apple/device_calendar_controller.dart';
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
import 'theme/app_background.dart';
import 'theme/app_fonts.dart';
import 'theme/appearance_prefs.dart';
import 'utils/fast_route.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.settingsController,
    required this.taskController,
    required this.folderController,
    required this.noteController,
    required this.routineController,
    required this.eventController,
    required this.contactController,
    required this.backupService,
    this.securityService,
    required this.googleCalendarController,
    required this.deviceCalendarController,
  });

  final SettingsController settingsController;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final RoutineController routineController;
  final EventController eventController;
  final ContactController contactController;
  final BackupService backupService;
  final SecurityService? securityService;
  final GoogleCalendarController googleCalendarController;
  final DeviceCalendarController deviceCalendarController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Drives time-of-day dynamic colors. Only ticks while a dynamic appearance
  // is active AND the app is foregrounded; otherwise no timer is scheduled.
  Timer? _clock;
  int _minuteOfDay = _nowMinuteOfDay();
  bool _foreground = true;

  SettingsController get _settings => widget.settingsController;

  static int _nowMinuteOfDay() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);
    _syncClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    _clock?.cancel();
    super.dispose();
  }

  void _onSettingsChanged() => _syncClock();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      // Catch up to the current minute before repainting, then restart the
      // timer if a dynamic appearance is still configured. The visible result
      // is identical to having ticked while backgrounded.
      final m = _nowMinuteOfDay();
      if (m != _minuteOfDay && mounted) {
        setState(() => _minuteOfDay = m);
      }
      _syncClock();
    } else {
      // No point ticking/rebuilding while the app isn't on screen.
      _clock?.cancel();
      _clock = null;
    }
  }

  /// Starts or stops the per-minute refresh timer to match whether any
  /// time-of-day dynamic color is currently configured. Never runs while
  /// backgrounded (see [didChangeAppLifecycleState]).
  void _syncClock() {
    final needsClock = _foreground && _settings.appearancePrefs.usesDynamic;
    if (needsClock && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 30), (_) {
        final m = _nowMinuteOfDay();
        if (m != _minuteOfDay && mounted) setState(() => _minuteOfDay = m);
      });
    } else if (!needsClock && _clock != null) {
      _clock!.cancel();
      _clock = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final settingsController = _settings;
        final prefs = settingsController.appearancePrefs;
        final brightness = switch (settingsController.themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          _ => null,
        };

        // Resolve the per-brightness scaffold background + font color overrides
        // into brightness-aware dynamic colors so they apply correctly whether
        // the user is on light, dark, or system-following mode.
        final scaffoldColor = _scaffoldBackgroundColor(prefs, _minuteOfDay);
        final fontColor = _fontColor(prefs, _minuteOfDay);
        final barColor = _barBackgroundColor(prefs);

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
            scaffoldBackgroundColor: scaffoldColor,
            barBackgroundColor: barColor,
            textTheme: buildCupertinoTextTheme(
              settingsController.fontKey,
              color: fontColor,
            ),
          ),
          builder: (context, child) {
            // Image backgrounds need a real painter behind the (transparent)
            // scaffolds. Solid / dynamic colors are handled by the theme above.
            if (child == null) return const SizedBox.shrink();
            final isDark = _isDark(settingsController.themeMode, context);
            final appearance = prefs.forBrightness(isDark);
            if (appearance.backgroundMode != BackgroundMode.image) return child;
            return AppBackground(appearance: appearance, child: child);
          },
          onGenerateRoute: (settings) => FastRoute<void>(
            settings: settings,
            // Accent/completion color changes bump colorRevision (not the main
            // settings notifier), so they rebuild only this content subtree
            // instead of the whole CupertinoApp above.
            builder: (context) => ValueListenableBuilder<int>(
              valueListenable: settingsController.colorRevision,
              builder: (context, _, __) {
                // Apply the user-selected text scale to the whole content
                // subtree. When useSystemTextScale is true we honour the OS
                // value (TextScaler.noScaling falls through to whatever the
                // platform passed in via MediaQuery).
                final base = MediaQuery.of(context);
                final mq = settingsController.useSystemTextScale
                    ? base
                    : base.copyWith(
                        textScaler:
                            TextScaler.linear(settingsController.textScale),
                      );
                return MediaQuery(
                  data: mq,
                  child: _KeyboardBrightnessReactor(
                    child: _SecurityGate(
                      securityService: widget.securityService,
                      child: HomeShell(
                        settingsController: settingsController,
                        taskController: widget.taskController,
                        folderController: widget.folderController,
                        noteController: widget.noteController,
                        routineController: widget.routineController,
                        eventController: widget.eventController,
                        contactController: widget.contactController,
                        backupService: widget.backupService,
                        securityService: widget.securityService,
                        googleCalendarController: widget.googleCalendarController,
                        deviceCalendarController: widget.deviceCalendarController,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// True when the effective brightness is dark, resolving [ThemeMode.system]
/// against the platform brightness.
bool _isDark(ThemeMode mode, BuildContext context) => switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      _ => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

/// Resolves the scaffold background override to a brightness-aware color, or
/// null to keep the app default. Image backgrounds resolve to transparent so
/// the painter ([AppBackground]) shows through; solid/dynamic resolve to the
/// configured color at [minute].
Color? _scaffoldBackgroundColor(AppearancePrefs prefs, int minute) {
  // The dark-mode default background is a dark gray (matching the dark tab-bar
  // background) rather than pure black — softer and easier on the eyes. Light
  // mode keeps its white default. Because the dark default is no longer the
  // Cupertino system default, we always resolve an explicit color here.
  Color side(ThemeAppearance a) {
    if (a.backgroundMode == BackgroundMode.image) return const Color(0x00000000);
    return a.backgroundColorAt(minute) ??
        (a.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF));
  }

  return CupertinoDynamicColor.withBrightness(
    color: side(prefs.light),
    darkColor: side(prefs.dark),
  );
}

/// Resolves the global font-color override to a brightness-aware color, or
/// null to keep the app default ([CupertinoColors.label]).
Color? _fontColor(AppearancePrefs prefs, int minute) {
  final l = prefs.light.fontColorAt(minute);
  final d = prefs.dark.fontColorAt(minute);
  if (l == null && d == null) return null;
  return CupertinoDynamicColor.withBrightness(
    color: l ?? const Color(0xFF000000),
    darkColor: d ?? const Color(0xFFFFFFFF),
  );
}

/// Nav/tab bar background. Stays the opaque system background unless a custom
/// app background is active, in which case it becomes a frosted translucent
/// bar so the background shows through with the standard iOS blur.
Color _barBackgroundColor(AppearancePrefs prefs) {
  final custom = prefs.light.backgroundMode != BackgroundMode.defaultBg ||
      prefs.dark.backgroundMode != BackgroundMode.defaultBg;
  if (!custom) return CupertinoColors.systemBackground;
  return const CupertinoDynamicColor.withBrightness(
    color: Color(0xCCF8F8F8),
    darkColor: Color(0xCC1C1C1E),
  );
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

/// Watches the effective Cupertino brightness and, when it flips while a text
/// field is focused AND the keyboard is up, forces the IME to re-attach so the
/// open keyboard adopts the new appearance. Without this, iOS keeps the
/// keyboard in its previous light/dark style until the field is unfocused and
/// refocused — the keyboardAppearance baked into the TextInputConfiguration
/// is set once at attach time and the OS doesn't refresh a live keyboard.
///
/// The refresh is gated to skip during app resume: after a background+resume
/// (e.g. the user switched the OS theme in Settings), iOS won't let us
/// programmatically bring the keyboard back after an unfocus until the user
/// interacts with the field again. Without this gate the refresh dismisses
/// the keyboard and is unable to restore it, which is a worse regression
/// than the stale appearance it was trying to fix.
class _KeyboardBrightnessReactor extends StatefulWidget {
  const _KeyboardBrightnessReactor({required this.child});

  final Widget child;

  @override
  State<_KeyboardBrightnessReactor> createState() =>
      _KeyboardBrightnessReactorState();
}

class _KeyboardBrightnessReactorState
    extends State<_KeyboardBrightnessReactor> with WidgetsBindingObserver {
  Brightness? _lastBrightness;
  DateTime? _lastResumeAt;

  /// Window after [AppLifecycleState.resumed] during which we ignore
  /// brightness changes. Long enough to cover any stale-frame brightness
  /// transitions caused by the resume itself.
  static const Duration _postResumeQuietWindow = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastResumeAt = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    if (_lastBrightness != null && _lastBrightness != brightness) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshKeyboard());
    }
    _lastBrightness = brightness;
    return widget.child;
  }

  void _refreshKeyboard() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus) return;

    // If the brightness flip is happening as part of an app-resume (e.g. the
    // user came back from OS Settings after toggling Dark Mode), iOS will
    // refuse to re-show the keyboard after our programmatic unfocus, leaving
    // it permanently hidden. Skip the refresh in that window and let the
    // normal next-attach pick up the new appearance.
    if (_lastResumeAt != null &&
        DateTime.now().difference(_lastResumeAt!) < _postResumeQuietWindow) {
      return;
    }

    // No live keyboard → nothing to refresh; the IME picks up the new
    // brightness on its next attach.
    final mq = MediaQuery.maybeOf(context);
    if (mq == null || mq.viewInsets.bottom <= 0) return;

    // Toggle focus to close + reopen the input connection. The IME picks up
    // the new keyboardAppearance from the freshly-attached configuration.
    focus.unfocus(disposition: UnfocusDisposition.scope);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focus.requestFocus();
    });
  }
}
