import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../localization/strings.dart';
import '../theme/app_fonts.dart';
import '../theme/appearance_prefs.dart';
import '../utils/color_picker.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'appearance_custom_view.dart';
import 'font_picker_view.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

// ── Preset palettes ───────────────────────────────────────────────────────────

const _kAccentOptions = [
  Color(0xFFFF4D00), // default orange-red
  Color(0xFFFF3B30), // iOS red
  Color(0xFFFF9500), // iOS orange
  Color(0xFFFFCC00), // iOS yellow
  Color(0xFF34C759), // iOS green
  Color(0xFF00C7BE), // iOS teal
  Color(0xFF30B0C7), // iOS cyan
  Color(0xFF007AFF), // iOS blue
  Color(0xFF5856D6), // iOS purple
  Color(0xFFAF52DE), // iOS magenta
  Color(0xFFFF2D55), // iOS pink
  Color(0xFFA2845E), // iOS brown
];

const _kCompletionOptions = [
  Color(0xFF34C759), // iOS green (default)
  Color(0xFF00C7BE), // iOS teal
  Color(0xFF007AFF), // iOS blue
  Color(0xFF5856D6), // iOS purple
  Color(0xFFFF9500), // iOS orange
  Color(0xFFFF2D55), // iOS pink
  Color(0xFF8E8E93), // iOS gray
];

// ── View ─────────────────────────────────────────────────────────────────────

class AppearanceView extends StatelessWidget {
  const AppearanceView({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.sectionAppearance),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          // Merge the main notifier (theme) with colorRevision so tapping an
          // accent/completion swatch still moves the checkmark — color changes
          // no longer fire the main notifier.
          listenable: Listenable.merge([controller, controller.colorRevision]),
          builder: (context, _) {
            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                // ── Theme ────────────────────────────────────────────────
                Text(
                  s.theme,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoSlidingSegmentedControl<ThemeMode>(
                  groupValue: controller.themeMode,
                  onValueChanged: controller.updateThemeMode,
                  children: {
                    ThemeMode.light: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(s.themeLight),
                    ),
                    ThemeMode.system: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(s.themeSystem),
                    ),
                    ThemeMode.dark: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(s.themeDark),
                    ),
                  },
                ),

