import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/core/utils/date_formatter.dart';

void main() {
  setUp(() {
    AppLocalizations.setCurrentLanguage(AppLanguage.uzbek);
  });

  group('BackendTextMapper - Ariza Status Translations (4 languages)', () {
    test('Uzbek status', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.uzbek);
      expect(BackendTextMapper.translateArizaStatus('kutilmoqda'), 'Kutilmoqda');
      expect(BackendTextMapper.translateArizaStatus('tasdiqlangan'), 'Tasdiqlangan');
      expect(BackendTextMapper.translateArizaStatus('rad etilgan'), 'Rad etilgan');
      expect(BackendTextMapper.translateStatus('kechikkan'), 'Kechikkan');
    });

    test('Russian status', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.russian);
      expect(BackendTextMapper.translateArizaStatus('kutilmoqda'), 'Ожидается');
      expect(BackendTextMapper.translateArizaStatus('tasdiqlangan'), 'Одобрено');
      expect(BackendTextMapper.translateArizaStatus('rad etilgan'), 'Отклонено');
      expect(BackendTextMapper.translateStatus('kechikkan'), 'Опоздал');
    });

    test('English status', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.english);
      expect(BackendTextMapper.translateArizaStatus('kutilmoqda'), 'Pending');
      expect(BackendTextMapper.translateArizaStatus('tasdiqlangan'), 'Approved');
      expect(BackendTextMapper.translateArizaStatus('rad etilgan'), 'Rejected');
      expect(BackendTextMapper.translateStatus('kechikkan'), 'Late');
    });

    test('Kyrgyz status', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.kyrgyz);
      expect(BackendTextMapper.translateArizaStatus('kutilmoqda'), 'Күтүлүүдө');
      expect(BackendTextMapper.translateArizaStatus('tasdiqlangan'), 'Тастыкталды');
      expect(BackendTextMapper.translateArizaStatus('rad etilgan'), 'Четке кагылды');
      expect(BackendTextMapper.translateStatus('kechikkan'), 'Кечиккен');
    });
  });

  group('BackendTextMapper - isLate and sanitizeDelay helpers', () {
    test('Identifies non-late and late delays correctly', () {
      expect(BackendTextMapper.isLate(null), false);
      expect(BackendTextMapper.isLate(''), false);
      expect(BackendTextMapper.isLate("Yo'q"), false);
      expect(BackendTextMapper.isLate('Yo‘q'), false);
      expect(BackendTextMapper.isLate('0'), false);
      expect(BackendTextMapper.isLate('00:00'), false);
      expect(BackendTextMapper.isLate('--'), false);
      expect(BackendTextMapper.isLate('-'), false);
      expect(BackendTextMapper.isLate('Нет'), false);
      expect(BackendTextMapper.isLate('+Нет'), false);
      expect(BackendTextMapper.isLate('+yo\'q'), false);
      expect(BackendTextMapper.isLate('no'), false);
      expect(BackendTextMapper.isLate('жок'), false);
      expect(BackendTextMapper.isLate('false'), false);
      expect(BackendTextMapper.isLate('0 daq'), false);

      expect(BackendTextMapper.isLate('15 min'), true);
      expect(BackendTextMapper.isLate('00:25'), true);
      expect(BackendTextMapper.isLate('1 soat 10 min'), true);
    });

    test('sanitizeDelay returns null for non-late delays and trims actual delays', () {
      expect(BackendTextMapper.sanitizeDelay(null), null);
      expect(BackendTextMapper.sanitizeDelay(''), null);
      expect(BackendTextMapper.sanitizeDelay("Yo'q"), null);
      expect(BackendTextMapper.sanitizeDelay('Yo‘q'), null);
      expect(BackendTextMapper.sanitizeDelay('0'), null);
      expect(BackendTextMapper.sanitizeDelay('00:00'), null);
      expect(BackendTextMapper.sanitizeDelay('--'), null);
      expect(BackendTextMapper.sanitizeDelay('Нет'), null);
      expect(BackendTextMapper.sanitizeDelay('+Нет'), null);
      expect(BackendTextMapper.sanitizeDelay('false'), null);

      expect(BackendTextMapper.sanitizeDelay('15 min'), '15 min');
      expect(BackendTextMapper.sanitizeDelay('00:25'), '00:25');
    });

    test('Status helpers identify late, absent, and present across languages', () {
      // Late
      expect(BackendTextMapper.isLateStatus('Kechikkan'), true);
      expect(BackendTextMapper.isLateStatus('Опоздал'), true);
      expect(BackendTextMapper.isLateStatus('Опоздали'), true);
      expect(BackendTextMapper.isLateStatus('Late'), true);
      expect(BackendTextMapper.isLateStatus('Кечиккен'), true);
      expect(BackendTextMapper.isLateStatus('Присутствовал'), false);

      // Absent
      expect(BackendTextMapper.isAbsentStatus('Kelmagan'), true);
      expect(BackendTextMapper.isAbsentStatus('Отсутствовал'), true);
      expect(BackendTextMapper.isAbsentStatus('Absent'), true);
      expect(BackendTextMapper.isAbsentStatus('Присутствовал'), false);

      // Present
      expect(BackendTextMapper.isPresentStatus('Kelgan'), true);
      expect(BackendTextMapper.isPresentStatus('Присутствовал'), true);
      expect(BackendTextMapper.isPresentStatus('Пришёл'), true);
      expect(BackendTextMapper.isPresentStatus('Present'), true);
      expect(BackendTextMapper.isPresentStatus('Отсутствовал'), false);
    });
  });

  group('BackendTextMapper - Ariza Turi Translations (4 languages)', () {
    test('Uzbek ariza types', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.uzbek);
      expect(BackendTextMapper.translateArizaTuriNomi("Javob so'rash"), "Javob so'rash");
      expect(BackendTextMapper.translateArizaTuriNomi('Javob so‘rash'), "Javob so'rash");
      expect(BackendTextMapper.translateArizaTuriNomi("Ta'til"), "Ta'til");
      expect(BackendTextMapper.translateArizaTuriNomi('Kasallik'), 'Kasallik');
      expect(BackendTextMapper.translateArizaTuriNomi('Xizmat safari'), 'Xizmat safari');
    });

    test('Russian ariza types', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.russian);
      expect(BackendTextMapper.translateArizaTuriNomi("Javob so'rash"), 'Отпроситься');
      expect(BackendTextMapper.translateArizaTuriNomi('Javob so‘rash'), 'Отпроситься');
      expect(BackendTextMapper.translateArizaTuriNomi("Ta'til"), 'Отпуск');
      expect(BackendTextMapper.translateArizaTuriNomi('Kasallik'), 'Больничный');
      expect(BackendTextMapper.translateArizaTuriNomi('Xizmat safari'), 'Командировка');
    });

    test('English ariza types', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.english);
      expect(BackendTextMapper.translateArizaTuriNomi("Javob so'rash"), 'Permission / Leave');
      expect(BackendTextMapper.translateArizaTuriNomi("Ta'til"), 'Vacation');
      expect(BackendTextMapper.translateArizaTuriNomi('Kasallik'), 'Sick leave');
      expect(BackendTextMapper.translateArizaTuriNomi('Xizmat safari'), 'Business trip');
    });

    test('Kyrgyz ariza types', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.kyrgyz);
      expect(BackendTextMapper.translateArizaTuriNomi("Javob so'rash"), 'Сурануу');
      expect(BackendTextMapper.translateArizaTuriNomi("Ta'til"), 'Эмгек өргүү');
      expect(BackendTextMapper.translateArizaTuriNomi('Kasallik'), 'Оору өргүүсү');
      expect(BackendTextMapper.translateArizaTuriNomi('Xizmat safari'), 'Иш сапары');
    });
  });

  group('DateFormatter & BackendTextMapper - Delay Translations (4 languages)', () {
    test('Uzbek delay', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.uzbek);
      expect(DateFormatter.formatDelayToHours("Yo'q"), "Yo'q");
      expect(DateFormatter.formatDelayToHours('Yo‘q'), "Yo'q");
      expect(DateFormatter.formatDelayToHours('0'), "Yo'q");
      expect(DateFormatter.formatDelayToHours('00:00'), "Yo'q");
      expect(DateFormatter.formatDelayToHours('--'), "Yo'q");
      expect(DateFormatter.formatDelayToHours('95 min'), '1 soat 35 minut');
      expect(DateFormatter.formatDelayToHours('01:30'), '1 soat 30 minut');
      expect(DateFormatter.formatDelayToHours('00:15'), '15 minut');
      expect(DateFormatter.formatDelayToHours('02:00'), '2 soat');
    });

    test('Russian delay', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.russian);
      expect(DateFormatter.formatDelayToHours("Yo'q"), 'Нет');
      expect(DateFormatter.formatDelayToHours('Yo‘q'), 'Нет');
      expect(DateFormatter.formatDelayToHours('0'), 'Нет');
      expect(DateFormatter.formatDelayToHours('00:00'), 'Нет');
      expect(DateFormatter.formatDelayToHours('--'), 'Нет');
      expect(DateFormatter.formatDelayToHours('95 min'), '1 ч 35 мин');
      expect(DateFormatter.formatDelayToHours('01:30'), '1 ч 30 мин');
      expect(DateFormatter.formatDelayToHours('00:15'), '15 мин');
      expect(DateFormatter.formatDelayToHours('02:00'), '2 ч');
    });

    test('English delay', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.english);
      expect(DateFormatter.formatDelayToHours("Yo'q"), 'No');
      expect(DateFormatter.formatDelayToHours('Yo‘q'), 'No');
      expect(DateFormatter.formatDelayToHours('0'), 'No');
      expect(DateFormatter.formatDelayToHours('00:00'), 'No');
      expect(DateFormatter.formatDelayToHours('--'), 'No');
      expect(DateFormatter.formatDelayToHours('95 min'), '1h 35m');
      expect(DateFormatter.formatDelayToHours('01:30'), '1h 30m');
      expect(DateFormatter.formatDelayToHours('00:15'), '15m');
      expect(DateFormatter.formatDelayToHours('02:00'), '2h');
    });

    test('Kyrgyz delay', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.kyrgyz);
      expect(DateFormatter.formatDelayToHours("Yo'q"), 'Жок');
      expect(DateFormatter.formatDelayToHours('Yo‘q'), 'Жок');
      expect(DateFormatter.formatDelayToHours('0'), 'Жок');
      expect(DateFormatter.formatDelayToHours('00:00'), 'Жок');
      expect(DateFormatter.formatDelayToHours('--'), 'Жок');
      expect(DateFormatter.formatDelayToHours('95 min'), '1 саат 35 мүн');
      expect(DateFormatter.formatDelayToHours('01:30'), '1 саат 30 мүн');
      expect(DateFormatter.formatDelayToHours('00:15'), '15 мүн');
      expect(DateFormatter.formatDelayToHours('02:00'), '2 саат');
    });
  });
}
