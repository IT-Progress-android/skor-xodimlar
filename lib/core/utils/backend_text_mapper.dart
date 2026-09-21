import 'package:skore_hodimlar/core/localization/app_localizations.dart';

/// Backend dan kelayotgan ba'zi so'zlar doim o'zbekcha (yoki ruscha) bo'ladi.
/// Masalan: status="Kelgan", delay="Yo'q", weekday="Dushanba" va h.k.
///
/// Bu class ularning barchasini ilovaning hozirgi tiliga tarjima qiladi.
/// Natijada UI da hech qachon "Опоздание: Yo'q" kabi aralash matn chiqmaydi.
class BackendTextMapper {
  BackendTextMapper._();

  // ─────────────────────────────────────────────
  // STATUS: kelgan / kelmagan / kechikkan
  // ─────────────────────────────────────────────

  /// Backend status matnini ilovaning tiliga o'giradi.
  /// Bilmagan so'zni o'zgartirmasdan qaytaradi.
  static String translateStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      // "keldi / kelgan / present / пришёл / Присутствовал"
      case 'kelgan':
      case 'keldi':
      case 'present':
      case 'пришёл':
      case 'пришла':
      case 'присутствовал':
      case 'присутствовала':
      case 'kelgan (kechikkan)': // kechikkan holati ham "kelgan" sanaladi
        return AppLocalizations.trStatic('attendance_present');

      // "kelmagan / absent / отсутствовал"
      case 'kelmagan':
      case 'kelmadi':
      case 'absent':
      case 'отсутствовал':
      case 'отсутствовала':
      case 'не пришёл':
      case 'не пришла':
        return AppLocalizations.trStatic('attendance_absent');

      default:
        // Noma'lum so'z — o'zgartirmasdan qaytaramiz
        return raw;
    }
  }

  // ─────────────────────────────────────────────
  // DELAY: "Yo'q", "Нет", "0" → null yoki formatlangan vaqt
  // ─────────────────────────────────────────────

  /// Backend kechikish qiymatini tozalaydi.
  /// "Yo'q", "Нет", "0", "" → null qaytaradi (badge ko'rsatilmaydi).
  /// Boshqa qiymatlar o'z holicha qaytaradi (vaqt formatida: "00:05").
  static String? sanitizeDelay(String? raw) {
    if (raw == null) return null;
    final t = raw.trim().toLowerCase();
    if (t.isEmpty || t == '0' || t == "yo'q" || t == 'нет' || t == 'no') {
      return null;
    }
    return raw.trim();
  }

  // ─────────────────────────────────────────────
  // WEEKDAY: "Dushanba", "Понедельник" → localized
  // ─────────────────────────────────────────────

  /// Backend weekday matnini yoki sana stringini (`2026-09-21`)
  /// ilovaning tiliga mos hafta kuniga aylantiradi.
  /// Agar tanib olsa → tarjima, aks holda → `null`.
  static String? translateWeekday(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    // 1) Sana string bo'lsa (yyyy-MM-dd) — Date.weekday dan hisoblaymiz
    final date = DateTime.tryParse(raw.trim());
    if (date != null) {
      const keys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      return AppLocalizations.trStatic('weekday_${keys[date.weekday - 1]}');
    }

    // 2) Backend string bo'lsa — known strings ni map qilamiz
    switch (raw.trim().toLowerCase()) {
      case 'dushanba':
      case 'понедельник':
      case 'monday':
      case 'дүйшөмбү':
        return AppLocalizations.trStatic('weekday_mon');
      case 'seshanba':
      case 'вторник':
      case 'tuesday':
      case 'шейшемби':
        return AppLocalizations.trStatic('weekday_tue');
      case 'chorshanba':
      case 'среда':
      case 'wednesday':
      case 'шаршемби':
        return AppLocalizations.trStatic('weekday_wed');
      case 'payshanba':
      case 'четверг':
      case 'thursday':
      case 'бейшемби':
        return AppLocalizations.trStatic('weekday_thu');
      case 'juma':
      case 'пятница':
      case 'friday':
      case 'жума':
        return AppLocalizations.trStatic('weekday_fri');
      case 'shanba':
      case 'суббота':
      case 'saturday':
      case 'ишемби':
        return AppLocalizations.trStatic('weekday_sat');
      case 'yakshanba':
      case 'воскресенье':
      case 'sunday':
      case 'жекшемби':
        return AppLocalizations.trStatic('weekday_sun');
      default:
        return null;
    }
  }
}
