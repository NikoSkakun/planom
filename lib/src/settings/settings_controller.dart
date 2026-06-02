import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:google_fonts/google_fonts.dart';

import '../database/database_service.dart';
import '../localization/strings.dart';
import '../tasks/task_field_prefs.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/appearance_prefs.dart';
import 'settings_service.dart';
import 'smart_list_prefs.dart';
import 'tab_bar_config.dart';

/// Sentinel [SettingsController.defaultTab] value: open whichever tab was last
/// open when the app was closed, rather than a fixed tab.
const String kLastOpenedTab = 'last';

/// Global speed multiplier applied to every animation in the app.
///
/// Implemented on top of Flutter's `timeDilation` global (which scales the
/// time delivered to every Ticker), so AnimationController-driven widgets
/// — page transitions, AnimatedSize, AnimatedSwitcher, AnimatedList,
/// scroll physics, drag visuals — all respond without per-call-site
/// plumbing. The matching numeric scale is mirrored to
/// [AppDurations.scale] for the rare callers that build a Duration
/// outside the ticker pipeline (e.g. `Future.delayed`).
enum AnimationSpeed {
  /// Transitions are instant: no animation frames at all.
  off,

  /// Half the normal duration — animations feel "snappy".
  fast,

  /// Stock duration; matches the app's design timing.
  normal,

  /// 2× the normal duration — useful for demos and screen recordings.
  slow,
}

/// Numeric multiplier for an [AnimationSpeed]. Smaller = faster. The
/// `off` case maps to a sentinel near-zero scale instead of literal zero
/// because `timeDilation = 0` divides by zero inside the scheduler; the
/// chosen value is small enough that every frame appears to traverse the
/// full animation timeline.
double animationSpeedScale(AnimationSpeed s) {
  switch (s) {
    case AnimationSpeed.off:
      return 0.0001;
    case AnimationSpeed.fast:
      return 0.5;
    case AnimationSpeed.normal:
      return 1.0;
    case AnimationSpeed.slow:
      return 2.0;
  }
}

/// How the Calendar tab lays out days.
enum CalendarViewMode {
  /// Default: each month is its own grid, starting on a fresh week row with
  /// blank leading/trailing cells so weeks never straddle a month boundary.
  months,

  /// Continuous scroll: weeks flow into one another with no gap between
  /// months, so the last day of a month sits next to the first day of the
  /// next. Month boundaries are marked inline on the 1st of each month.
  continuous,
}

/// What the app icon badge counts. Only the current space's data feeds in.
enum BadgeMode {
  /// No badge at all.
  none,

  /// Default: today's uncompleted tasks (including overdue).
  todayTasks,

  /// Today's uncompleted tasks plus today's not-yet-started events.
  todayTasksAndEvents,

  /// Inbox uncompleted tasks (`listId == null`).
  inboxTasks,

  /// All uncompleted top-level tasks across every list.
  allUncompleted,

  /// A user-chosen combination of smart lists, lists and folders. The
  /// selected sources are stored in [SettingsController.badgeCustomSources].
  custom,
}

/// Encodes a badge source token. Tokens are stored comma-joined in the
/// `badge_custom_sources` setting. Forms:
///   `smart:<inbox|today|tomorrow|upcoming|allTasks>`
///   `list:<listId>`
///   `folder:<folderId>`
class BadgeSource {
  const BadgeSource(this.token);
  final String token;

  static const smartPrefix = 'smart:';
  static const listPrefix = 'list:';
  static const folderPrefix = 'folder:';

  static BadgeSource smart(String key) => BadgeSource('$smartPrefix$key');
  static BadgeSource list(String id) => BadgeSource('$listPrefix$id');
  static BadgeSource folder(String id) => BadgeSource('$folderPrefix$id');
}

class SettingsController with ChangeNotifier {
  SettingsController(this._settingsService, this._db);

  final SettingsService _settingsService;
  final DatabaseService _db;

  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  SmartListPrefs _smartListPrefs = SmartListPrefs();
  SmartListPrefs get smartListPrefs => _smartListPrefs;
  bool get hideTabLabels => _smartListPrefs.hideTabLabels;

  TaskFieldPrefs _taskFieldPrefs = TaskFieldPrefs();
  TaskFieldPrefs get taskFieldPrefs => _taskFieldPrefs;

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  String _fontKey = kSystemFontKey;
  String get fontKey => _fontKey;

