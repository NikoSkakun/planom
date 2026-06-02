import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_background.dart';
import '../theme/appearance_prefs.dart';
import '../utils/color_picker.dart';
import 'dynamic_color_editor.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

// Shared swatch palettes for the solid-color pickers.
const _kBackgroundSwatches = [
  Color(0xFFFFFFFF), Color(0xFFF2F2F7), Color(0xFFEDE7DD), Color(0xFFE3F0E8),
  Color(0xFFE5EEF7), Color(0xFFF3E8F0), Color(0xFF1C1C1E), Color(0xFF000000),
  Color(0xFF101522), Color(0xFF1A1410),
];

const _kTextSwatches = [
  Color(0xFF000000), Color(0xFF1C1C1E), Color(0xFF3A3A3C), Color(0xFF6E6E73),
  Color(0xFFFFFFFF), Color(0xFFE5E5EA), Color(0xFFFF3B30), Color(0xFF007AFF),
  Color(0xFF34C759), Color(0xFFAF52DE),
];

// ── Background ────────────────────────────────────────────────────────────────

class BackgroundSettingsView extends StatefulWidget {
  const BackgroundSettingsView({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<BackgroundSettingsView> createState() => _BackgroundSettingsViewState();
}

class _BackgroundSettingsViewState extends State<BackgroundSettingsView> {
  late AppearancePrefs _prefs;
  bool _editingDark = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _prefs = widget.controller.appearancePrefs.copy();
  }

  ThemeAppearance get _current => _prefs.forBrightness(_editingDark);

  void _commit() {
    setState(() {});
    widget.controller.updateAppearancePrefs(_prefs.copy());
  }

  Future<void> _pickImage() async {
    setState(() => _picking = true);
    try {
      final path = await pickBackgroundImage();
      if (!mounted) return;
      if (path != null) {
        _current.backgroundImagePath = path;
        _current.backgroundMode = BackgroundMode.image;
        _commit();
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final a = _current;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(border: null, middle: Text(s.background)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _BrightnessSelector(
              isDark: _editingDark,
              onChanged: (v) => setState(() => _editingDark = v),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(s.backgroundHint,
                  style: TextStyle(fontSize: 13, color: labelColor)),
            ),
            const SizedBox(height: 20),
            _ModeSelector<BackgroundMode>(
              value: a.backgroundMode,
              segments: {
                BackgroundMode.defaultBg: s.appearanceModeDefault,
                BackgroundMode.solid: s.appearanceModeSolid,
                BackgroundMode.image: s.appearanceModeImage,
                BackgroundMode.dynamicColor: s.appearanceModeDynamic,
              },
              onChanged: (m) {
                a.backgroundMode = m;
                _commit();
              },
            ),
            const SizedBox(height: 20),
            ..._modeBody(s, a),
          ],
        ),
      ),
    );
  }

  List<Widget> _modeBody(S s, ThemeAppearance a) {
    switch (a.backgroundMode) {
      case BackgroundMode.defaultBg:
        return const [];
      case BackgroundMode.solid:
        return [
          _SolidColorPicker(
            swatches: _kBackgroundSwatches,
            selected: a.backgroundColor,
            onSelect: (c) {
              a.backgroundColor = c;
              _commit();
            },
          ),
        ];
      case BackgroundMode.image:
        return [_imageBody(s, a)];
      case BackgroundMode.dynamicColor:
        return [
          DynamicColorEditor(
            timeline: a.backgroundDynamic,
            onChanged: (t) {
              a.backgroundDynamic = t;
              _commit();
            },
          ),
        ];
    }
  }

