import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/utils/phone_formatter.dart';

void main() {
  group('UzbekPhoneInputFormatter Tests', () {
    final formatter = UzbekPhoneInputFormatter();

    test('1. Typing digit by digit formats correctly', () {
      var val = const TextEditingValue(text: '');
      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '9', selection: TextSelection.collapsed(offset: 1)));
      expect(val.text, '+998 9');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '+998 90', selection: TextSelection.collapsed(offset: 7)));
      expect(val.text, '+998 90');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '+998 90 1', selection: TextSelection.collapsed(offset: 9)));
      expect(val.text, '+998 90 1');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '+998 90 1234567', selection: TextSelection.collapsed(offset: 15)));
      expect(val.text, '+998 90 123 45 67');
    });

    test('2. HARD LIMIT: Cannot type more than 9 digits (no rolling over)', () {
      const full = TextEditingValue(
        text: '+998 90 123 45 67',
        selection: TextSelection.collapsed(offset: 17),
      );
      final attemptMore = TextEditingValue(
        text: '+998 90 123 45 678',
        selection: const TextSelection.collapsed(offset: 18),
      );
      final result = formatter.formatEditUpdate(full, attemptMore);
      expect(result.text, '+998 90 123 45 67');
    });

    test('3. Number starting with 99 8 (Uzmobile) does not delete 998', () {
      var val = const TextEditingValue(text: '+998 ');
      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '+998 9981', selection: TextSelection.collapsed(offset: 9)));
      expect(val.text, '+998 99 81');
    });

    test('4. Pasting formatted text with parentheses and dashes', () {
      var val = const TextEditingValue(text: '');
      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '+998 (90) 123-45-67', selection: TextSelection.collapsed(offset: 19)));
      expect(val.text, '+998 90 123 45 67');
    });

    test('5. Pasting 8-prefixed number (8901234567)', () {
      var val = const TextEditingValue(text: '');
      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '8901234567', selection: TextSelection.collapsed(offset: 10)));
      expect(val.text, '+998 90 123 45 67');
    });

    test('6. Pasting long text truncates at 9 digits and does not shift', () {
      var val = const TextEditingValue(text: '');
      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '+99890123456799999', selection: TextSelection.collapsed(offset: 18)));
      expect(val.text, '+998 90 123 45 67');
    });

    test('7. Backspace after space deletes preceding digit', () {
      const oldVal = TextEditingValue(text: '+998 90 ', selection: TextSelection.collapsed(offset: 8));
      const newVal = TextEditingValue(text: '+998 90', selection: TextSelection.collapsed(offset: 7));
      final res = formatter.formatEditUpdate(oldVal, newVal);
      expect(res.text, '+998 9');
    });

    test('8. Editing in middle keeps cursor position', () {
      // User has +998 90 123 45 6, and inserts 9 between 90 and 1
      const oldVal = TextEditingValue(text: '+998 90 123 45 6', selection: TextSelection.collapsed(offset: 8));
      const newVal = TextEditingValue(text: '+998 90 9123 45 6', selection: TextSelection.collapsed(offset: 9));
      final res = formatter.formatEditUpdate(oldVal, newVal);
      expect(res.text, '+998 90 912 34 56');
    });
  });

  group('PhoneFormatter Helper Tests', () {
    test('extractSubscriberDigits extracts 9 digits reliably', () {
      expect(PhoneFormatter.extractSubscriberDigits('+998 90 123 45 67'), '901234567');
      expect(PhoneFormatter.extractSubscriberDigits('90 123 45 67'), '901234567');
      expect(PhoneFormatter.extractSubscriberDigits('+998 (99) 812-34-56'), '998123456');
      expect(PhoneFormatter.extractSubscriberDigits('8901234567'), '901234567');
      expect(PhoneFormatter.extractSubscriberDigits('+998901234567999'), '901234567');
    });

    test('normalizePhone returns full 998XXXXXXXXX', () {
      expect(PhoneFormatter.normalizePhone('+998 90 123 45 67'), '998901234567');
      expect(PhoneFormatter.normalizePhone('901234567'), '998901234567');
    });
  });
}