  Color _accentColor = AppColors.accent;
  Color get accentColor => _accentColor;

  Color _completionColor = AppColors.systemGreen;
  Color get completionColor => _completionColor;

  // Custom background + font-color overrides (per light/dark), incl. optional
  // time-of-day dynamic colors. See [AppearancePrefs].
  AppearancePrefs _appearancePrefs = AppearancePrefs();
  AppearancePrefs get appearancePrefs => _appearancePrefs;

  // ISO weekday number for the first day of the week: 1=Monday … 7=Sunday.
  // Default is Monday to match the existing calendar grid.
  int _firstDayOfWeek = DateTime.monday;
  int get firstDayOfWeek => _firstDayOfWeek;

  // How the Calendar tab lays out days. Defaults to the classic month grid.
  CalendarViewMode _calendarViewMode = CalendarViewMode.months;
  CalendarViewMode get calendarViewMode => _calendarViewMode;

  // Whether the Calendar tab's + button can create Tasks / Events. Both
  // default to true. If both are off the + button is hidden in Calendar; if
  // exactly one is off the + button skips the picker and routes straight to
  // the remaining option.
  bool _calendarAllowCreatingTasks = true;
  bool get calendarAllowCreatingTasks => _calendarAllowCreatingTasks;
  bool _calendarAllowCreatingEvents = true;
  bool get calendarAllowCreatingEvents => _calendarAllowCreatingEvents;

  BadgeMode _badgeMode = BadgeMode.todayTasks;
  BadgeMode get badgeMode => _badgeMode;

  // Source tokens counted by [BadgeMode.custom] (see [BadgeSource]).
  List<String> _badgeCustomSources = [];
  List<String> get badgeCustomSources => List.unmodifiable(_badgeCustomSources);

  // When true, today's uncompleted routines are added to the app icon badge
  // count (on top of whatever [badgeMode] counts). Ignored when the badge is
  // off ([BadgeMode.none]).
  bool _badgeIncludeRoutines = false;
  bool get badgeIncludeRoutines => _badgeIncludeRoutines;

  // Surface today's routines as a collapsible section in Tasks → Today, and in
  // the Calendar day view. Both default off and are mirrored between the
  // Routines / Tasks / Calendar settings pages.
  bool _showRoutinesInToday = false;
  bool get showRoutinesInToday => _showRoutinesInToday;
  bool _showRoutinesInCalendar = false;
  bool get showRoutinesInCalendar => _showRoutinesInCalendar;

  // Whether today's routines feed the Today smart-list count badge (only
  // relevant when [showRoutinesInToday] is on).
  bool _countRoutinesInToday = false;
  bool get countRoutinesInToday => _countRoutinesInToday;

  // Surface today's events as a section in Tasks → Today, and optionally fold
  // them into the Today count badge. Both default off.
  bool _showEventsInToday = false;
  bool get showEventsInToday => _showEventsInToday;
  bool _countEventsInToday = false;
  bool get countEventsInToday => _countEventsInToday;

  AnimationSpeed _animationSpeed = AnimationSpeed.normal;
  AnimationSpeed get animationSpeed => _animationSpeed;

  // App-wide font/UI scale.
  //
  // [textScale] is the multiplier applied to text via MediaQuery's
  // `textScaler` AND mirrored to [AppScale.factor] for UI widgets that want
  // to grow alongside their attached text (checkbox, row icons). The default
  // 1.0 matches today's behavior.
  //
  // When [useSystemTextScale] is true, the app respects the OS-level text
  // scale (Dynamic Type on iOS; Display & Text Size on Android) and the
  // [textScale] value is ignored for text — but still applied to UI widgets
  // through [AppScale.factor] so the two stay roughly in sync visually.
  double _textScale = 1.0;
  double get textScale => _textScale;
  bool _useSystemTextScale = false;
  bool get useSystemTextScale => _useSystemTextScale;

  /// Multi-page tab bar layout — supersedes the legacy [tabOrder] +
  /// [tabVisibility] booleans. On first load the legacy values are migrated
  /// into a single-page layout if no `tab_bar_config` row exists yet.
  TabBarConfig _tabBarConfig = TabBarConfig.defaultLayout();
  TabBarConfig get tabBarConfig => _tabBarConfig;

