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

TextStyle _applyFont(String key, TextStyle base) {
  final fontFn = GoogleFonts.asMap()[key];
  if (fontFn != null) return fontFn(textStyle: base);
  return base;
}

/// Builds a [CupertinoTextThemeData] with [fontKey] applied to every text
/// role used by Cupertino (body text, nav titles, action buttons, picker
/// labels, etc.).
CupertinoTextThemeData buildCupertinoTextTheme(String fontKey) {
  const defaults = CupertinoTextThemeData();
  if (fontKey == kSystemFontKey) return defaults;
  return CupertinoTextThemeData(
    textStyle: _applyFont(fontKey, defaults.textStyle),
    actionTextStyle: _applyFont(fontKey, defaults.actionTextStyle),
    tabLabelTextStyle: _applyFont(fontKey, defaults.tabLabelTextStyle),
    navTitleTextStyle: _applyFont(fontKey, defaults.navTitleTextStyle),
    navLargeTitleTextStyle:
        _applyFont(fontKey, defaults.navLargeTitleTextStyle),
    navActionTextStyle: _applyFont(fontKey, defaults.navActionTextStyle),
    pickerTextStyle: _applyFont(fontKey, defaults.pickerTextStyle),
    dateTimePickerTextStyle:
        _applyFont(fontKey, defaults.dateTimePickerTextStyle),
  );
}
