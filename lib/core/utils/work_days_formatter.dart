import 'package:flutter/widgets.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';

enum Weekday {
  mon(1, 'mon', 'Dushanba', 'Dush', 'Du'),
  tue(2, 'tue', 'Seshanba', 'Sesh', 'Se'),
  wed(3, 'wed', 'Chorshanba', 'Chor', 'Ch'),
  thu(4, 'thu', 'Payshanba', 'Pay', 'Pa'),
  fri(5, 'fri', 'Juma', 'Jum', 'Ju'),
  sat(6, 'sat', 'Shanba', 'Shan', 'Sh'),
  sun(7, 'sun', 'Yakshanba', 'Yak', 'Ya');

  final int number; // 1 = Dushanba, 7 = Yakshanba
  final String key;
  final String fullNameUz;
  final String shortNameUz;
  final String miniNameUz;

  const Weekday(
    this.number,
    this.key,
    this.fullNameUz,
    this.shortNameUz,
    this.miniNameUz,
  );

  String getMiniName(BuildContext context) {
    return context.tr('weekday_mini_$key');
  }

  String getFullName(BuildContext context) {
    return context.tr('weekday_$key');
  }

  String getShortName(BuildContext context) {
    return context.tr('weekday_short_$key');
  }

  /// Bugungi haftaning kunini qaytaradi (1..7)
  static Weekday get today {
    final weekdayNumber = DateTime.now().weekday;
    return Weekday.values.firstWhere(
      (w) => w.number == weekdayNumber,
      orElse: () => Weekday.mon,
    );
  }
}

class WorkDaysFormatter {
  /// Backenddan keluvchi turli formatdagi kunlarni Weekday enum to'plamiga o'tkazadi
  static Set<Weekday> parse(List<String> rawDays) {
    final result = <Weekday>{};
    for (final raw in rawDays) {
      final clean = raw.trim().toLowerCase();
      if (clean.isEmpty) continue;

      for (final w in Weekday.values) {
        if (clean == w.key ||
            clean.startsWith(w.key) ||
            clean == w.number.toString() ||
            clean == w.shortNameUz.toLowerCase() ||
            clean.startsWith(w.miniNameUz.toLowerCase())) {
          result.add(w);
          break;
        }
      }
    }
    return result;
  }

  /// Format summary with localization support
  static String formatSummary(List<String> rawDays, [BuildContext? context]) {
    final parsed = parse(rawDays).toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    if (parsed.isEmpty) return '';

    final count = parsed.length;

    if (context != null) {
      // 7 kun to'liq bo'lsa
      if (count == 7) {
        return context.tr('everyday_7');
      }

      // Faqat 1 kun bo'lsa
      if (count == 1) {
        return context.tr('single_day_format', {
          'day': parsed.first.getFullName(context),
        });
      }

      bool isConsecutive = true;
      for (int i = 0; i < count - 1; i++) {
        if (parsed[i + 1].number != parsed[i].number + 1) {
          isConsecutive = false;
          break;
        }
      }

      final daysCountStr = context.tr('days_format', {
        'count': count.toString(),
      });

      if (isConsecutive) {
        final from = parsed.first.getFullName(context);
        final to = parsed.last.getFullName(context);
        return '$from – $to ($daysCountStr)';
      }

      final shortNames = parsed.map((e) => e.getShortName(context)).join(', ');
      return '$shortNames ($daysCountStr)';
    }

    // Default Uzbek fallback
    if (count == 7) {
      return 'Har kuni (7 kunlik)';
    }

    if (count == 1) {
      return '${parsed.first.fullNameUz} (1 kun)';
    }

    bool isConsecutive = true;
    for (int i = 0; i < count - 1; i++) {
      if (parsed[i + 1].number != parsed[i].number + 1) {
        isConsecutive = false;
        break;
      }
    }

    if (isConsecutive) {
      final from = parsed.first.fullNameUz;
      final to = parsed.last.fullNameUz;
      return '$from – $to ($count kunlik)';
    }

    final shortNames = parsed.map((e) => e.shortNameUz).join(', ');
    return '$shortNames ($count kunlik)';
  }
}
