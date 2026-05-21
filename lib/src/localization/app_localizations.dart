import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'strings.dart';

/// Thin delegate that registers the supported locales with Flutter's
/// `Localizations` system. The actual translations live in `strings.dart`
/// and are accessed via `S.of(context)`.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  String get appTitle => S(locale).appTitle;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static List<Locale> get supportedLocales => kSupportedLocales;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      kSupportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
