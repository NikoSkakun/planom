/// One entry in the currency catalogue.
///
/// [decimals] is the number of fractional digits the currency is normally
/// written with. Amounts are always *stored* as hundredths regardless (see
/// [FinanceTransaction.amount]); a zero-decimal currency simply renders
/// without the fractional part.
class Currency {
  const Currency(this.code, this.symbol, this.name, {this.decimals = 2});

  final String code;
  final String symbol;
  final String name;
  final int decimals;
}

/// Currencies offered when creating an account or picking the space default.
/// Not exhaustive — a code that isn't here still works, it just renders with
/// its code instead of a symbol.
const List<Currency> kCurrencies = [
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('UAH', '₴', 'Ukrainian Hryvnia'),
  Currency('PLN', 'zł', 'Polish Złoty'),
  Currency('CHF', 'CHF', 'Swiss Franc'),
  Currency('CZK', 'Kč', 'Czech Koruna'),
  Currency('SEK', 'kr', 'Swedish Krona'),
  Currency('NOK', 'kr', 'Norwegian Krone'),
  Currency('DKK', 'kr', 'Danish Krone'),
  Currency('CAD', r'C$', 'Canadian Dollar'),
  Currency('AUD', r'A$', 'Australian Dollar'),
  Currency('NZD', r'NZ$', 'New Zealand Dollar'),
  Currency('JPY', '¥', 'Japanese Yen', decimals: 0),
  Currency('CNY', '¥', 'Chinese Yuan'),
  Currency('KRW', '₩', 'South Korean Won', decimals: 0),
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('BRL', r'R$', 'Brazilian Real'),
  Currency('MXN', r'MX$', 'Mexican Peso'),
  Currency('TRY', '₺', 'Turkish Lira'),
  Currency('ILS', '₪', 'Israeli Shekel'),
  Currency('ZAR', 'R', 'South African Rand'),
  Currency('SGD', r'S$', 'Singapore Dollar'),
  Currency('HKD', r'HK$', 'Hong Kong Dollar'),
  Currency('AED', 'AED', 'UAE Dirham'),
  Currency('THB', '฿', 'Thai Baht'),
  Currency('IDR', 'Rp', 'Indonesian Rupiah', decimals: 0),
  Currency('PHP', '₱', 'Philippine Peso'),
  Currency('VND', '₫', 'Vietnamese Dong', decimals: 0),
  Currency('RON', 'lei', 'Romanian Leu'),
  Currency('HUF', 'Ft', 'Hungarian Forint', decimals: 0),
  Currency('BGN', 'лв', 'Bulgarian Lev'),
  Currency('RSD', 'дин', 'Serbian Dinar'),
  Currency('KZT', '₸', 'Kazakhstani Tenge'),
  Currency('GEL', '₾', 'Georgian Lari'),
];

/// Looks a code up in the catalogue; null when it isn't a known currency.
Currency? currencyByCode(String? code) {
  if (code == null) return null;
  final upper = code.toUpperCase();
  for (final c in kCurrencies) {
    if (c.code == upper) return c;
  }
  return null;
}

/// Symbol for [code], falling back to the code itself so an unknown or
/// user-typed currency still renders something meaningful.
String currencySymbol(String? code) =>
    currencyByCode(code)?.symbol ?? (code ?? '').toUpperCase();

/// Fractional digits for [code] (2 unless the catalogue says otherwise).
int currencyDecimals(String? code) => currencyByCode(code)?.decimals ?? 2;
