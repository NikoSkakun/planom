// User-customisable appearance overrides for the app background and the global
// font (text) color, configured independently for the light and dark themes.
// Persisted as a single JSON string under the `appearance_prefs` app-setting
// key. Each of background and font color supports the app default plus override
// modes: a single solid color, a user-loaded photo (background only), or a
// time-of-day [DynamicColorTimeline] that interpolates linearly between color
// stops placed across the day.
import 'dart:convert';

import 'package:flutter/cupertino.dart';

/// Storage key for the serialized [AppearancePrefs] in `app_settings`.
const String kAppearancePrefsKey = 'appearance_prefs';

enum BackgroundMode { defaultBg, solid, image, dynamicColor }

enum FontColorMode { defaultColor, solid, dynamicColor }

String _bgModeToString(BackgroundMode m) => switch (m) {
      BackgroundMode.defaultBg => 'default',
      BackgroundMode.solid => 'solid',
      BackgroundMode.image => 'image',
      BackgroundMode.dynamicColor => 'dynamic',
    };

BackgroundMode _bgModeFromString(String? s) => switch (s) {
      'solid' => BackgroundMode.solid,
      'image' => BackgroundMode.image,
      'dynamic' => BackgroundMode.dynamicColor,
      _ => BackgroundMode.defaultBg,
    };

String _fcModeToString(FontColorMode m) => switch (m) {
      FontColorMode.defaultColor => 'default',
      FontColorMode.solid => 'solid',
      FontColorMode.dynamicColor => 'dynamic',
    };

FontColorMode _fcModeFromString(String? s) => switch (s) {
      'solid' => FontColorMode.solid,
      'dynamic' => FontColorMode.dynamicColor,
      _ => FontColorMode.defaultColor,
    };

/// A single (time-of-day, color) anchor on a [DynamicColorTimeline].
class ColorStop {
  const ColorStop(this.minute, this.color);

  /// Minute of the day in `0..1439`.
  final int minute;
  final Color color;

  ColorStop copyWith({int? minute, Color? color}) =>
      ColorStop(minute ?? this.minute, color ?? this.color);

  List<dynamic> toJson() => [minute, color.value];

  static ColorStop fromJson(List<dynamic> j) =>
      ColorStop((j[0] as num).toInt().clamp(0, 1439), Color((j[1] as num).toInt()));
}

/// An ordered set of [ColorStop]s describing how a color changes over the
/// course of a day. Between two adjacent stops the color is linearly
/// interpolated; after the last stop it wraps smoothly back to the first
/// (crossing midnight) so the timeline is continuous.
class DynamicColorTimeline {
  DynamicColorTimeline(List<ColorStop> stops)
      : stops = (List<ColorStop>.of(stops)..sort((a, b) => a.minute.compareTo(b.minute)));

  final List<ColorStop> stops;

  bool get isEmpty => stops.isEmpty;

  /// Resolves the interpolated color at [minute] (`0..1439`).
  Color colorAt(int minute) {
    if (stops.isEmpty) return const Color(0xFF000000);
    if (stops.length == 1) return stops.first.color;

    final m = minute.clamp(0, 1439);
    // Before the first stop or at/after the last stop → wrap-around segment
    // that bridges the last stop to the first across midnight.
    if (m < stops.first.minute || m >= stops.last.minute) {
      final last = stops.last;
      final first = stops.first;
      final span = (1440 - last.minute) + first.minute;
      if (span == 0) return first.color;
      final elapsed = m >= last.minute ? m - last.minute : (1440 - last.minute) + m;
      return Color.lerp(last.color, first.color, elapsed / span)!;
    }
    for (var i = 0; i < stops.length - 1; i++) {
      final a = stops[i];
      final b = stops[i + 1];
      if (m >= a.minute && m < b.minute) {
        final span = b.minute - a.minute;
        if (span == 0) return a.color;
        return Color.lerp(a.color, b.color, (m - a.minute) / span)!;
      }
    }
    return stops.last.color;
  }

  DynamicColorTimeline copy() => DynamicColorTimeline(stops);