  // Default icons applied when the user creates a new task/list/folder/note
  // folder without picking one. Strings match the existing iconId scheme:
  // - Tasks: 'inbox' is the historical default; other values are presets.
  // - Lists / folders / note folders: null = render the default PNG asset;
  //   non-null is an SF-symbol key from `kFolderIconPresets`.
  String _defaultTaskIcon = 'inbox';
  String get defaultTaskIcon => _defaultTaskIcon;
  String? _defaultListIcon;
  String? get defaultListIcon => _defaultListIcon;
  String? _defaultFolderIcon;
  String? get defaultFolderIcon => _defaultFolderIcon;
  String? _defaultNoteFolderIcon;
  String? get defaultNoteFolderIcon => _defaultNoteFolderIcon;

  /// Bumped whenever the accent/completion color changes. Those colors live in
  /// AppColors statics read all over the tree, so instead of firing the main
  /// notifier (which rebuilds the whole CupertinoApp, including routing, locale
  /// and theme), color updates only bump this. Widgets that must react to a
  /// color change listen to this notifier, scoping the rebuild to the content.
  final ValueNotifier<int> colorRevision = ValueNotifier<int>(0);

  @override
  void dispose() {
    colorRevision.dispose();
    super.dispose();
  }

  final Map<int, bool> _tabVisibility = {
    0: true,
    1: true,
    2: true,
    3: true,
    4: true,
  };
  bool isTabVisible(int index) => _tabVisibility[index] ?? true;

  /// Returns the count of tabs (0–4) that are currently visible.
  int get visibleOptionalTabCount =>
      [0, 1, 2, 3, 4].where((i) => _tabVisibility[i] == true).length;

  List<int> _tabOrder = [0, 1, 2, 3, 4];

  /// The user-defined display order of the five logical tab indices.
  List<int> get tabOrder => List.unmodifiable(_tabOrder);

  // Which tab to select on launch: a logical index ('0'–'4') or [kLastOpenedTab].
  String _defaultTab = '0';
  String get defaultTab => _defaultTab;

  // Last tab the user opened; persisted so [kLastOpenedTab] can restore it.
  int _lastOpenedTab = 0;
  int get lastOpenedTab => _lastOpenedTab;

  /// The logical tab (0–4) to show on launch, resolved against the tabs that
  /// are currently visible. Falls back to the first visible tab when the
  /// configured choice is hidden or invalid.
  int resolveInitialTab(List<int> visibleLogicalTabs) {
    if (visibleLogicalTabs.isEmpty) return 0;
    final candidate = _defaultTab == kLastOpenedTab
        ? _lastOpenedTab
        : (int.tryParse(_defaultTab) ?? 0);
    return visibleLogicalTabs.contains(candidate)
        ? candidate
        : visibleLogicalTabs.first;
  }

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _smartListPrefs = await SmartListPrefs.load();

