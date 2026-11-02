import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/utils/day_change_watcher.dart';

void main() {
  testWidgets('00:00 da yangi kun (ilova ochiq)', (tester) async {
    var now = DateTime(2026, 10, 28, 23, 59, 50);
    final days = <DateTime>[];
    final w = DayChangeWatcher(onNewDay: days.add, clock: () => now);

    // 23:59:55 — hali kecha.
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(days, isEmpty);

    // Yarim tun o'tdi (taymer 00:00:01 da).
    now = DateTime(2026, 10, 29, 0, 0, 1);
    await tester.pump(const Duration(seconds: 6));
    expect(days, [DateTime(2026, 10, 29)]);
    expect(w.today, DateTime(2026, 10, 29));
    w.dispose();
  });

  testWidgets('kunduzi (09:00, 12:00) kun almashmaydi', (tester) async {
    var now = DateTime(2026, 10, 29, 0, 5);
    final days = <DateTime>[];
    final w = DayChangeWatcher(onNewDay: days.add, clock: () => now);
    for (final h in [9, 12, 18, 23]) {
      now = DateTime(2026, 10, 29, h);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }
    expect(days, isEmpty);
    w.dispose();
  });

  testWidgets('ertalab orqa fondan qaytganda (taymer ishlamagan)', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 28, 21);
    final days = <DateTime>[];
    final w = DayChangeWatcher(onNewDay: days.add, clock: () => now);

    // Telefon uxlagan: taymer ishlamadi, soat 9 da ilova ochildi.
    now = DateTime(2026, 10, 29, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(days, [DateTime(2026, 10, 29)]);

    // Qayta qaytish — ikkinchi marta chaqirilmaydi.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(days, hasLength(1));
    w.dispose();
  });

  testWidgets('dispose dan keyin chaqirilmaydi', (tester) async {
    var now = DateTime(2026, 10, 28, 23, 59, 59);
    final days = <DateTime>[];
    final w = DayChangeWatcher(onNewDay: days.add, clock: () => now)..dispose();
    now = DateTime(2026, 10, 29, 0, 0, 5);
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    w.check();
    expect(days, isEmpty);
  });
}