  List<dynamic> toJson() => stops.map((s) => s.toJson()).toList();

  static DynamicColorTimeline fromJson(dynamic j) {
    if (j is! List || j.isEmpty) return DynamicColorTimeline(const []);
    return DynamicColorTimeline(
        j.map((e) => ColorStop.fromJson(e as List<dynamic>)).toList());
  }

  /// A pleasant default background timeline (deep night → daylight → dusk).
  static DynamicColorTimeline defaultBackground(bool isDark) => isDark
      ? DynamicColorTimeline(const [
          ColorStop(0, Color(0xFF05060A)),
          ColorStop(7 * 60, Color(0xFF161A26)),
          ColorStop(13 * 60, Color(0xFF1C2233)),
          ColorStop(19 * 60, Color(0xFF221821)),
          ColorStop(22 * 60, Color(0xFF0A0710)),
        ])
      : DynamicColorTimeline(const [
          ColorStop(0, Color(0xFFE9ECF5)),
          ColorStop(7 * 60, Color(0xFFFFF4E2)),
          ColorStop(13 * 60, Color(0xFFFFFFFF)),
          ColorStop(19 * 60, Color(0xFFFCE8DA)),
          ColorStop(22 * 60, Color(0xFFE4E6F0)),
        ]);

  /// A default font-color timeline (subtle warm/cool drift).
  static DynamicColorTimeline defaultFontColor(bool isDark) => isDark
      ? DynamicColorTimeline(const [
          ColorStop(0, Color(0xFFD8DCE6)),
          ColorStop(12 * 60, Color(0xFFFFFFFF)),
          ColorStop(20 * 60, Color(0xFFE8DDD2)),
        ])
      : DynamicColorTimeline(const [
          ColorStop(0, Color(0xFF1B2030)),
          ColorStop(12 * 60, Color(0xFF000000)),
          ColorStop(20 * 60, Color(0xFF2A1E18)),
        ]);
}