                // ── Accent color ─────────────────────────────────────────
                const SizedBox(height: 32),
                Text(
                  s.accentColor,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                _ColorSwatchRow(
                  options: _kAccentOptions,
                  selected: controller.accentColor,
                  onSelect: controller.updateAccentColor,
                ),

                // ── Completion color ─────────────────────────────────────
                const SizedBox(height: 32),
                Text(
                  s.completionColor,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                _ColorSwatchRow(
                  options: _kCompletionOptions,
                  selected: controller.completionColor,
                  onSelect: controller.updateCompletionColor,
                ),

                // ── Font & custom colors ─────────────────────────────────
                const SizedBox(height: 32),
                Text(
                  s.sectionCustomization,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                SettingsNavRow(
                  label: s.font,
                  trailingLabel: controller.fontKey == kSystemFontKey
                      ? s.systemFont
                      : fontDisplayName(controller.fontKey),
                  onTap: () => Navigator.of(context).push(
                    FastRoute<void>(
                      builder: (_) => FontPickerView(controller: controller),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                SettingsNavRow(
                  label: s.background,
                  trailingLabel: _backgroundSummary(s, controller),
                  onTap: () => Navigator.of(context).push(
                    FastRoute<void>(
                      builder: (_) =>
                          BackgroundSettingsView(controller: controller),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                SettingsNavRow(
                  label: s.textColor,
                  trailingLabel: _textColorSummary(s, controller),
                  onTap: () => Navigator.of(context).push(
                    FastRoute<void>(
                      builder: (_) =>
                          TextColorSettingsView(controller: controller),
                    ),
                  ),
                ),

                // ── Text size ────────────────────────────────────────────
                const SizedBox(height: 32),
                Text(
                  s.textSize,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                SettingsToggleRow(
                  label: s.useSystemTextSize,
                  value: controller.useSystemTextScale,
                  onChanged: controller.updateUseSystemTextScale,
                ),
                if (!controller.useSystemTextScale) ...[
                  const SizedBox(height: 8),
                  _TextScaleRow(controller: controller),
                ],
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.textSizeHint,
                    style: TextStyle(fontSize: 13, color: labelColor),
                  ),
                ),

                // ── Animation speed ──────────────────────────────────────
                const SizedBox(height: 32),
                Text(
                  s.animationSpeed,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoSlidingSegmentedControl<AnimationSpeed>(
                  groupValue: controller.animationSpeed,
                  onValueChanged: (v) {
                    if (v != null) controller.updateAnimationSpeed(v);
                  },
                  children: {
                    AnimationSpeed.off: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(s.animationSpeedOff),
                    ),
                    AnimationSpeed.fast: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(s.animationSpeedFast),
                    ),
                    AnimationSpeed.normal: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(s.animationSpeedNormal),
                    ),
                    AnimationSpeed.slow: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(s.animationSpeedSlow),
                    ),
                  },
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.animationSpeedHint,
                    style: TextStyle(fontSize: 13, color: labelColor),
                  ),
                ),

                // ── Calendar ─────────────────────────────────────────────
                const SizedBox(height: 32),
                Text(
                  s.tabCalendar,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    letterSpacing: -0.08,
                  ),
                ),
                const SizedBox(height: 8),
                SettingsNavRow(
                  label: s.firstDayOfWeek,
                  trailingLabel: _firstDayLabel(s, controller.firstDayOfWeek),
                  onTap: () => _pickFirstDay(context, controller),
                ),
                const SizedBox(height: 1),
                SettingsNavRow(
                  label: s.dayBoundary,
                  trailingLabel: _hourLabel(controller.dayBoundaryHour),
                  onTap: () => _pickDayBoundary(context, controller),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.dayBoundaryHint,
                    style: TextStyle(fontSize: 13, color: labelColor),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _hourLabel(int h) {
    final hour = h % 24;
    final twoDigit = hour.toString().padLeft(2, '0');
    return '$twoDigit:00';
  }

  Future<void> _pickDayBoundary(
      BuildContext context, SettingsController controller) async {
    final s = S.of(context);
    final selected = await showSelectionMenu<int>(
      context: context,
      title: s.dayBoundary,
      current: controller.dayBoundaryHour,
      options: [
        for (var h = 0; h < 24; h++)
          SelectionMenuOption(value: h, label: _hourLabel(h)),
      ],
    );
    if (selected != null) await controller.updateDayBoundaryHour(selected);
  }

  static String _bgModeLabel(S s, BackgroundMode m) => switch (m) {
        BackgroundMode.solid => s.appearanceModeSolid,
        BackgroundMode.image => s.appearanceModeImage,
        BackgroundMode.dynamicColor => s.appearanceModeDynamic,
        BackgroundMode.defaultBg => s.appearanceModeDefault,
      };

  static String _backgroundSummary(S s, SettingsController controller) {
    final p = controller.appearancePrefs;
    final l = p.light.backgroundMode;
    final d = p.dark.backgroundMode;
    if (l == BackgroundMode.defaultBg && d == BackgroundMode.defaultBg) {
      return s.appearanceModeDefault;
    }
    if (l == d) return _bgModeLabel(s, l);
    // Light & dark differ — surface the non-default one (prefer the active-ish).
    final shown = l != BackgroundMode.defaultBg ? l : d;
    return _bgModeLabel(s, shown);
  }

  static String _textColorSummary(S s, SettingsController controller) {
    final p = controller.appearancePrefs;
    bool customized(ThemeAppearance a) =>
        a.autoFontColorFromBackground ||
        a.fontColorMode != FontColorMode.defaultColor;
    if (!customized(p.light) && !customized(p.dark)) {
      return s.appearanceModeDefault;
    }
    final a = customized(p.light) ? p.light : p.dark;
    if (a.autoFontColorFromBackground) return s.autoTextColor;
    return a.fontColorMode == FontColorMode.dynamicColor
        ? s.appearanceModeDynamic
        : s.appearanceModeSolid;
  }

  static String _firstDayLabel(S s, int day) {
    final long = kWeekdaysLong[s.locale.languageCode] ?? kWeekdaysLong['en']!;
    // long is Mon=0..Sun=6; ISO day is 1..7
    return long[(day - 1).clamp(0, 6)];
  }

  Future<void> _pickFirstDay(
      BuildContext context, SettingsController controller) async {
    final s = S.of(context);
    final selected = await showSelectionMenu<int>(
      context: context,
      title: s.firstDayOfWeek,
      current: controller.firstDayOfWeek,
      options: [
        for (var d = 1; d <= 7; d++)
          SelectionMenuOption(value: d, label: _firstDayLabel(s, d)),
      ],
    );
    if (selected != null) await controller.updateFirstDayOfWeek(selected);
  }
}

// ── Text scale ────────────────────────────────────────────────────────────────

class _TextScaleRow extends StatelessWidget {
  const _TextScaleRow({required this.controller});

  final SettingsController controller;

  static const _presets = <double>[0.85, 1.0, 1.15, 1.3, 1.5];

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('A', style: TextStyle(fontSize: 13)),
              Text('A', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 4),
          // CupertinoSlider with discrete preset stops. We compute the nearest
          // preset on commit so the value snaps to a clean number.
          CupertinoSlider(
            value: controller.textScale,
            min: _presets.first,
            max: _presets.last,
            divisions: _presets.length - 1,
            onChanged: (v) {
              final nearest = _presets.reduce((a, b) =>
                  (a - v).abs() < (b - v).abs() ? a : b);
              if (nearest != controller.textScale) {
                controller.updateTextScale(nearest);
              }
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final p in _presets)
                Text(
                  '${(p * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: p == controller.textScale
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: p == controller.textScale
                        ? CupertinoColors.label.resolveFrom(context)
                        : CupertinoColors.tertiaryLabel.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Swatch row ────────────────────────────────────────────────────────────────

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<Color> options;
  final Color selected;
  final ValueChanged<Color> onSelect;

  Future<void> _showCustomPicker(BuildContext context) async {
    final picked = await showCustomColorPicker(
      context,
      initialColor: selected,
      title: S.of(context).customColor,
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    final isPresetSelected =
        options.any((c) => c.value == selected.value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ...options.map((c) => _Swatch(
                color: c,
                isSelected: c.value == selected.value,
                onTap: () => onSelect(c),
                context: context,
              )),
          _CustomSwatch(
            // When the active color isn't one of the presets, the user already
            // has a custom one — show the live color inside the rainbow ring.
            currentColor: isPresetSelected ? null : selected,
            onTap: () => _showCustomPicker(context),
            context: context,
          ),
        ],
      ),
    );
  }
}

/// Rainbow-bordered swatch that opens the HSV color picker. If the current
/// theme color isn't one of the presets, the centre fills with that color
/// (and shows a checkmark) so the user can see their custom choice.
class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({
    required this.currentColor,
    required this.onTap,
    required this.context,
  });

  final Color? currentColor;
  final VoidCallback onTap;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentColor ??
                CupertinoColors.systemBackground.resolveFrom(context),
          ),
          child: currentColor != null
              ? const Icon(
                  CupertinoIcons.checkmark,
                  size: 16,
                  color: CupertinoColors.white,
                )
              : null,
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.context,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: isSelected
              ? Border.all(
                  color: CupertinoColors.label.resolveFrom(context),
                  width: 2.5,
                )
              : null,
        ),
        child: isSelected
            ? const Icon(CupertinoIcons.checkmark,
                size: 16, color: CupertinoColors.white)
            : null,
      ),
    );
  }
}
