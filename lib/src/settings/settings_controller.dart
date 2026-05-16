import 'package:flutter/material.dart';

import '../database/database_service.dart';
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

  // Tabs 1=Notes, 2=Calendar, 3=Routines, 4=Settings. Tasks(0) always on.
  final Map<int, bool> _tabVisibility = {1: true, 2: true, 3: true, 4: true};
  bool isTabVisible(int index) => _tabVisibility[index] ?? true;

  /// Returns the count of optional tabs (1,2,3,4) that are currently visible.
  int get visibleOptionalTabCount =>
      [1, 2, 3, 4].where((i) => _tabVisibility[i] == true).length;

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
        if (_tabVisibility.containsKey(idx)) {
          _tabVisibility[idx] = value == 'true';
        }
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
