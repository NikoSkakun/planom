/// Money helpers for the Finance feature.
///
/// Amounts are stored as **integer minor units** (e.g. cents) to avoid binary
/// floating-point drift on sums. [Currency] knows how many minor units make a
/// major unit so a JPY value (0 decimals) and a USD value (2 decimals) both
/// round-trip correctly.
class Currency {
  const Currency(this.code, this.symbol, this.name, {this.decimals = 2});

  final String code; // ISO-4217, e.g. 'USD'
  final String symbol; // e.g. '$'
  final String name; // e.g. 'US Dollar'
  final int decimals; // minor units per major unit exponent (2 → cents)

  int get _scale {
    var s = 1;
    for (var i = 0; i < decimals; i++) {
      s *= 10;
    }
    return s;
  }

  /// Parses user-typed text (e.g. "12.50") into minor units (1250). Tolerates
  /// thousands separators, a leading currency symbol, and comma decimals.
  int? parse(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(symbol, '').replaceAll(' ', '');
    // If both separators present, the last one is the decimal separator.
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      // Comma only: treat as decimal separator when it looks like one.
      final after = s.length - lastComma - 1;
      s = (after == 3 && !s.contains(' '))
          ? s.replaceAll(',', '') // likely a thousands group
          : s.replaceAll(',', '.');
    }
    final value = double.tryParse(s);
    if (value == null) return null;
    return (value * _scale).round();
  }

  /// Formats minor units as a major-unit string without the symbol, e.g.
  /// `1234567` (cents) → `12,345.67`.
  String formatPlain(int minor, {bool grouped = true}) {
    final negative = minor < 0;
    final abs = minor.abs();
    final major = abs ~/ _scale;
    final frac = abs % _scale;
    var intPart = major.toString();
    if (grouped) {
      final buf = StringBuffer();
      final digits = intPart.split('');
      for (var i = 0; i < digits.length; i++) {
        if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
        buf.write(digits[i]);
      }
      intPart = buf.toString();
    }
    final sign = negative ? '-' : '';
    if (decimals == 0) return '$sign$intPart';
    final fracStr = frac.toString().padLeft(decimals, '0');
    return '$sign$intPart.$fracStr';
  }

  /// Formats minor units with the currency symbol, e.g. `$12,345.67`.
  String format(int minor, {bool grouped = true, bool showSign = false}) {
    final sign = showSign && minor > 0 ? '+' : '';
    if (minor < 0) {
      return '-$symbol${formatPlain(minor.abs(), grouped: grouped)}';
    }
    return '$sign$symbol${formatPlain(minor, grouped: grouped)}';
  }
}

/// A small but practical catalogue of world currencies. Lookup is by ISO code;
/// unknown codes resolve to a generic 2-decimal currency using the code as its
/// own symbol so the app never crashes on an unfamiliar code.
class Currencies {
  static const List<Currency> all = [
    Currency('USD', '\$', 'US Dollar'),
    Currency('EUR', '€', 'Euro'),
    Currency('GBP', '£', 'British Pound'),
    Currency('JPY', '¥', 'Japanese Yen', decimals: 0),
    Currency('CNY', '¥', 'Chinese Yuan'),
    Currency('CHF', 'Fr', 'Swiss Franc'),
    Currency('CAD', 'C\$', 'Canadian Dollar'),
    Currency('AUD', 'A\$', 'Australian Dollar'),
    Currency('NZD', 'NZ\$', 'New Zealand Dollar'),
    Currency('INR', '₹', 'Indian Rupee'),
    Currency('UAH', '₴', 'Ukrainian Hryvnia'),
    Currency('PLN', 'zł', 'Polish Zloty'),
    Currency('CZK', 'Kč', 'Czech Koruna'),
    Currency('SEK', 'kr', 'Swedish Krona'),
    Currency('NOK', 'kr', 'Norwegian Krone'),
    Currency('DKK', 'kr', 'Danish Krone'),
    Currency('RUB', '₽', 'Russian Ruble'),
    Currency('TRY', '₺', 'Turkish Lira'),
    Currency('BRL', 'R\$', 'Brazilian Real'),
    Currency('MXN', 'MX\$', 'Mexican Peso'),
    Currency('ARS', '\$', 'Argentine Peso'),
    Currency('ZAR', 'R', 'South African Rand'),
    Currency('KRW', '₩', 'South Korean Won', decimals: 0),
    Currency('SGD', 'S\$', 'Singapore Dollar'),
    Currency('HKD', 'HK\$', 'Hong Kong Dollar'),
    Currency('AED', 'د.إ', 'UAE Dirham'),
    Currency('SAR', '﷼', 'Saudi Riyal'),
    Currency('ILS', '₪', 'Israeli Shekel'),
    Currency('THB', '฿', 'Thai Baht'),
    Currency('IDR', 'Rp', 'Indonesian Rupiah', decimals: 0),
    Currency('PHP', '₱', 'Philippine Peso'),
    Currency('MYR', 'RM', 'Malaysian Ringgit'),
    Currency('VND', '₫', 'Vietnamese Dong', decimals: 0),
  ];

  static Currency byCode(String code) {
    final upper = code.toUpperCase();
    for (final c in all) {
      if (c.code == upper) return c;
    }
    return Currency(upper, upper, upper);
  }

  /// Best-guess default currency for a BCP-47 [languageCode].
  static String defaultForLanguage(String languageCode) {
    switch (languageCode) {
      case 'uk':
        return 'UAH';
      case 'es':
        return 'EUR';
      case 'fr':
        return 'EUR';
      case 'de':
        return 'EUR';
      case 'it':
        return 'EUR';
      case 'pt':
        return 'BRL';
      case 'ru':
        return 'RUB';
      case 'zh':
        return 'CNY';
      case 'ja':
        return 'JPY';
      default:
        return 'USD';
    }
  }
}
