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
    });

    test('Russian status', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.russian);
      expect(BackendTextMapper.translateArizaStatus('kutilmoqda'), 'Ожидается');
      expect(BackendTextMapper.translateArizaStatus('tasdiqlangan'), 'Одобрено');
      expect(BackendTextMapper.translateArizaStatus('rad etilgan'), 'Отклонено');
    });

    test('English status', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.english);
      expect(BackendTextMapper.translateArizaStatus('kutilmoqda'), 'Pending');
      expect(BackendTextMapper.translateArizaStatus('tasdiqlangan'), 'Approved');
      expect(BackendTextMapper.translateArizaStatus('rad etilgan'), 'Rejected');
    });

    test('Kyrgyz status', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.kyrgyz);
      expect(BackendTextMapper.translateArizaStatus('kutilmoqda'), 'Күтүлүүдө');
      expect(BackendTextMapper.translateArizaStatus('tasdiqlangan'), 'Тастыкталды');
      expect(BackendTextMapper.translateArizaStatus('rad etilgan'), 'Четке кагылды');
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
      expect(DateFormatter.formatDelayToHours('95 min'), '1 soat 35 minut');
    });

    test('Russian delay', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.russian);
      expect(DateFormatter.formatDelayToHours("Yo'q"), 'Нет');
      expect(DateFormatter.formatDelayToHours('Yo‘q'), 'Нет');
      expect(DateFormatter.formatDelayToHours('0'), 'Нет');
      expect(DateFormatter.formatDelayToHours('95 min'), '1 ч 35 мин');
    });

    test('English delay', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.english);
      expect(DateFormatter.formatDelayToHours("Yo'q"), 'No');
      expect(DateFormatter.formatDelayToHours('Yo‘q'), 'No');
      expect(DateFormatter.formatDelayToHours('0'), 'No');
      expect(DateFormatter.formatDelayToHours('95 min'), '1h 35m');
    });

    test('Kyrgyz delay', () {
      AppLocalizations.setCurrentLanguage(AppLanguage.kyrgyz);
      expect(DateFormatter.formatDelayToHours("Yo'q"), 'Жок');
      expect(DateFormatter.formatDelayToHours('Yo‘q'), 'Жок');
      expect(DateFormatter.formatDelayToHours('0'), 'Жок');
      expect(DateFormatter.formatDelayToHours('95 min'), '1 саат 35 мүн');
    });
  });
}
