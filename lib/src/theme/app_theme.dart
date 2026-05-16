import 'package:flutter/cupertino.dart';

/// Centralised colors, durations, and sizing tokens used across the app.
///
/// Avoid hard-coding these values at call sites — import this file and use the
/// constants so that re-theming or accent-color changes happen in one place.
class AppColors {
  AppColors._();

  /// Primary brand accent (orange-red).
  static const Color accent = Color(0xFFFF4D00);

  /// System green used for completed indicators (matches iOS systemGreen).
  static const Color systemGreen = Color(0xFF34C759);

  /// Subtle drop-shadow used by floating panels and dropdowns.
  static const Color shadow = Color(0x30000000);
}

class AppDurations {
  AppDurations._();

  /// Standard page-transition / animation duration used across the app.
  static const Duration transition = Duration(milliseconds: 180);
}
