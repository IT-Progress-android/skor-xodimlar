import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';
import 'package:skore_hodimlar/core/widgets/app_update_bottom_sheet.dart';
import 'package:skore_hodimlar/core/widgets/app_update_gate.dart';

void main() {
  group('AppUpdateService SemVer Comparison Tests', () {
    test(
      'User on same version (1.0.8 vs 1.0.8) should NEVER prompt update',
      () {
        final result = AppUpdateService.compareSemVer('1.0.8', '1.0.8');
        expect(result, equals(0));
        expect(result > 0, isFalse);
      },
    );

    test(
      'User on newer version than store (1.0.8 vs 1.0.7) should NEVER prompt update',
      () {
        final result = AppUpdateService.compareSemVer('1.0.7', '1.0.8');
        expect(result, equals(-1));
        expect(result > 0, isFalse);
      },
    );

    test('Store has newer patch version (1.0.9 vs 1.0.8) triggers update', () {
      final result = AppUpdateService.compareSemVer('1.0.9', '1.0.8');
      expect(result, equals(1));
      expect(result > 0, isTrue);
    });

    test('Store has newer minor version (1.1.0 vs 1.0.8) triggers update', () {
      final result = AppUpdateService.compareSemVer('1.1.0', '1.0.8');
      expect(result, equals(1));
      expect(result > 0, isTrue);
    });

    test('Store has newer major version (2.0.0 vs 1.0.8) triggers update', () {
      final result = AppUpdateService.compareSemVer('2.0.0', '1.0.8');
      expect(result, equals(1));
      expect(result > 0, isTrue);
    });

    test('Handles dirty strings like "v1.0.8" or "1.0.8+15"', () {
      expect(AppUpdateService.compareSemVer('v1.0.8', '1.0.8'), equals(0));
      expect(AppUpdateService.compareSemVer('1.0.8', 'v1.0.8'), equals(0));
      expect(AppUpdateService.compareSemVer('v1.0.9', '1.0.8'), equals(1));
    });
  });

  group('Majburiy yangilanish', () {
    setUp(() {
      AppUpdateService.forcedUpdate.value = null;
      AppUpdateService.currentVersion = '1.0.15';
      AppUpdateService.currentBuildNumber = 29;
    });

    Future<SharedPreferences> prefsWith(Map<String, Object> forced) async {
      SharedPreferences.setMockInitialValues({
        'forced_update_android': jsonEncode(forced),
      });
      return SharedPreferences.getInstance();
    }

    test('saqlangan talab yangiroq bo\'lsa internetsiz ham yopiq', () async {
      final prefs = await prefsWith({'version': '1.0.16', 'buildNumber': 30});
      await AppUpdateService.restoreForcedUpdate(prefs);
      expect(AppUpdateService.forcedUpdate.value?.version, '1.0.16');
    });

    test('allaqachon yangilangan bo\'lsa talab o\'chiriladi', () async {
      final prefs = await prefsWith({'version': '1.0.15', 'buildNumber': 29});
      await AppUpdateService.restoreForcedUpdate(prefs);
      expect(AppUpdateService.forcedUpdate.value, isNull);
      expect(prefs.getString('forced_update_android'), isNull);
    });

    testWidgets('darvoza ilovani butunlay yashiradi', (tester) async {
      AppUpdateService.forcedUpdate.value = const AppUpdateInfo(
        version: '1.0.16',
        buildNumber: 30,
        isMandatory: true,
      );
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
          builder: (context, child) => AppUpdateGate(child: child!),
          home: const Scaffold(body: Text('ilova')),
        ),
      );
      await tester.pump();

      expect(find.byType(ForceUpdatePage), findsOneWidget);
      expect(find.text('ilova'), findsNothing);
      expect(find.text('Yangilash'), findsOneWidget);
      expect(find.text('Keyinroq'), findsNothing);
    });
  });
}
