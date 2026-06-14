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

  /// The app's base surface tone — matches the default scaffold background
  /// (white in light, dark gray in dark). Use this instead of
  /// [CupertinoColors.systemBackground] for surfaces that should blend with
  /// the app background: systemBackground is **pure black** in dark mode,
  /// which reads as a harsh block against the dark-gray scaffold.
  static const CupertinoDynamicColor surface =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );

  /// Hairline edge that delineates a menu/popover from a same-toned
  /// background — important in dark mode, where the drop shadow over the
  /// near-black scaffold barely registers on its own. Transparent in light,
  /// where the existing white-on-shadow look already reads fine.
  static const CupertinoDynamicColor menuBorder =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x00000000),
    darkColor: Color(0x33FFFFFF),
  );

  /// Drop shadow for menus / popovers. Heavier in dark so the panel still
  /// reads as elevated over the dark scaffold.
  static const CupertinoDynamicColor menuShadow =
      CupertinoDynamicColor.withBrightness(
    color: Color(0x30000000),
    darkColor: Color(0x80000000),
  );

  /// Fill for small circular icon buttons (e.g. the Add-Folder button).
  /// [CupertinoColors.secondarySystemBackground] is identical to the dark
  /// scaffold, making the circle invisible; this keeps a subtle but visible
  /// fill in both modes.
  static const CupertinoDynamicColor circleButtonBackground =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF2C2C2E),
  );

  /// Standard decoration for a floating dropdown menu / popover: app-surface
  /// fill, a hairline border, and an elevation shadow — all dark-mode aware
  /// so menus never render as a pure-black block.
  static BoxDecoration menuDecoration(BuildContext context,
      {double radius = 14}) {
    return BoxDecoration(
      color: surface.resolveFrom(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: menuBorder.resolveFrom(context), width: 0.5),
      boxShadow: [
        BoxShadow(
          color: menuShadow.resolveFrom(context),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

class AppDurations {
  AppDurations._();

  /// Standard page-transition / animation duration used across the app.
  static const Duration transition = Duration(milliseconds: 180);

  /// Multiplier applied to scaled durations. 1.0 = normal, < 1 = faster,
  /// > 1 = slower, 0 = disabled. Updated by [SettingsController] when the
  /// user changes the Animation Speed setting. The matching `timeDilation`
  /// is applied at the same time so AnimationController-driven animations
  /// (page transitions, AnimatedSize, etc.) honour the same scale.
  static double scale = 1.0;

  /// Scales [base] by [scale]. Returns [Duration.zero] when animations are
  /// disabled. Use in places where the duration is consumed outside the
  /// AnimationController pipeline (e.g. `Future.delayed` for hover timers).
  /// Tickers already respect `timeDilation` directly, so most call sites
  /// can keep their existing literal durations.
  static Duration scaled(Duration base) {
    if (scale == 0) return Duration.zero;
    return Duration(microseconds: (base.inMicroseconds * scale).round());
  }
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
