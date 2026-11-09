import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/utils/app_day.dart';

void main() {
  testWidgets('00:00 da tinglovchilar chaqiriladi, "bugun" sahifa o\'tadi', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 2, 23, 59, 58);
    final day = AppDay(clock: () => now)..start();
    var calls = 0;
    day.addListener(() => calls++);
    final shown = DateTime(2026, 11, 2); // sahifa "bugun"ni ko'rsatyapti

    now = DateTime(2026, 11, 3, 0, 0, 1);
    await tester.pump(const Duration(seconds: 4));

    expect(calls, 1);
    expect(day.today, DateTime(2026, 11, 3));
    expect(day.wasToday(shown), isTrue);
    // Qo'lda tanlangan boshqa sana o'zgarmaydi.
    expect(day.wasToday(DateTime(2026, 10, 30)), isFalse);
    day.dispose();
  });

  testWidgets('telefon bir necha kun uxlasa ham yangi kunga o\'tadi', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 31, 18); // juma kechqurun
    final day = AppDay(clock: () => now)..start();
    final shown = DateTime(2026, 10, 31);

    // Dushanba ertalab ilova ochildi (taymer ishlamagan).
    now = DateTime(2026, 11, 3, 8, 35);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(day.today, DateTime(2026, 11, 3));
    // Avvalgi shart ("kecha"mi?) bu yerda yolg'on bo'lardi: 31.10 != 02.11.
    expect(day.wasToday(shown), isTrue);
    day.dispose();
  });

  testWidgets('taymer va resume yo\'qolsa — daqiqalik zaxira tekshiruv', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 2, 23, 0);
    final day = AppDay(clock: () => now)..start();
    // Soat oldinga sakradi (masalan, telefon soati to'g'rilandi).
    now = DateTime(2026, 11, 3, 0, 30);
    await tester.pump(const Duration(minutes: 1));
    expect(day.today, DateTime(2026, 11, 3));
    day.dispose();
  });

  group('shiftRangeToNewDay', () {
    test('"bugungacha" oraliq uzunligi saqlanib suriladi', () {
      final r = shiftRangeToNewDay(
        from: DateTime(2026, 10, 3),
        to: DateTime(2026, 11, 2, 15, 20),
        previous: DateTime(2026, 11, 2),
        today: DateTime(2026, 11, 3),
      );
      expect(r, isNotNull);
      expect(r!.from, DateTime(2026, 10, 4));
      expect(r.to, DateTime(2026, 11, 3));
    });

    test('qo\'lda tanlangan o\'tgan oraliq o\'zgarmaydi', () {
      final r = shiftRangeToNewDay(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        previous: DateTime(2026, 11, 2),
        today: DateTime(2026, 11, 3),
      );
      expect(r, isNull);
    });
  });

  test('GPS: sessiya tugaganda kechagi zona holati tozalanadi', () async {
    SharedPreferences.setMockInitialValues({
      fgsInsideZoneKey: true,
      fgsCurrentZoneKey: 7,
      'boshqa': 'qoladi',
    });
    final prefs = await SharedPreferences.getInstance();
    await clearFgsZoneState(prefs);
    expect(prefs.getBool(fgsInsideZoneKey), isNull);
    expect(prefs.getInt(fgsCurrentZoneKey), isNull);
    expect(prefs.getString('boshqa'), 'qoladi');
  });
}