  Widget _imageBody(S s, ThemeAppearance a) {
    final path = resolveBackgroundImagePath(a.backgroundImagePath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (path != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  alignment: Alignment.center,
                  child: Icon(CupertinoIcons.photo,
                      size: 40,
                      color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
                ),
              ),
            ),
          ),
        if (path != null) const SizedBox(height: 12),
        SettingsNavRow(
          label: path == null ? s.chooseImage : s.changeImage,
          onTap: _picking ? () {} : _pickImage,
        ),
        if (path != null) ...[
          const SizedBox(height: 1),
          GestureDetector(
            onTap: () {
              a.backgroundImagePath = null;
              a.backgroundMode = BackgroundMode.defaultBg;
              _commit();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                s.removeImage,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Text color ────────────────────────────────────────────────────────────────

class TextColorSettingsView extends StatefulWidget {
  const TextColorSettingsView({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<TextColorSettingsView> createState() => _TextColorSettingsViewState();
}

class _TextColorSettingsViewState extends State<TextColorSettingsView> {
  late AppearancePrefs _prefs;
  bool _editingDark = false;

  @override
  void initState() {
    super.initState();
    _prefs = widget.controller.appearancePrefs.copy();
  }

  ThemeAppearance get _current => _prefs.forBrightness(_editingDark);

  void _commit() {
    setState(() {});
    widget.controller.updateAppearancePrefs(_prefs.copy());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final a = _current;
    final auto = a.autoFontColorFromBackground;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(border: null, middle: Text(s.textColor)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _BrightnessSelector(
              isDark: _editingDark,
              onChanged: (v) => setState(() => _editingDark = v),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(s.textColorHint,
                  style: TextStyle(fontSize: 13, color: labelColor)),
            ),
            const SizedBox(height: 20),
            SettingsToggleRow(
              label: s.autoTextColor,
              value: auto,
              onChanged: (v) {
                a.autoFontColorFromBackground = v;
                _commit();
              },
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(s.autoTextColorHint,
                  style: TextStyle(fontSize: 13, color: labelColor)),
            ),
            if (!auto) ...[
              const SizedBox(height: 20),
              _ModeSelector<FontColorMode>(
                value: a.fontColorMode,
                segments: {
                  FontColorMode.defaultColor: s.appearanceModeDefault,
                  FontColorMode.solid: s.appearanceModeSolid,
                  FontColorMode.dynamicColor: s.appearanceModeDynamic,
                },
                onChanged: (m) {
                  a.fontColorMode = m;
                  _commit();
                },
              ),
              const SizedBox(height: 20),
              ..._modeBody(a),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _modeBody(ThemeAppearance a) {
    switch (a.fontColorMode) {
      case FontColorMode.defaultColor:
        return const [];
      case FontColorMode.solid:
        return [
          _SolidColorPicker(
            swatches: _kTextSwatches,
            selected: a.fontColor,
            onSelect: (c) {
              a.fontColor = c;
              _commit();
            },
          ),
        ];
      case FontColorMode.dynamicColor:
        return [
          DynamicColorEditor(
            timeline: a.fontColorDynamic,
            onChanged: (t) {
              a.fontColorDynamic = t;
              _commit();
            },
          ),
        ];
    }
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _BrightnessSelector extends StatelessWidget {
  const _BrightnessSelector({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoSlidingSegmentedControl<bool>(
      groupValue: isDark,
      onValueChanged: (v) {
        if (v != null) onChanged(v);
      },
      children: {
        false: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(s.themeLight),
        ),
        true: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(s.themeDark),
        ),
      },
    );
  }
}

class _ModeSelector<T extends Object> extends StatelessWidget {
  const _ModeSelector({
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
        children: {
          for (final entry in segments.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(entry.value,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
        },
      ),
    );
  }
}

class _SolidColorPicker extends StatelessWidget {
  const _SolidColorPicker({
    required this.swatches,
    required this.selected,
    required this.onSelect,
  });

  final List<Color> swatches;
  final Color selected;
  final ValueChanged<Color> onSelect;

  Future<void> _custom(BuildContext context) async {
    final picked = await showCustomColorPicker(
      context,
      initialColor: selected,
      title: S.of(context).customColor,
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isPreset = swatches.any((c) => c.value == selected.value);
    final bg = CupertinoColors.tertiarySystemBackground.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in swatches)
            _Swatch(
              color: c,
              isSelected: c.value == selected.value,
              onTap: () => onSelect(c),
            ),
          _CustomSwatch(
            currentColor: isPreset ? null : selected,
            onTap: () => _custom(context),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(
      {required this.color, required this.isSelected, required this.onTap});

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: isSelected
                ? CupertinoColors.label.resolveFrom(context)
                : CupertinoColors.separator.resolveFrom(context),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: isSelected
            ? Icon(CupertinoIcons.checkmark,
                size: 16,
                color: color.computeLuminance() > 0.5
                    ? CupertinoColors.black
                    : CupertinoColors.white)
            : null,
      ),
    );
  }
}

class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({required this.currentColor, required this.onTap});

  final Color? currentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ]),
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentColor ??
                CupertinoColors.systemBackground.resolveFrom(context),
          ),
          child: currentColor != null
              ? Icon(CupertinoIcons.checkmark,
                  size: 16,
                  color: currentColor!.computeLuminance() > 0.5
                      ? CupertinoColors.black
                      : CupertinoColors.white)
              : null,
        ),
      ),
    );
  }
}
