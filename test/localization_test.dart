import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_cubit.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLanguage tests', () {
    test('supports Uzbek, Russian, English, and Kyrgyz', () {
      expect(AppLanguage.values.length, 4);
      expect(AppLanguage.fromCode('uz'), AppLanguage.uzbek);
      expect(AppLanguage.fromCode('ru'), AppLanguage.russian);
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.fromCode('ky'), AppLanguage.kyrgyz);
    });

    test('defaults to Uzbek for invalid or null codes', () {
      expect(AppLanguage.fromCode(null), AppLanguage.uzbek);
      expect(AppLanguage.fromCode('unknown'), AppLanguage.uzbek);
    });

    test('supportedLocales contains all 4 language locales', () {
      final locales = AppLanguage.supportedLocales;
      expect(locales, contains(const Locale('uz')));
      expect(locales, contains(const Locale('ru')));
      expect(locales, contains(const Locale('en')));
      expect(locales, contains(const Locale('ky')));
    });
  });

  group('AppLocalizations tests', () {
    test('translates profile and navigation in all 4 languages', () {
      final uz = AppLocalizations(const Locale('uz'));
      final ru = AppLocalizations(const Locale('ru'));
      final en = AppLocalizations(const Locale('en'));
      final ky = AppLocalizations(const Locale('ky'));

      expect(uz.translate('profile_title'), 'Profil');
      expect(ru.translate('profile_title'), 'Профиль');
      expect(en.translate('profile_title'), 'Profile');
      expect(ky.translate('profile_title'), 'Профиль');

      expect(uz.translate('nav_home'), 'Asosiy');
      expect(ru.translate('nav_home'), 'Главная');
      expect(en.translate('nav_home'), 'Home');
      expect(ky.translate('nav_home'), 'Башкы');

      expect(uz.translate('nav_applications'), 'Arizalar');
      expect(ru.translate('nav_applications'), 'Заявки');
      expect(en.translate('nav_applications'), 'Applications');
      expect(ky.translate('nav_applications'), 'Арыздар');
    });

    test('interpolates params correctly', () {
      final uz = AppLocalizations(const Locale('uz'));
      final formatted = uz.translate('days_format', {'count': '5'});
      expect(formatted, '5 kunlik');

      final ru = AppLocalizations(const Locale('ru'));
      expect(ru.translate('days_format', {'count': '5'}), '5-дневный');

      final en = AppLocalizations(const Locale('en'));
      expect(en.translate('days_format', {'count': '5'}), '5 days');

      final ky = AppLocalizations(const Locale('ky'));
      expect(ky.translate('days_format', {'count': '5'}), '5 күндүк');
    });
  });

  group('LanguageCubit tests', () {
    test('loads saved language and emits state changes immediately in real time', () async {
      SharedPreferences.setMockInitialValues({
        LanguageCubit.prefKey: 'ru',
      });
      final prefs = await SharedPreferences.getInstance();
      final cubit = LanguageCubit(prefs);

      expect(cubit.state, const LanguageState(AppLanguage.russian));

      // Change to Kyrgyz
      await cubit.changeLanguage(AppLanguage.kyrgyz);
      expect(cubit.state, const LanguageState(AppLanguage.kyrgyz));
      expect(prefs.getString(LanguageCubit.prefKey), 'ky');

      // Change to English
      await cubit.changeLanguage(AppLanguage.english);
      expect(cubit.state, const LanguageState(AppLanguage.english));
      expect(prefs.getString(LanguageCubit.prefKey), 'en');

      // Change to Uzbek
      await cubit.changeLanguage(AppLanguage.uzbek);
      expect(cubit.state, const LanguageState(AppLanguage.uzbek));
      expect(prefs.getString(LanguageCubit.prefKey), 'uz');
    });
  });
}
