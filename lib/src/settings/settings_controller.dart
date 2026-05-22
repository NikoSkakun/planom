import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../database/database_service.dart';
import '../localization/strings.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'settings_service.dart';
import 'smart_list_prefs.dart';

class SettingsController with ChangeNotifier {
  SettingsController(this._settingsService, this._db);

  final SettingsService _settingsService;
  final DatabaseService _db;

  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  SmartListPrefs _smartListPrefs = SmartListPrefs();
  SmartListPrefs get smartListPrefs => _smartListPrefs;
  bool get hideTabLabels => _smartListPrefs.hideTabLabels;

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  String _fontKey = kSystemFontKey;
  String get fontKey => _fontKey;

  Color _accentColor = AppColors.accent;
  Color get accentColor => _accentColor;

  Color _completionColor = AppColors.systemGreen;
  Color get completionColor => _completionColor;

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
      }
    }

    notifyListeners();
  }

  Future<void> setTabVisible(int index, bool visible) async {
    _tabVisibility[index] = visible;
    notifyListeners();
    await _db.setAppSetting('tab_${index}_visible', visible.toString());
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
    notifyListeners();
    await _db.setAppSetting('accent_color', color.value.toString());
  }

  Future<void> updateCompletionColor(Color color) async {
    if (color == _completionColor) return;
    AppColors.systemGreen = color;
    _completionColor = color;
    notifyListeners();
    await _db.setAppSetting('completion_color', color.value.toString());
  }

  Future<void> updateHideTabLabels(bool value) async {
    _smartListPrefs.hideTabLabels = value;
    notifyListeners();
    await _smartListPrefs.save();
  }

  /// Replaces in-memory smart-list prefs from a backup map and persists them.
  Future<void> importSmartListPrefs(Map<String, dynamic> data) async {
    _smartListPrefs.applyJson(data);
    notifyListeners();
    await _smartListPrefs.save();
  }

  Future<void> updateSmartListVisibility(
      String key, SmartListVisibility value) async {
    switch (key) {
      case 'today':
        _smartListPrefs.today = value;
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
