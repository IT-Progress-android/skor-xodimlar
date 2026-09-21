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

      // "kechikkan / late / опоздал"
      case 'kechikkan':
      case 'kechikdi':
      case 'late':
      case 'опоздал':
      case 'опоздала':
      case 'опоздали':
      case 'кечиккен':
        return AppLocalizations.trStatic('status_kechikkan');

      default:
        // Noma'lum so'z — o'zgartirmasdan qaytaramiz
        return raw;
    }
  }

  /// Xodim kechikkanmi yoki yo'qligini aniqlaydi.
  /// "Yo'q", "Нет", "+Нет", "No", "Жок", "0", "00:00", "--", "false", null bo'lsa -> false.
  /// Musbat vaqt yoki kechikish daqiqasi bo'lsa -> true.
  static bool isLate(String? rawDelay) {
    if (rawDelay == null) return false;
    final t = rawDelay.trim().toLowerCase().replaceAll(RegExp(r"[‘’ʻʼ'`]"), "'");
    if (t.isEmpty ||
        t == '0' ||
        t == '00:00' ||
        t == '--' ||
        t == '-' ||
        t == "yo'q" ||
        t == 'нет' ||
        t == '+нет' ||
        t == '+yo\'q' ||
        t == 'no' ||
        t == '+no' ||
        t == 'жок' ||
        t == '+жок' ||
        t == '0 daq' ||
        t == '0 daqiqa' ||
        t == '0 min' ||
        t == '0m' ||
        t == 'false') {
      return false;
    }
    final digits = t.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isNotEmpty && (int.tryParse(digits) ?? -1) == 0) {
      return false;
    }
    return true;
  }

  /// Status so'zi (istalgan tilda) xodimning kechikkanligini bildiradimi
  static bool isLateStatus(String? status) {
    if (status == null || status.trim().isEmpty) return false;
    final s = status.trim().toLowerCase();
    return s.contains('kechik') ||
        s.contains('опоздал') ||
        s.contains('опозда') ||
        s.contains('кечик') ||
        s == 'late' ||
        s.contains('late');
  }

  /// Status so'zi (istalgan tilda) xodimning kelmaganligini bildiradimi
  static bool isAbsentStatus(String? status) {
    if (status == null || status.trim().isEmpty) return false;
    final s = status.trim().toLowerCase();
    return s.contains('kelmagan') ||
        s.contains('kelmadi') ||
        s.contains('отсутствова') ||
        s.contains('не пришёл') ||
        s.contains('не пришла') ||
        s.contains('келген эмес') ||
        s.contains('келген жок') ||
        s == 'absent' ||
        s.contains('absent');
  }

  /// Status so'zi (istalgan tilda) xodimning kelganligini bildiradimi
  static bool isPresentStatus(String? status) {
    if (status == null || status.trim().isEmpty) return false;
    final s = status.trim().toLowerCase();
    return s.contains('kelgan') ||
        s.contains('keldi') ||
        s.contains('присутствова') ||
        s.contains('пришёл') ||
        s.contains('пришла') ||
        s.contains('келди') ||
        s.contains('келген') ||
        s == 'present' ||
        s.contains('present');
  }

  // ─────────────────────────────────────────────
  // ARIZA STATUS: kutilmoqda / tasdiqlangan / rad etilgan
  // ─────────────────────────────────────────────

  /// Backend ariza statusini ilovaning tiliga o'giradi.
  /// Backend bu so'zlarni doim o'zbekcha yuborgani uchun
  /// AppLocalizations kalitlari orqali hozirgi tilga o'giramiz.
  ///
  /// Qabul qilingan qiymatlar:
  ///   "kutilmoqda" / "pending" / "ожидается" / "ожидание"
  ///   "tasdiqlangan" / "tasdiqlandi" / "approved" / "одобрено" / "подтверждено"
  ///   "rad etilgan" / "rad etildi" / "rejected" / "отклонено"
  static String translateArizaStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      // ── Kutilmoqda ──────────────────────────────
      case 'kutilmoqda':
      case 'pending':
      case 'ожидается':
      case 'ожидание':
      case 'в ожидании':
        return AppLocalizations.trStatic('status_kutilmoqda');

      // ── Tasdiqlangan ────────────────────────────
      case 'tasdiqlangan':
      case 'tasdiqlandi':
      case 'approved':
      case 'одобрено':
      case 'подтверждено':
      case 'тастыкталды':
        return AppLocalizations.trStatic('status_tasdiqlangan');

      // ── Rad etilgan ─────────────────────────────
      case 'rad etilgan':
      case 'rad etildi':
      case 'rejected':
      case 'отклонено':
      case 'четке кагылды':
        return AppLocalizations.trStatic('status_rad_etilgan');

      default:
        return raw;
    }
  }

  // ─────────────────────────────────────────────
  // DELAY: "Yo'q", "Нет", "0" → null (kechikish yo'q)
  // ─────────────────────────────────────────────

  /// Backend kechikish qiymatini tozalaydi.
  ///
  /// Agar xodim kechikmagan bo'lsa (backend "Yo'q", "Нет", "+Нет", "0", false yuborsa):
  /// - `null` qaytaradi. Shu sababli xodim kechikkan deb hisoblanmaydi va UI da
  ///   "Опоздание на +Нет" kabi ortiqcha badge ko'rinmaydi.
  /// Agar haqiqiy kechikish vaqti bo'lsa (masalan "15 daq", "00:25", "20"):
  /// - Trim qilingan qiymatni qaytaradi.
  static String? sanitizeDelay(String? raw) {
    if (raw == null) return null;
    final t = raw.trim().toLowerCase().replaceAll(RegExp(r"[‘’ʻʼ'`]"), "'");
    if (t.isEmpty ||
        t == '0' ||
        t == '00:00' ||
        t == '--' ||
        t == '-' ||
        t == "yo'q" ||
        t == 'нет' ||
        t == '+нет' ||
        t == '+yo\'q' ||
        t == 'no' ||
        t == '+no' ||
        t == 'жок' ||
        t == '+жок' ||
        t == '0 daq' ||
        t == '0 daqiqa' ||
        t == '0 min' ||
        t == '0m' ||
        t == 'false') {
      return null;
    }
    final digits = t.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isNotEmpty && (int.tryParse(digits) ?? -1) == 0) {
      return null;
    }
    return raw.trim();
  }

  // ─────────────────────────────────────────────
  // ARIZA TURI NOMI: "Javob so'rash", "Ta'til" → 4 tilda
  // ─────────────────────────────────────────────

  /// Backend ariza turining o'zbekcha nomini ilovaning tiliga o'giradi.
  /// Apostroflar (', ‘, ’, ʻ, ʼ) avtomatik normallashtiriladi.
  /// Noma'lum tur kelsa — o'zgartirmasdan qaytaradi.
  static String translateArizaTuriNomi(String raw) {
    final clean = raw.trim().toLowerCase().replaceAll(RegExp(r"[‘’ʻʼ'`]"), "'");
    switch (clean) {
      // ── Javob so'rash ───────────────────────────
      case "javob so'rash":
      case 'javob sorash':
      case 'отпроситься':
      case 'отгул':
      case 'permission':
      case 'short leave':
      case 'сурануу':
        return AppLocalizations.trStatic('ariza_type_javob_sorash');

      // ── Ta'til ──────────────────────────────────
      case "ta'til":
      case 'tatil':
      case 'отпуск':
      case 'vacation':
      case 'annual leave':
      case 'эмгек өргүү':
        return AppLocalizations.trStatic('ariza_type_tatil');

      // ── Kasallik ────────────────────────────────
      case 'kasallik':
      case 'больничный':
      case 'sick leave':
      case 'оору өргүүсү':
        return AppLocalizations.trStatic('ariza_type_kasallik');

      // ── Xizmat safari ───────────────────────────
      case 'xizmat safari':
      case 'командировка':
      case 'business trip':
      case 'иш сапары':
        return AppLocalizations.trStatic('ariza_type_xizmat_safari');

      // ── Sababsiz ────────────────────────────────
      case 'sababsiz':
      case 'без причины':
      case 'unexcused':
      case 'no reason':
      case 'себепсиз':
        return AppLocalizations.trStatic('ariza_type_sababsiz');

      // ── Boshqa ──────────────────────────────────
      case 'boshqa':
      case 'другое':
      case 'other':
      case 'башка':
        return AppLocalizations.trStatic('ariza_type_boshqa');

      default:
        return raw;
    }
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
