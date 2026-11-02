import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/security/app_lock_service.dart';
import 'package:skore_hodimlar/core/theme/app_theme.dart';
import 'package:skore_hodimlar/core/security/pin_pad.dart';

void main() {
  test('PIN xeshi tuzga bog\'liq va PIN o\'zi saqlanmaydi', () {
    final a = hashPin('1234', 'salt-a');
    expect(a, isNot(contains('1234')));
    expect(hashPin('1234', 'salt-a'), a);
    expect(hashPin('1234', 'salt-b'), isNot(a));
    expect(hashPin('1235', 'salt-a'), isNot(a));
  });

  test('fonda 30 soniyadan ko\'p tursa qulf', () {
    expect(shouldLockAfter(const Duration(seconds: 10)), isFalse);
    expect(shouldLockAfter(const Duration(seconds: 29)), isFalse);
    expect(shouldLockAfter(const Duration(seconds: 30)), isTrue);
    expect(shouldLockAfter(const Duration(minutes: 5)), isTrue);
  });

  testWidgets('PinPad 4 raqamdan keyin tekshiradi, xatoda tozalaydi', (
    tester,
  ) async {
    final entered = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PinPad(
              title: 'PIN',
              onCompleted: (pin) async {
                entered.add(pin);
                return pin == '2580';
              },
            ),
          ),
        ),
      ),
    );

    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(entered, ['1234']);

    for (final d in ['2', '5', '8', '0']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(entered, ['1234', '2580']);
  });

  testWidgets('qurilish paytida yo\'nalish o\'zgarsa xato chiqmaydi', (
    tester,
  ) async {
    final lock = AppLockService.instance;
    var builds = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            ListenableBuilder(
              listenable: lock,
              builder: (context, _) {
                builds++;
                return const SizedBox();
              },
            ),
            // go_router kabi: qurilish paytida yo'nalish xabari.
            Builder(
              builder: (context) {
                lock.onRoute('/test-${builds == 1 ? 'a' : 'b'}');
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(builds, greaterThan(1));
  });

  testWidgets('PinPad Overlay\'siz joyda ham xatosiz chiziladi', (
    tester,
  ) async {
    // Qulf ekrani MaterialApp builder'ida — Navigator/Overlay'dan tashqarida.
    await tester.pumpWidget(
      Theme(
        data: AppTheme.lightTheme,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 900)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              child: SingleChildScrollView(
                child: PinPad(
                  title: 'PIN',
                  onCompleted: (_) async => true,
                  leading: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.fingerprint_rounded),
                  ),
                  footer: TextButton(onPressed: () {}, child: const Text('?')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.fingerprint_rounded));
    await tester.longPress(find.byIcon(Icons.fingerprint_rounded));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
