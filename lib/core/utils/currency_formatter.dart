import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  /// Formats amount into "Rp18.000" format
  static String format(num amount) {
    return _formatter.format(amount).replaceAll(' ', '');
  }
}
