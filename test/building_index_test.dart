import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/features/rahbar/data/building_index.dart';

void main() {
  final b = BuildingIndex.instance;
  // ~40×40 m bino.
  const house = [
    (lat: 41.30000, lng: 69.24000),
    (lat: 41.30036, lng: 69.24000),
    (lat: 41.30036, lng: 69.24048),
    (lat: 41.30000, lng: 69.24048),
    (lat: 41.30000, lng: 69.24000),
  ];

  setUp(() {
    b.clearForTest();
    b.addForTest(house);
  });

  test('bino ustidan o\'tgan kesma aniqlanadi, yonidan o\'tgani yo\'q', () {
    expect(
      b.crosses((lat: 41.30018, lng: 69.23980), (lat: 41.30018, lng: 69.24070)),
      isTrue,
    );
    // Bino yonidagi trotuar (5 m shimolda) — taqiqlanmaydi.
    expect(
      b.crosses((lat: 41.30041, lng: 69.23980), (lat: 41.30041, lng: 69.24070)),
      isFalse,
    );
  });

  test('clipOutside: bino ichi kesiladi, chiziq devor oldida to\'xtaydi', () {
    final parts = b.clipOutside(const [
      (lat: 41.30018, lng: 69.23980),
      (lat: 41.30018, lng: 69.24070),
    ]);
    expect(parts.length, 2);
    expect(parts.first.last.lng, closeTo(69.24000, 1e-6));
    expect(parts.last.first.lng, closeTo(69.24048, 1e-6));
  });

  test('bino ichida tugagan chiziq eshik (devor) oldida to\'xtaydi', () {
    final parts = b.clipOutside(const [
      (lat: 41.30018, lng: 69.23980),
      (lat: 41.30018, lng: 69.24020), // bino ichida
    ]);
    expect(parts.length, 1);
    expect(parts.single.last.lng, closeTo(69.24000, 1e-6));
  });

  test('konturlar yo\'q — tekshiruv o\'chiq', () {
    b.clearForTest();
    expect(b.isReady, isFalse);
    expect(
      b.crosses((lat: 41.30018, lng: 69.23980), (lat: 41.30018, lng: 69.24070)),
      isFalse,
    );
  });

  test(
    'outside: bino ichidagi nuqta eng yaqin devor tashqarisiga suriladi',
    () {
      // G'arbiy devordan ~4 m ichkarida.
      final q = b.outside((lat: 41.30018, lng: 69.24005));
      expect(q.lng, lessThan(69.24000));
      expect(b.crosses(q, (lat: 41.30018, lng: 69.23980)), isFalse);
      // Tashqaridagi nuqta o'zgarmaydi.
      const out = (lat: 41.30100, lng: 69.24000);
      expect(b.outside(out), out);
    },
  );
}
