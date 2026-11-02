import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';
import 'package:skore_hodimlar/features/rahbar/data/street_router.dart';
import 'package:skore_hodimlar/features/rahbar/data/walk_route_store.dart';

const _lat0 = 41.3, _lng0 = 69.24;
const _mLat = 1 / 111320;
final _mLng = 1 / (111320 * math.cos(_lat0 * math.pi / 180));
final t0 = DateTime(2026, 10, 28, 10);

/// Sharqqa 1,3 m/s piyoda, har soniyada nuqta, ±5 m titrash.
List<TimedPoint> walkEast(int seconds) => [
  for (var s = 0; s <= seconds; s++)
    (
      lat: _lat0 + (s.isEven ? 5 : -5) * _mLat,
      lng: _lng0 + 1.3 * s * _mLng,
      time: t0.add(Duration(seconds: s)),
    ),
];

/// Izdan 4 m shimoldagi yo'lak.
Future<List<List<LatLng>>> footway(List<LatLng> pts) async => [
  [for (final p in pts) (lat: _lat0 + 4 * _mLat, lng: p.lng)],
];

Future<void> settle(StreetRouter r) async {
  await r.whenIdle();
  // Saqlash 2 s kechikib ketadi — dispose darhol yozadi.
}

void main() {
  test('saqlangan natija bilan qayta ochilganda so\'rov ketmaydi', () async {
    final store = MemoryWalkRouteStore();
    final raw = walkEast(300);

    var calls = 0;
    final first = StreetRouter(
      onUpdate: () {},
      walkStore: store,
      walkRequester: (pts) {
        calls++;
        return footway(pts);
      },
    );
    await first.ready;
    first.walkPath(raw);
    await settle(first);
    final drawn = first.walkPath(raw);
    expect(calls, greaterThan(0));
    first.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(store.saves, 1);
    expect(store.data, isNotEmpty);

    // Ilova qayta ochildi.
    var again = 0;
    final second = StreetRouter(
      onUpdate: () {},
      walkStore: store,
      walkRequester: (pts) {
        again++;
        return footway(pts);
      },
    );
    addTearDown(second.dispose);
    await second.ready;
    final line = second.walkPath(raw);
    expect(second.isBusy, isFalse);
    expect(again, 0);
    expect(line, drawn);
  });

  test('"mos yo\'l yo\'q" ham saqlanadi — qayta so\'ralmaydi', () async {
    final store = MemoryWalkRouteStore();
    final raw = walkEast(200);
    final first = StreetRouter(
      onUpdate: () {},
      walkStore: store,
      // 150 m naridagi ko'cha — rad etiladi.
      walkRequester: (pts) async => [
        [for (final p in pts) (lat: p.lat + 150 * _mLat, lng: p.lng)],
      ],
    );
    await first.ready;
    first.walkPath(raw);
    await settle(first);
    first.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(store.data.values.where((v) => v.isEmpty), isNotEmpty);

    var calls = 0;
    final second = StreetRouter(
      onUpdate: () {},
      walkStore: store,
      walkRequester: (pts) async {
        calls++;
        return const [];
      },
    );
    addTearDown(second.dispose);
    await second.ready;
    second.walkPath(raw);
    expect(second.isBusy, isFalse);
    expect(calls, 0);
  });

  test(
    'internet xatosi saqlanmaydi — keyingi safar qayta so\'raladi',
    () async {
      final store = MemoryWalkRouteStore();
      final raw = walkEast(100);
      final first = StreetRouter(
        onUpdate: () {},
        walkStore: store,
        walkRequester: (pts) async => throw StateError('internet yo\'q'),
      );
      await first.ready;
      first.walkPath(raw);
      await settle(first);
      first.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(store.data, isEmpty);

      var calls = 0;
      final second = StreetRouter(
        onUpdate: () {},
        walkStore: store,
        walkRequester: (pts) {
          calls++;
          return footway(pts);
        },
      );
      addTearDown(second.dispose);
      await second.ready;
      second.walkPath(raw);
      await second.whenIdle();
      expect(calls, greaterThan(0));
    },
  );

  test('ombor o\'qilmasa ham ishlaydi (so\'rov bilan)', () async {
    final router = StreetRouter(
      onUpdate: () {},
      walkStore: _BrokenStore(),
      walkRequester: footway,
    );
    addTearDown(router.dispose);
    await router.ready;
    router.walkPath(walkEast(100));
    expect(router.isBusy, isTrue);
    await router.whenIdle();
  });

  group('encode/decode', () {
    test('qaytadan o\'qilganda bir xil (6 xona aniqlik)', () {
      final data = {
        'w1': [(lat: 41.123456, lng: 69.654321), (lat: 41.2, lng: 69.3)],
        'w2': <LatLng>[],
      };
      final back = decodeWalkRoutes(encodeWalkRoutes(data));
      expect(back.keys, data.keys);
      expect(back['w1']![0].lat, closeTo(41.123456, 1e-9));
      expect(back['w1']![1].lng, closeTo(69.3, 1e-9));
      expect(back['w2'], isEmpty);
    });

    test('buzilgan fayl — bo\'sh, buzilgan yozuv tashlanadi', () {
      expect(decodeWalkRoutes('{yarim'), isEmpty);
      expect(decodeWalkRoutes('[1,2]'), isEmpty);
      final back = decodeWalkRoutes(
        '{"a":[41.1,69.2],"b":[1],"c":"x","d":[1,"y"]}',
      );
      expect(back.keys, ['a']);
    });
  });
}

class _BrokenStore implements WalkRouteStore {
  @override
  Future<Map<String, List<LatLng>>> load() async => throw StateError('disk');

  @override
  Future<void> save(Map<String, List<LatLng>> entries) async {}
}