    final rows = await _db.getAppSettings();
    for (final row in rows) {
      final key = row['key'] as String;
      final value = row['value'] as String;
      final match = RegExp(r'^tab_(\d+)_visible$').firstMatch(key);
      if (match != null) {
        final idx = int.parse(match.group(1)!);
        _tabVisibility[idx] = value == 'true';
        continue;
      }
      if (key == 'locale') {
        _locale = localeFromCode(value);
      } else if (key == 'font') {
        if (value == kSystemFontKey || GoogleFonts.asMap().containsKey(value)) _fontKey = value;
      } else if (key == 'accent_color') {
        final v = int.tryParse(value);
        if (v != null) { _accentColor = Color(v); AppColors.accent = _accentColor; }
      } else if (key == 'completion_color') {
        final v = int.tryParse(value);
        if (v != null) { _completionColor = Color(v); AppColors.systemGreen = _completionColor; }
      } else if (key == 'tab_order') {
        final parts = value.split(',')
            .map((s) => int.tryParse(s))
            .whereType<int>()
            .toList();
        if (parts.length == 5 && parts.toSet().containsAll([0, 1, 2, 3, 4])) {
          _tabOrder = parts;
        }
      } else if (key == 'default_tab') {
        if (value == kLastOpenedTab ||
            (int.tryParse(value) != null && value.length == 1)) {
          _defaultTab = value;
        }
      } else if (key == 'last_tab') {
        final v = int.tryParse(value);
        if (v != null && v >= 0 && v <= 4) _lastOpenedTab = v;
      } else if (key == 'first_day_of_week') {
        final v = int.tryParse(value);
        if (v != null && v >= 1 && v <= 7) _firstDayOfWeek = v;
      } else if (key == 'calendar_view_mode') {
        _calendarViewMode = _decodeCalendarViewMode(value);
      } else if (key == 'calendar_allow_tasks') {
        _calendarAllowCreatingTasks = value != 'false';
      } else if (key == 'calendar_allow_events') {
        _calendarAllowCreatingEvents = value != 'false';
      } else if (key == 'badge_mode') {
        _badgeMode = _decodeBadgeMode(value);
      } else if (key == 'badge_custom_sources') {
        _badgeCustomSources = value
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (key == 'badge_include_routines') {
        _badgeIncludeRoutines = value == 'true';
      } else if (key == 'show_routines_in_today') {
        _showRoutinesInToday = value == 'true';
      } else if (key == 'show_routines_in_calendar') {
        _showRoutinesInCalendar = value == 'true';
      } else if (key == 'count_routines_in_today') {
        _countRoutinesInToday = value == 'true';
      } else if (key == 'show_events_in_today') {
        _showEventsInToday = value == 'true';
      } else if (key == 'count_events_in_today') {
        _countEventsInToday = value == 'true';
      } else if (key == 'animation_speed') {
        _animationSpeed = _decodeAnimationSpeed(value);
      } else if (key == 'default_task_icon') {
        if (value.isNotEmpty) _defaultTaskIcon = value;
      } else if (key == 'default_list_icon') {
        _defaultListIcon = value.isEmpty ? null : value;
      } else if (key == 'default_folder_icon') {
        _defaultFolderIcon = value.isEmpty ? null : value;
      } else if (key == 'default_note_folder_icon') {
        _defaultNoteFolderIcon = value.isEmpty ? null : value;
      } else if (key == 'text_scale') {
        final v = double.tryParse(value);
        if (v != null && v >= 0.5 && v <= 2.5) _textScale = v;
      } else if (key == 'use_system_text_scale') {
        _useSystemTextScale = value == 'true';
      } else if (key == 'tab_bar_config') {
        final parsed = TabBarConfig.tryParse(value);
        if (parsed != null) _tabBarConfig = parsed;
      } else if (key == TaskFieldPrefs.storageKey) {
        _taskFieldPrefs = TaskFieldPrefs.fromJson(value);
      } else if (key == kAppearancePrefsKey) {
        _appearancePrefs = AppearancePrefs.fromJsonString(value);
      }
    }

    // Keep the global checkbox-style mirror in sync with persisted prefs so
    // every TaskRow/_RoundedCheckbox renders in the user-selected style without
    // having to thread the value through every callsite.
    TaskCheckboxAppearance.current = _taskFieldPrefs.checkboxStyle;
    TaskCompletionUndoPref.enabled = _taskFieldPrefs.showUndoOnComplete;
    AppDefaults.taskIcon = _defaultTaskIcon;
    AppDefaults.listIcon = _defaultListIcon;
    AppDefaults.folderIcon = _defaultFolderIcon;
    AppDefaults.noteFolderIcon = _defaultNoteFolderIcon;
    AppScale.factor = _textScale;
    _applyAnimationSpeed(_animationSpeed);

    // Migrate the legacy single-row tab layout to TabBarConfig the first time
    // a user opens the new tab-bar UI. Existing _tabBarConfig is the default
    // if no `tab_bar_config` row was loaded above; merge the user's visibility
    // + order into it so they don't lose their existing layout.
    final loadedConfig =
        rows.any((r) => r['key'] == 'tab_bar_config');
    if (!loadedConfig) {
      _tabBarConfig = TabBarConfig.fromLegacy(
        tabVisibility: _tabVisibility,
        tabOrder: _tabOrder,
      );
    }

    notifyListeners();
  }

  Future<void> updateTabBarConfig(TabBarConfig config) async {
    _tabBarConfig = config;
    notifyListeners();
    await _db.setAppSetting('tab_bar_config', config.toJsonString());
  }

