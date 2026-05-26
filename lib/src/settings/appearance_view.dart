import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../utils/selection_menu.dart';
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
              ],
            );
          },
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options
            .map((c) => _Swatch(
                  color: c,
                  isSelected: c.value == selected.value,
                  onTap: () => onSelect(c),
                  context: context,
                ))
            .toList(),
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
