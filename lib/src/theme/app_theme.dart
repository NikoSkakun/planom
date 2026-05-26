import 'package:flutter/cupertino.dart';

/// Centralised colors, durations, and sizing tokens used across the app.
///
/// Avoid hard-coding these values at call sites — import this file and use the
/// constants so that re-theming or accent-color changes happen in one place.
class AppColors {
  AppColors._();

  /// Primary brand accent (orange-red). Mutable so the user can customise it
  /// via Settings → Appearance; changes propagate through a SettingsController
  /// rebuild rather than const-capture.
  static Color accent = const Color(0xFFFF4D00);

  /// System green used for completed indicators (matches iOS systemGreen).
  /// Also user-customisable via Settings → Appearance.
  static Color systemGreen = const Color(0xFF34C759);

  /// Subtle drop-shadow used by floating panels and dropdowns.
  static const Color shadow = Color(0x30000000);
}

class AppDurations {
  AppDurations._();

  /// Standard page-transition / animation duration used across the app.
  static const Duration transition = Duration(milliseconds: 180);
}

/// Mutable defaults applied to newly created entities when the user hasn't
/// explicitly picked an icon. Updated by SettingsController on load and on
/// every preference change so creation sheets can read them statically.
class AppDefaults {
  AppDefaults._();

  /// Default `iconId` for a freshly created task. Historical default 'inbox'.
  static String taskIcon = 'inbox';

  /// Default `iconId` for a list. null = render the default PNG asset.
  static String? listIcon;

  /// Default `iconId` for a task folder. null = render the default PNG asset.
  static String? folderIcon;

  /// Default `iconId` for a note folder. null = render the default PNG asset.
  static String? noteFolderIcon;
}

/// UI scale factor mirrored from SettingsController. CupertinoApp wraps the
/// content in a MediaQuery whose `textScaler` is `TextScaler.linear(factor)`
/// when system scaling is disabled, so text widgets scale automatically.
/// Widgets that need to scale alongside their attached text (e.g. checkboxes,
/// row icons) multiply their hardcoded size by [AppScale.factor].
class AppScale {
  AppScale._();

  /// Current effective UI scale (1.0 = default). Updated on settings load.
  static double factor = 1.0;
}
