import 'package:shared_preferences/shared_preferences.dart';

/// Davomatga bog'liq, vaqt bo'yicha keladigan eslatmalar. Har biri kuniga
/// faqat bir marta ko'rsatiladi:
/// - `attendance_reminder` — smena boshlanishidan 10 daqiqa oldin;
/// - `shift_end_reminder` — smena tugashidan 10 daqiqa oldin.
const dailyReminderTypes = {'attendance_reminder', 'shift_end_reminder'};

/// Avto-ketdi haqida xabar ko'rsatilsinmi. `false` — ko'rsatilmaydi, lekin
/// GPS baribir to'xtatiladi.
const showAutoKetdiPush = false;

/// `type` siz kelgan eski davomat eslatmasi `attendance_reminder` deb olinadi.
String? normalizePushType(String? type) =>
    (type == null || type.isEmpty || type == 'attendance')
    ? 'attendance_reminder'
    : type;

/// Bildirishnoma ko'rsatilsinmi. [lastShownDay] — shu tur oxirgi marta
/// ko'rsatilgan kun (`YYYY-MM-DD`), [today] — bugun.
bool shouldShowPush(
  String? type, {
  String? lastShownDay,
  required String today,
}) {
  final t = normalizePushType(type);
  if (t == 'auto_ketdi') return showAutoKetdiPush;
  if (dailyReminderTypes.contains(t)) return lastShownDay != today;
  return true;
}

/// [shouldShowPush] ni saqlangan holat bilan tekshiradi va ko'rsatiladigan
/// bo'lsa bugungi kunni belgilab qo'yadi — server ikkinchi marta yuborsa,
/// u e'tiborsiz qoldiriladi. Asosiy va fon izolyatorlari ikkalasi ham
/// chaqiradi, shuning uchun har safar diskdan qayta o'qiladi.
Future<bool> claimPushDisplay(String? type, {DateTime? now}) async {
  final t = normalizePushType(type);
  final d = now ?? DateTime.now();
  final today =
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = 'push_shown_$t';
    final show = shouldShowPush(
      t,
      lastShownDay: prefs.getString(key),
      today: today,
    );
    if (show && dailyReminderTypes.contains(t)) {
      await prefs.setString(key, today);
    }
    return show;
  } catch (_) {
    return shouldShowPush(t, today: today);
  }
}
