import 'package:flutter/material.dart';

import 'settings_service.dart';
import 'smart_list_prefs.dart';

class SettingsController with ChangeNotifier {
  SettingsController(this._settingsService);

  final SettingsService _settingsService;

  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  SmartListPrefs _smartListPrefs = SmartListPrefs();
  SmartListPrefs get smartListPrefs => _smartListPrefs;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _smartListPrefs = await SmartListPrefs.load();
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode == _themeMode) return;
    _themeMode = newThemeMode;
    notifyListeners();
    await _settingsService.updateThemeMode(newThemeMode);
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
