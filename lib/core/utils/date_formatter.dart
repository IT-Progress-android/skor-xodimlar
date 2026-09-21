import 'package:skore_hodimlar/core/localization/app_localizations.dart';

class DateFormatter {
  /// Serverdan keladigan kechikish qiymatini ("95", "95 min", "Yo'q", "0")
  /// ilovaning hozirgi tiliga mos ko'rinishiga o'giradi.
  ///
  /// Masalan:
  /// - "Yo'q" / "0" -> "Yo'q" (UZ) / "Нет" (RU) / "No" (EN) / "Жок" (KY)
  /// - "95" -> "1 soat 35 minut" (UZ) / "1 ч 35 мин" (RU) / "1h 35m" (EN) / "1 саат 35 мүн" (KY)
  static String formatDelayToHours(String? rawDelay) {
    if (rawDelay == null || rawDelay.trim().isEmpty) return '';

    final text = rawDelay.trim();
    final clean = text.toLowerCase().replaceAll(RegExp(r"[‘’ʻʼ'`]"), "'");

    // Kechikish yo'q holatlari: "yo'q", "нет", "no", "жок", "0", "00:00", "--", "0 daq"
    if (clean == "yo'q" ||
        clean == 'нет' ||
        clean == 'no' ||
        clean == 'жок' ||
        clean == '0' ||
        clean == '00:00' ||
        clean == '--' ||
        clean == '0 daq') {
      return AppLocalizations.trStatic('no');
    }

    // Agar "01:30" yoki "00:25" (HH:mm / HH:mm:ss) formatida bo'lsa
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final m = int.tryParse(parts[1].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final totalM = h * 60 + m;
        if (totalM <= 0) {
          return AppLocalizations.trStatic('no');
        }
        if (h > 0 && m > 0) {
          return AppLocalizations.trStatic('duration_hours_mins', {
            'hours': '$h',
            'mins': '$m',
          });
        } else if (h > 0 && m == 0) {
          return AppLocalizations.trStatic('duration_hours', {
            'hours': '$h',
          });
        } else {
          return AppLocalizations.trStatic('duration_mins', {
            'mins': '$m',
          });
        }
      }
    }

    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return text;
    }

    final totalMinutes = int.tryParse(digits);
    if (totalMinutes == null || totalMinutes <= 0) {
      return AppLocalizations.trStatic('no');
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return AppLocalizations.trStatic('duration_hours_mins', {
        'hours': '$hours',
        'mins': '$minutes',
      });
    } else if (hours > 0 && minutes == 0) {
      return AppLocalizations.trStatic('duration_hours', {
        'hours': '$hours',
      });
    } else {
      return AppLocalizations.trStatic('duration_mins', {
        'mins': '$minutes',
      });
    }
  }
}

