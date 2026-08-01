import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'calendar/event_controller.dart';
import 'contacts/contact_controller.dart';
import 'finance/finance_controller.dart';
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
import 'utils/keyboard_insets.dart';

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
    required this.financeController,
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
  final FinanceController financeController;
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
        final barColor = _barBackgroundColor(prefs, _minuteOfDay);

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
                        financeController: widget.financeController,
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

/// Nav/tab bar background. Matches the scaffold background — the default
/// (white / dark-gray) or the custom solid/dynamic color — so scrolling
/// content under the header doesn't reveal a contrasting band. Image
/// backgrounds keep a frosted translucent bar so the image shows through
/// with the standard iOS blur.
Color _barBackgroundColor(AppearancePrefs prefs, int minute) {
  Color side(ThemeAppearance a,
      {required Color frosted, required Color fallback}) {
    if (a.backgroundMode == BackgroundMode.image) return frosted;
    return a.backgroundColorAt(minute) ?? fallback;
  }

  return CupertinoDynamicColor.withBrightness(
    color: side(prefs.light,
        frosted: const Color(0xCCF8F8F8), fallback: const Color(0xFFFFFFFF)),
    darkColor: side(prefs.dark,
        frosted: const Color(0xCC1C1C1E), fallback: const Color(0xFF1C1C1E)),
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
/// Timing is the hard part. When the user toggles the OS theme from Settings
/// and returns, the brightness change is usually delivered (and this widget
/// rebuilt) BEFORE the `resumed` lifecycle event — and an unfocus/refocus run
/// during that transition hides the keyboard for good, because iOS drops the
/// programmatic re-show while the app isn't fully active. So instead of
/// refreshing on the spot, the flip arms a deferred refresh that only fires
/// once the app is firmly resumed plus a settle delay, with the focus dance
/// followed by a belt-and-braces `TextInput.show` in case the platform still
/// swallowed the implicit show.
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
  Timer? _pendingRefresh;

  /// Set when a brightness flip arrives while the app isn't resumed (theme
  /// switched in the background); the refresh is re-armed on the next resume.
  bool _refreshWhenResumed = false;

  /// Delay between (the later of) the brightness flip / app resume and the
  /// focus dance, so the resume's own keyboard restore has finished and iOS
  /// honours the re-show.
  static const Duration _settleDelay = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _pendingRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _refreshWhenResumed) {
      _refreshWhenResumed = false;
      _armRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    if (_lastBrightness != null && _lastBrightness != brightness) {
      // Lifecycle ordering isn't guaranteed: on a background theme switch the
      // brightness rebuild often lands while the app is still inactive. Defer
      // to the resume handler in that case; refresh (after the settle delay)
      // when the flip happens while already active.
      if (WidgetsBinding.instance.lifecycleState ==
          AppLifecycleState.resumed) {
        _armRefresh();
      } else {
        _refreshWhenResumed = true;
      }
    }
    _lastBrightness = brightness;
    return widget.child;
  }

  void _armRefresh() {
    _pendingRefresh?.cancel();
    _pendingRefresh = Timer(_settleDelay, () {
      _pendingRefresh = null;
      if (!mounted) return;
      // Backgrounded again before the timer fired — try again next resume.
      if (WidgetsBinding.instance.lifecycleState !=
          AppLifecycleState.resumed) {
        _refreshWhenResumed = true;
        return;
      }
      _refreshKeyboard();
    });
  }

  void _refreshKeyboard() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus || focus.context == null) return;

    // No live keyboard → nothing to refresh; the IME picks up the new
    // brightness on its next attach. Read the root view's insets — inherited
    // MediaQueries below the Cupertino scaffolds have the bottom inset
    // consumed and always read 0.
    if (!isKeyboardVisible(context)) return;

    // Toggle focus to close + reopen the input connection. The IME picks up
    // the new keyboardAppearance from the freshly-attached configuration.
    // Announce the refresh window first: the owning view keeps its field
    // mounted across the gap only while KeyboardAppearanceRefresh.isActive
    // (see NoteDetailView / TaskDetailView) — otherwise the focus drop would
    // be treated as a user dismissal and the field torn down, detaching the
    // node and turning the refocus into a silent no-op.
    KeyboardAppearanceRefresh.begin();
    focus.unfocus(disposition: UnfocusDisposition.scope);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focus.requestFocus();
      _verifyKeyboardRestored(focus, retriesLeft: 2);
    });
  }

  /// iOS can swallow the keyboard re-show if it lands while the dismissal
  /// animation from the unfocus is still running. Check after the animation
  /// window has passed and nudge the keyboard back if the focus survived but
  /// the keyboard didn't.
  void _verifyKeyboardRestored(FocusNode focus, {required int retriesLeft}) {
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || !focus.hasFocus) {
        KeyboardAppearanceRefresh.end();
        return;
      }
      if (isKeyboardVisible(context)) {
        // Keyboard is back in the new style — the refresh is complete.
        KeyboardAppearanceRefresh.end();
        return;
      }
      final focusContext = focus.context;
      final state =
          focusContext is StatefulElement ? focusContext.state : null;
      if (state is EditableTextState) {
        // Re-shows the keyboard for the existing connection (or attaches a
        // fresh one if it was lost) without touching focus.
        state.requestKeyboard();
      } else {
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      }
      if (retriesLeft > 1) {
        _verifyKeyboardRestored(focus, retriesLeft: retriesLeft - 1);
      } else {
        KeyboardAppearanceRefresh.end();
      }
    });
  }
}
