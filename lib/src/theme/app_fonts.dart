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

TextStyle _applyFont(String key, TextStyle base) {
  switch (key) {
    case 'inter':
      return GoogleFonts.inter(textStyle: base);
    case 'roboto':
      return GoogleFonts.roboto(textStyle: base);
    case 'sourceSans3':
      return GoogleFonts.sourceSans3(textStyle: base);
    case 'nunito':
      return GoogleFonts.nunito(textStyle: base);
    case 'lora':
      return GoogleFonts.lora(textStyle: base);
    case 'merriweather':
      return GoogleFonts.merriweather(textStyle: base);
    case 'jetbrainsMono':
      return GoogleFonts.jetBrainsMono(textStyle: base);
    default:
      return base;
  }
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