/// All appearance overrides for a single brightness (light or dark).
class ThemeAppearance {
  ThemeAppearance({
    required this.isDark,
    BackgroundMode? backgroundMode,
    Color? backgroundColor,
    this.backgroundImagePath,
    DynamicColorTimeline? backgroundDynamic,
    FontColorMode? fontColorMode,
    Color? fontColor,
    DynamicColorTimeline? fontColorDynamic,
    this.autoFontColorFromBackground = false,
  })  : backgroundMode = backgroundMode ?? BackgroundMode.defaultBg,
        backgroundColor = backgroundColor ??
            (isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF)),
        backgroundDynamic =
            backgroundDynamic ?? DynamicColorTimeline.defaultBackground(isDark),
        fontColorMode = fontColorMode ?? FontColorMode.defaultColor,
        fontColor = fontColor ??
            (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000)),
        fontColorDynamic =
            fontColorDynamic ?? DynamicColorTimeline.defaultFontColor(isDark);

  final bool isDark;

  BackgroundMode backgroundMode;
  Color backgroundColor;
  String? backgroundImagePath;
  DynamicColorTimeline backgroundDynamic;

  FontColorMode fontColorMode;
  Color fontColor;
  DynamicColorTimeline fontColorDynamic;
  bool autoFontColorFromBackground;

  bool get usesDynamic =>
      backgroundMode == BackgroundMode.dynamicColor ||
      fontColorMode == FontColorMode.dynamicColor;

  bool get usesImageBackground => backgroundMode == BackgroundMode.image;

  /// The flat background color at [minute], or null when the app default
  /// should be used or an image background is in effect (handled separately).
  Color? backgroundColorAt(int minute) {
    switch (backgroundMode) {
      case BackgroundMode.solid:
        return backgroundColor;
      case BackgroundMode.dynamicColor:
        return backgroundDynamic.colorAt(minute);
      case BackgroundMode.image:
      case BackgroundMode.defaultBg:
        return null;
    }
  }

  /// The effective font color at [minute], or null to keep the app default.
  Color? fontColorAt(int minute) {
    if (autoFontColorFromBackground) {
      final bg = backgroundColorAt(minute);
      if (bg != null) return _contrastingColor(bg);
      // No resolvable background color (image/default) → keep default label.
      return null;
    }
    switch (fontColorMode) {
      case FontColorMode.solid:
        return fontColor;
      case FontColorMode.dynamicColor:
        return fontColorDynamic.colorAt(minute);
      case FontColorMode.defaultColor:
        return null;
    }
  }

  ThemeAppearance copy() => ThemeAppearance(
        isDark: isDark,
        backgroundMode: backgroundMode,
        backgroundColor: backgroundColor,
        backgroundImagePath: backgroundImagePath,
        backgroundDynamic: backgroundDynamic.copy(),
        fontColorMode: fontColorMode,
        fontColor: fontColor,
        fontColorDynamic: fontColorDynamic.copy(),
        autoFontColorFromBackground: autoFontColorFromBackground,
      );

  Map<String, dynamic> toJson() => {
        'bgMode': _bgModeToString(backgroundMode),
        'bgColor': backgroundColor.value,
        if (backgroundImagePath != null) 'bgImage': backgroundImagePath,
        'bgDynamic': backgroundDynamic.toJson(),
        'fcMode': _fcModeToString(fontColorMode),
        'fcColor': fontColor.value,
        'fcDynamic': fontColorDynamic.toJson(),
        'autoFc': autoFontColorFromBackground,
      };

  static ThemeAppearance fromJson(bool isDark, Map<String, dynamic>? j) {
    if (j == null) return ThemeAppearance(isDark: isDark);
    return ThemeAppearance(
      isDark: isDark,
      backgroundMode: _bgModeFromString(j['bgMode'] as String?),
      backgroundColor:
          j['bgColor'] is num ? Color((j['bgColor'] as num).toInt()) : null,
      backgroundImagePath: j['bgImage'] as String?,
      backgroundDynamic: j['bgDynamic'] != null
          ? DynamicColorTimeline.fromJson(j['bgDynamic'])
          : null,
      fontColorMode: _fcModeFromString(j['fcMode'] as String?),
      fontColor:
          j['fcColor'] is num ? Color((j['fcColor'] as num).toInt()) : null,
      fontColorDynamic: j['fcDynamic'] != null
          ? DynamicColorTimeline.fromJson(j['fcDynamic'])
          : null,
      autoFontColorFromBackground: j['autoFc'] == true,
    );
  }
}

/// Top-level appearance prefs holding a [ThemeAppearance] for each brightness.
class AppearancePrefs {
  AppearancePrefs({ThemeAppearance? light, ThemeAppearance? dark})
      : light = light ?? ThemeAppearance(isDark: false),
        dark = dark ?? ThemeAppearance(isDark: true);

  final ThemeAppearance light;
  final ThemeAppearance dark;

  ThemeAppearance forBrightness(bool isDark) => isDark ? dark : light;

  /// True when any brightness uses a time-of-day dynamic color, so callers
  /// know whether a per-minute refresh timer is needed.
  bool get usesDynamic => light.usesDynamic || dark.usesDynamic;

  /// All background image relative paths currently referenced (for storage
  /// bookkeeping / cleanup).
  List<String> get referencedImages => [
        if (light.usesImageBackground && light.backgroundImagePath != null)
          light.backgroundImagePath!,
        if (dark.usesImageBackground && dark.backgroundImagePath != null)
          dark.backgroundImagePath!,
      ];

  AppearancePrefs copy() =>
      AppearancePrefs(light: light.copy(), dark: dark.copy());

  String toJsonString() =>
      jsonEncode({'light': light.toJson(), 'dark': dark.toJson()});

  static AppearancePrefs fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return AppearancePrefs();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppearancePrefs(
        light: ThemeAppearance.fromJson(false, map['light'] as Map<String, dynamic>?),
        dark: ThemeAppearance.fromJson(true, map['dark'] as Map<String, dynamic>?),
      );
    } catch (_) {
      return AppearancePrefs();
    }
  }
}

/// Returns black or white, whichever contrasts better with [bg].
Color _contrastingColor(Color bg) =>
    bg.computeLuminance() > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
