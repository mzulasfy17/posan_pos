import 'package:flutter_test/flutter_test.dart';
import 'package:posan/core/utils/transaction_code_generator.dart';

void main() {
  group('TransactionCodeGenerator', () {
    test('generates correct format with day initial, date, and 4-digit random number', () {
      final mondayDate = DateTime(2026, 10, 5); // Monday -> SEN
      final code = TransactionCodeGenerator.generate(dateTime: mondayDate);

      // Expect format #SEN-051026-XXXX
      expect(code.startsWith('#SEN-051026-'), isTrue);
      expect(RegExp(r'^#SEN-051026-\d{4}$').hasMatch(code), isTrue);
    });

    test('generates correct initials for each day of the week', () {
      expect(TransactionCodeGenerator.getDayInitial(DateTime(2026, 10, 5)), 'SEN'); // Monday
      expect(TransactionCodeGenerator.getDayInitial(DateTime(2026, 10, 6)), 'SEL'); // Tuesday
      expect(TransactionCodeGenerator.getDayInitial(DateTime(2026, 10, 7)), 'RAB'); // Wednesday
      expect(TransactionCodeGenerator.getDayInitial(DateTime(2026, 10, 8)), 'KAM'); // Thursday
      expect(TransactionCodeGenerator.getDayInitial(DateTime(2026, 10, 9)), 'JUM'); // Friday
      expect(TransactionCodeGenerator.getDayInitial(DateTime(2026, 10, 10)), 'SAB'); // Saturday
      expect(TransactionCodeGenerator.getDayInitial(DateTime(2026, 10, 11)), 'MIN'); // Sunday
    });

    test('generates without hash when includeHash is false', () {
      final date = DateTime(2026, 10, 5);
      final code = TransactionCodeGenerator.generate(dateTime: date, includeHash: false);
      expect(RegExp(r'^SEN-051026-\d{4}$').hasMatch(code), isTrue);
    });
  });
}
