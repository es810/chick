import 'package:intl/intl.dart';

/// Formats amounts in Egyptian Pounds (EGP).
class CurrencyFormatter {
  static String format(
    num amount, {
    String languageCode = 'en',
    int decimalDigits = 2,
  }) {
    final symbol = languageCode == 'ar' ? 'ج.م' : 'EGP';
    final pattern = decimalDigits > 0
        ? '#,##0.${'0' * decimalDigits}'
        : '#,##0';
    final formatted = NumberFormat(pattern, 'en_US').format(amount);
    return languageCode == 'ar' ? '$formatted $symbol' : '$symbol $formatted';
  }

  static String compact(num amount, {String languageCode = 'en'}) {
    return format(amount, languageCode: languageCode, decimalDigits: 0);
  }
}
