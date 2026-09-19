import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/localization/app_translations.dart';
import 'package:skore_hodimlar/core/widgets/location_disclosure_dialog.dart';

void main() {
  group('Location Prominent Disclosure Translations Tests', () {
    test('All 4 languages have required location disclosure keys', () {
      final languages = ['uz', 'ru', 'en', 'ky'];
      final requiredKeys = [
        'location_disclosure_title',
        'location_disclosure_statement',
        'location_accept',
        'location_decline',
        'bg_location_disclosure_title',
        'bg_location_disclosure_statement',
        'bg_location_open_settings',
        'bg_location_cancel',
      ];

      for (final lang in languages) {
        final dict = AppTranslations.translations[lang];
        expect(dict, isNotNull, reason: 'Language $lang dictionary must exist');

        for (final key in requiredKeys) {
          final value = dict![key];
          expect(
            value,
            isNotNull,
            reason: 'Key "$key" must exist for language "$lang"',
          );
          expect(
            value!.isNotEmpty,
            isTrue,
            reason: 'Key "$key" cannot be empty for language "$lang"',
          );
        }
      }
    });

    test('All background location statements contain required closed/not in use disclosure', () {
      // English
      final en = AppTranslations.translations['en']!['bg_location_disclosure_statement']!;
      expect(en.toLowerCase().contains('closed or not in use'), isTrue);

      // Uzbek
      final uz = AppTranslations.translations['uz']!['bg_location_disclosure_statement']!;
      expect(uz.toLowerCase().contains('yopiq') && uz.toLowerCase().contains('fonda'), isTrue);

      // Russian
      final ru = AppTranslations.translations['ru']!['bg_location_disclosure_statement']!;
      expect(ru.toLowerCase().contains('закрыто') && ru.toLowerCase().contains('фоновом'), isTrue);

      // Kyrgyz
      final ky = AppTranslations.translations['ky']!['bg_location_disclosure_statement']!;
      expect(ky.toLowerCase().contains('жабык') && ky.toLowerCase().contains('фондо'), isTrue);
    });
  });

  group('LocationDisclosureDialog Widget Tests', () {
    testWidgets('Renders Foreground Disclosure properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLanguage.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            body: LocationDisclosureDialog(isBackgroundMode: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(AppTranslations.translations['uz']!['location_disclosure_title']!), findsOneWidget);
      expect(find.text(AppTranslations.translations['uz']!['location_accept']!), findsOneWidget);
      expect(find.text(AppTranslations.translations['uz']!['location_decline']!), findsOneWidget);
    });

    testWidgets('Renders Background Disclosure properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLanguage.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            body: LocationDisclosureDialog(isBackgroundMode: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(AppTranslations.translations['uz']!['bg_location_disclosure_title']!), findsOneWidget);
      expect(find.text(AppTranslations.translations['uz']!['bg_location_open_settings']!), findsOneWidget);
      expect(find.text(AppTranslations.translations['uz']!['bg_location_cancel']!), findsOneWidget);
    });
  });
}