  Future<void> setTabVisible(int index, bool visible) async {
    _tabVisibility[index] = visible;
    notifyListeners();
    await _db.setAppSetting('tab_${index}_visible', visible.toString());
  }

  Future<void> updateTabOrder(List<int> order) async {
    if (order.length != 5 || order.toSet().length != 5) return;
    _tabOrder = List.of(order);
    notifyListeners();
    await _db.setAppSetting('tab_order', order.join(','));
  }

  Future<void> updateDefaultTab(String value) async {
    if (value == _defaultTab) return;
    _defaultTab = value;
    notifyListeners();
    await _db.setAppSetting('default_tab', value);
  }

  /// Records the last tab the user opened (persisted for [kLastOpenedTab]).
  /// No [notifyListeners] — nothing in the UI reacts to this live.
  Future<void> setLastOpenedTab(int index) async {
    if (index == _lastOpenedTab) return;
    _lastOpenedTab = index;
    await _db.setAppSetting('last_tab', index.toString());
  }

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode == _themeMode) return;
    _themeMode = newThemeMode;
    notifyListeners();
    await _settingsService.updateThemeMode(newThemeMode);
  }

  Future<void> updateFirstDayOfWeek(int isoDay) async {
    if (isoDay < 1 || isoDay > 7) return;
    if (isoDay == _firstDayOfWeek) return;
    _firstDayOfWeek = isoDay;
    notifyListeners();
    await _db.setAppSetting('first_day_of_week', isoDay.toString());
  }

  Future<void> updateCalendarViewMode(CalendarViewMode mode) async {
    if (mode == _calendarViewMode) return;
    _calendarViewMode = mode;
    notifyListeners();
    await _db.setAppSetting(
        'calendar_view_mode', _encodeCalendarViewMode(mode));
  }

  Future<void> updateCalendarAllowCreatingTasks(bool value) async {
    if (value == _calendarAllowCreatingTasks) return;
    _calendarAllowCreatingTasks = value;
    notifyListeners();
    await _db.setAppSetting('calendar_allow_tasks', value.toString());
  }

  Future<void> updateCalendarAllowCreatingEvents(bool value) async {
    if (value == _calendarAllowCreatingEvents) return;
    _calendarAllowCreatingEvents = value;
    notifyListeners();
    await _db.setAppSetting('calendar_allow_events', value.toString());
  }

  Future<void> updateBadgeMode(BadgeMode mode) async {
    if (mode == _badgeMode) return;
    _badgeMode = mode;
    notifyListeners();
    await _db.setAppSetting('badge_mode', _encodeBadgeMode(mode));
  }

  Future<void> updateBadgeCustomSources(List<String> sources) async {
    _badgeCustomSources = List.of(sources);
    notifyListeners();
    await _db.setAppSetting('badge_custom_sources', _badgeCustomSources.join(','));
  }

  Future<void> updateBadgeIncludeRoutines(bool value) async {
    if (value == _badgeIncludeRoutines) return;
    _badgeIncludeRoutines = value;
    notifyListeners();
    await _db.setAppSetting('badge_include_routines', value.toString());
  }

  Future<void> updateShowRoutinesInToday(bool value) async {
    if (value == _showRoutinesInToday) return;
    _showRoutinesInToday = value;
    notifyListeners();
    await _db.setAppSetting('show_routines_in_today', value.toString());
  }

  Future<void> updateShowRoutinesInCalendar(bool value) async {
    if (value == _showRoutinesInCalendar) return;
    _showRoutinesInCalendar = value;
    notifyListeners();
    await _db.setAppSetting('show_routines_in_calendar', value.toString());
  }

  Future<void> updateCountRoutinesInToday(bool value) async {
    if (value == _countRoutinesInToday) return;
    _countRoutinesInToday = value;
    notifyListeners();
    await _db.setAppSetting('count_routines_in_today', value.toString());
  }

  Future<void> updateShowEventsInToday(bool value) async {
    if (value == _showEventsInToday) return;
    _showEventsInToday = value;
    notifyListeners();
    await _db.setAppSetting('show_events_in_today', value.toString());
  }

  Future<void> updateCountEventsInToday(bool value) async {
    if (value == _countEventsInToday) return;
    _countEventsInToday = value;
    notifyListeners();
    await _db.setAppSetting('count_events_in_today', value.toString());
  }

  Future<void> updateAnimationSpeed(AnimationSpeed speed) async {
    if (speed == _animationSpeed) return;
    _animationSpeed = speed;
    _applyAnimationSpeed(speed);
    notifyListeners();
    await _db.setAppSetting('animation_speed', _encodeAnimationSpeed(speed));
  }

  /// `timeDilation` and our [AppDurations.scale] use the same convention:
  /// a value of 2.0 makes animations 2× slower in wall-clock time,
  /// 0.5 makes them 2× faster. Setting either to 0 would divide by
  /// zero inside the scheduler, so "off" maps to a near-zero scale
  /// (0.0001) — small enough that every frame appears to traverse the
  /// full animation timeline at once.
  static void _applyAnimationSpeed(AnimationSpeed speed) {
    final scale = animationSpeedScale(speed);
    timeDilation = scale;
    AppDurations.scale = scale;
  }

  Future<void> updateDefaultTaskIcon(String iconId) async {
    if (iconId.isEmpty || iconId == _defaultTaskIcon) return;
    _defaultTaskIcon = iconId;
    AppDefaults.taskIcon = iconId;
    notifyListeners();
    await _db.setAppSetting('default_task_icon', iconId);
  }

  Future<void> updateDefaultListIcon(String? iconId) async {
    if (iconId == _defaultListIcon) return;
    _defaultListIcon = iconId;
    AppDefaults.listIcon = iconId;
    notifyListeners();
    await _db.setAppSetting('default_list_icon', iconId ?? '');
  }

  Future<void> updateDefaultFolderIcon(String? iconId) async {
    if (iconId == _defaultFolderIcon) return;
    _defaultFolderIcon = iconId;
    AppDefaults.folderIcon = iconId;
    notifyListeners();
    await _db.setAppSetting('default_folder_icon', iconId ?? '');
  }

  Future<void> updateDefaultNoteFolderIcon(String? iconId) async {
    if (iconId == _defaultNoteFolderIcon) return;
    _defaultNoteFolderIcon = iconId;
    AppDefaults.noteFolderIcon = iconId;
    notifyListeners();
    await _db.setAppSetting('default_note_folder_icon', iconId ?? '');
  }

  Future<void> updateTextScale(double scale) async {
    final clamped = scale.clamp(0.5, 2.5).toDouble();
    if (clamped == _textScale) return;
    _textScale = clamped;
    AppScale.factor = clamped;
    notifyListeners();
    await _db.setAppSetting('text_scale', clamped.toStringAsFixed(2));
  }

  Future<void> updateUseSystemTextScale(bool value) async {
    if (value == _useSystemTextScale) return;
    _useSystemTextScale = value;
    notifyListeners();
    await _db.setAppSetting('use_system_text_scale', value.toString());
  }

  static String _encodeBadgeMode(BadgeMode m) {
    switch (m) {
      case BadgeMode.none:
        return 'none';
      case BadgeMode.todayTasks:
        return 'todayTasks';
      case BadgeMode.todayTasksAndEvents:
        return 'todayTasksAndEvents';
      case BadgeMode.inboxTasks:
        return 'inboxTasks';
      case BadgeMode.allUncompleted:
        return 'allUncompleted';
      case BadgeMode.custom:
        return 'custom';
    }
  }

  static String _encodeAnimationSpeed(AnimationSpeed s) {
    switch (s) {
      case AnimationSpeed.off:
        return 'off';
      case AnimationSpeed.fast:
        return 'fast';
      case AnimationSpeed.normal:
        return 'normal';
      case AnimationSpeed.slow:
        return 'slow';
    }
  }

  static AnimationSpeed _decodeAnimationSpeed(String v) {
    switch (v) {
      case 'off':
        return AnimationSpeed.off;
      case 'fast':
        return AnimationSpeed.fast;
      case 'slow':
        return AnimationSpeed.slow;
      case 'normal':
      default:
        return AnimationSpeed.normal;
    }
  }

  static String _encodeCalendarViewMode(CalendarViewMode m) {
    switch (m) {
      case CalendarViewMode.months:
        return 'months';
      case CalendarViewMode.continuous:
        return 'continuous';
    }
  }

  static CalendarViewMode _decodeCalendarViewMode(String v) {
    switch (v) {
      case 'continuous':
        return CalendarViewMode.continuous;
      case 'months':
      default:
        return CalendarViewMode.months;
    }
  }

  static BadgeMode _decodeBadgeMode(String v) {
    switch (v) {
      case 'none':
        return BadgeMode.none;
      case 'todayTasksAndEvents':
        return BadgeMode.todayTasksAndEvents;
      case 'inboxTasks':
        return BadgeMode.inboxTasks;
      case 'allUncompleted':
        return BadgeMode.allUncompleted;
      case 'custom':
        return BadgeMode.custom;
      case 'todayTasks':
      default:
        return BadgeMode.todayTasks;
    }
  }

  Future<void> updateLocale(Locale locale) async {
    if (locale.languageCode == _locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    await _db.setAppSetting('locale', locale.languageCode);
  }

  Future<void> updateFontKey(String key) async {
    if (key == _fontKey) return;
    if (key != kSystemFontKey && !GoogleFonts.asMap().containsKey(key)) return;
    _fontKey = key;
    notifyListeners();
    await _db.setAppSetting('font', key);
  }

  Future<void> updateAccentColor(Color color) async {
    if (color == _accentColor) return;
    AppColors.accent = color;
    _accentColor = color;
    colorRevision.value++;
    await _db.setAppSetting('accent_color', color.value.toString());
  }

  Future<void> updateCompletionColor(Color color) async {
    if (color == _completionColor) return;
    AppColors.systemGreen = color;
    _completionColor = color;
    colorRevision.value++;
    await _db.setAppSetting('completion_color', color.value.toString());
  }

  /// Replaces the appearance overrides (background + font color) and persists.
  /// Fires the main notifier because these feed the CupertinoApp theme
  /// (scaffold background + text theme), which lives above the content subtree.
  Future<void> updateAppearancePrefs(AppearancePrefs prefs) async {
    _appearancePrefs = prefs;
    notifyListeners();
    await _db.setAppSetting(kAppearancePrefsKey, prefs.toJsonString());
  }

  Future<void> updateHideTabLabels(bool value) async {
    _smartListPrefs.hideTabLabels = value;
    notifyListeners();
    await _smartListPrefs.save();
  }

  Future<void> updateShowAddFolderButton(bool value) async {
    _smartListPrefs.showAddFolderButton = value;
    notifyListeners();
    await _smartListPrefs.save();
  }

  Future<void> updateShowNotesAddFolderButton(bool value) async {
    _smartListPrefs.showNotesAddFolderButton = value;
    notifyListeners();
    await _smartListPrefs.save();
  }

  Future<void> updateNotesUseMarkdown(bool value) async {
    _smartListPrefs.notesUseMarkdown = value;
    notifyListeners();
    await _smartListPrefs.save();
  }

  /// Replaces in-memory smart-list prefs from a backup map and persists them.
  Future<void> importSmartListPrefs(Map<String, dynamic> data) async {
    _smartListPrefs.applyJson(data);
    notifyListeners();
    await _smartListPrefs.save();
  }

  Future<void> updateTaskFieldPrefs(TaskFieldPrefs prefs) async {
    _taskFieldPrefs = prefs.copy();
    TaskCheckboxAppearance.current = _taskFieldPrefs.checkboxStyle;
    TaskCompletionUndoPref.enabled = _taskFieldPrefs.showUndoOnComplete;
    notifyListeners();
    await _db.setAppSetting(TaskFieldPrefs.storageKey, _taskFieldPrefs.toJson());
  }

  Future<void> updateSmartListVisibility(
      String key, SmartListVisibility value) async {
    switch (key) {
      case 'today':
        _smartListPrefs.today = value;
        break;
      case 'tomorrow':
        _smartListPrefs.tomorrow = value;
        break;
      case 'upcoming':
        _smartListPrefs.upcoming = value;
        break;
      case 'allTasks':
        _smartListPrefs.allTasks = value;
        break;
      case 'completed':
        _smartListPrefs.completed = value;
        break;
      case 'trash':
        _smartListPrefs.trash = value;
        break;
      case 'notesTrash':
        _smartListPrefs.notesTrash = value;
        break;
    }
    notifyListeners();
    await _smartListPrefs.save();
  }
}
