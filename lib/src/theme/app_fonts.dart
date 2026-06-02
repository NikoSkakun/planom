import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// The default font key — uses the system font (San Francisco on iOS).
const kSystemFontKey = 'system';

/// Supported fonts, in the order they appear in the picker. Keys are stable
/// identifiers persisted to the DB; values are the user-facing display names.
const Map<String, String> kAppFonts = {
  kSystemFontKey: 'System',
  'inter': 'Inter',
  'roboto': 'Roboto',
  'sourceSans3': 'Source Sans 3',
  'nunito': 'Nunito',
  'lora': 'Lora',
  'merriweather': 'Merriweather',
  'jetbrainsMono': 'JetBrains Mono',
};

/// Converts a camelCase Google Fonts key to a human-readable display name.
/// e.g. 'workSans' → 'Work Sans', 'sourceSans3' → 'Source Sans 3'
String fontDisplayName(String key) {
  if (key == kSystemFontKey) return 'System';
  return key
      .replaceAllMapped(
        RegExp(r'(?<=[a-z])([A-Z])'),
        (m) => ' ${m.group(1)}',
      )
      .replaceAllMapped(
        RegExp(r'(?<=[A-Za-z])(\d+)'),
        (m) => ' ${m.group(1)}',
      )
      .split(' ')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

TextStyle _applyFont(String key, TextStyle base, {Color? color}) {
  final styled = color != null ? base.copyWith(color: color) : base;
  final fontFn = GoogleFonts.asMap()[key];
  if (fontFn != null) return fontFn(textStyle: styled);
  return styled;
}

/// Builds a [CupertinoTextThemeData] with [fontKey] applied to every text
/// role used by Cupertino (body text, nav titles, action buttons, picker
/// labels, etc.).
///
/// When [color] is non-null it overrides the primary text color for the
/// reading roles (body, nav titles, picker text). Action / nav-action roles
/// keep their accent tint so buttons stay recognisable. [color] may be a
/// [CupertinoDynamicColor] so it resolves per brightness.
CupertinoTextThemeData buildCupertinoTextTheme(String fontKey, {Color? color}) {
  const defaults = CupertinoTextThemeData();
  final useFont = fontKey != kSystemFontKey;
  if (!useFont && color == null) return defaults;

  TextStyle role(TextStyle base, {bool tinted = false}) =>
      _applyFont(useFont ? fontKey : kSystemFontKey, base,
          color: tinted ? null : color);

  return CupertinoTextThemeData(
    textStyle: role(defaults.textStyle),
    actionTextStyle: role(defaults.actionTextStyle, tinted: true),
    tabLabelTextStyle: role(defaults.tabLabelTextStyle, tinted: true),
    navTitleTextStyle: role(defaults.navTitleTextStyle),
    navLargeTitleTextStyle: role(defaults.navLargeTitleTextStyle),
    navActionTextStyle: role(defaults.navActionTextStyle, tinted: true),
    pickerTextStyle: role(defaults.pickerTextStyle),
    dateTimePickerTextStyle: role(defaults.dateTimePickerTextStyle),
  );
}
