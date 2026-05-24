import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../database/database_service.dart';
import '../localization/strings.dart';
import '../tasks/task_field_prefs.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'settings_service.dart';
import 'smart_list_prefs.dart';

/// Sentinel [SettingsController.defaultTab] value: open whichever tab was last
/// open when the app was closed, rather than a fixed tab.
const String kLastOpenedTab = 'last';

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
      } else if (key == TaskFieldPrefs.storageKey) {
        _taskFieldPrefs = TaskFieldPrefs.fromJson(value);
      }
    }

    notifyListeners();
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

  /// Replaces in-memory smart-list prefs from a backup map and persists them.
  Future<void> importSmartListPrefs(Map<String, dynamic> data) async {
    _smartListPrefs.applyJson(data);
    notifyListeners();
    await _smartListPrefs.save();
  }

  Future<void> updateTaskFieldPrefs(TaskFieldPrefs prefs) async {
    _taskFieldPrefs = prefs.copy();
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
      case 'completed':
        _smartListPrefs.completed = value;
        break;
      case 'trash':
        _smartListPrefs.trash = value;
        break;
    }
    notifyListeners();
    await _smartListPrefs.save();
  }
}
