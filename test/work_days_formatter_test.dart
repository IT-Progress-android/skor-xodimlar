import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/utils/work_days_formatter.dart';

void main() {
  group('WorkDaysFormatter Tests', () {
    test('6-day work week (mon-sat) formats to Dushanba – Shanba (6 kunlik)', () {
      final days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
      expect(
        WorkDaysFormatter.formatSummary(days),
        'Dushanba – Shanba (6 kunlik)',
      );
      final parsed = WorkDaysFormatter.parse(days);
      expect(parsed.length, 6);
      expect(parsed.contains(Weekday.sun), false);
      expect(parsed.contains(Weekday.mon), true);
    });

    test('5-day work week (mon-fri) formats to Dushanba – Juma (5 kunlik)', () {
      final days = ['mon', 'tue', 'wed', 'thu', 'fri'];
      expect(
        WorkDaysFormatter.formatSummary(days),
        'Dushanba – Juma (5 kunlik)',
      );
    });

    test('7-day work week formats to Har kuni (7 kunlik)', () {
      final days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      expect(
        WorkDaysFormatter.formatSummary(days),
        'Har kuni (7 kunlik)',
      );
    });

    test('Non-consecutive days (mon, wed, fri) formats to Dush, Chor, Jum (3 kunlik)', () {
      final days = ['mon', 'wed', 'fri'];
      expect(
        WorkDaysFormatter.formatSummary(days),
        'Dush, Chor, Jum (3 kunlik)',
      );
    });

    test('Case insensitivity and different prefixes', () {
      final days = ['Mon', 'TUESDAY', 'wed'];
      expect(
        WorkDaysFormatter.formatSummary(days),
        'Dushanba – Chorshanba (3 kunlik)',
      );
    });

    test('Empty list returns empty string', () {
      expect(WorkDaysFormatter.formatSummary([]), '');
    });
  });
}
