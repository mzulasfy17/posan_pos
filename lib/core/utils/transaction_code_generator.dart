import 'dart:math';
import 'package:intl/intl.dart';

/// Generator untuk membuat nomor transaksi berformat:
/// #[INISIAL_HARI]-[DDMMYY]-[4_DIGIT_RANDOM]
/// Contoh: #SEN-051026-4829, #SEL-061026-7104
class TransactionCodeGenerator {
  static final Random _random = Random();

  /// Mengembalikan inisial 3 huruf hari dalam bahasa Indonesia
  static String getDayInitial(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'SEN';
      case DateTime.tuesday:
        return 'SEL';
      case DateTime.wednesday:
        return 'RAB';
      case DateTime.thursday:
        return 'KAM';
      case DateTime.friday:
        return 'JUM';
      case DateTime.saturday:
        return 'SAB';
      case DateTime.sunday:
        return 'MIN';
      default:
        return 'POS';
    }
  }

  /// Menghasilkan format kode transaksi lengkap: #HARI-DDMMYY-RANDOM
  /// Contoh: #SEN-051026-4829
  static String generate({DateTime? dateTime, bool includeHash = true}) {
    final now = dateTime ?? DateTime.now();
    final dayInitial = getDayInitial(now);
    final dateStr = DateFormat('ddMMyy').format(now);
    final randomCode = 1000 + _random.nextInt(9000); // 4 digit angka acak 1000-9999
    final code = '$dayInitial-$dateStr-$randomCode';
    return includeHash ? '#$code' : code;
  }
}
