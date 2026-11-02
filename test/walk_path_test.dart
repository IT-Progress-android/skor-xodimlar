import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/features/rahbar/data/speed_track.dart'
    show TrackPieceKind, buildSpeedTrack;
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';
import 'package:skore_hodimlar/features/rahbar/data/street_router.dart';
import 'package:skore_hodimlar/features/rahbar/data/walk_path.dart';

/// Toshkent atrofida: shimolga [north] m, sharqqa [east] m.
const _lat0 = 41.3, _lng0 = 69.24;
const _mLat = 1 / 111320;
final _mLng = 1 / (111320 * math.cos(_lat0 * math.pi / 180));

LatLng at(double north, double east) =>
    (lat: _lat0 + north * _mLat, lng: _lng0 + east * _mLng);

final t0 = DateTime(2026, 10, 28, 10);

TimedPoint tp(double north, double east, int sec) {
  final p = at(north, east);
  return (lat: p.lat, lng: p.lng, time: t0.add(Duration(seconds: sec)));
}

/// Sharqqa 1,3 m/s piyoda, har soniyada nuqta; GPS ±[jitter] m zigzag.
List<TimedPoint> walkEast(int seconds, {double jitter = 0, int startSec = 0}) =>
    [
      for (var s = 0; s <= seconds; s++)
        tp(s.isEven ? jitter : -jitter, 1.3 * s, startSec + s),
    ];

/// Avval sharqqa [legSec] s, keyin shimolga [legSec] s (90° burilish).
List<TimedPoint> walkL(int legSec, {double jitter = 0}) => [
  for (var s = 0; s <= legSec; s++) tp(s.isEven ? jitter : -jitter, 1.3 * s, s),
  for (var s = 1; s <= legSec; s++)
    tp(1.3 * s, 1.3 * legSec + (s.isEven ? jitter : -jitter), legSec + s),
];

double maxDeviation(List<LatLng> line, List<LatLng> reference) =>
    line.map((p) => distanceToLine(p, reference)).fold(0.0, math.max);

/// Ketma-ket kesmalar orasidagi eng keskin burilish (gradus).
double sharpestTurn(List<LatLng> line) {
  var worst = 0.0;
  for (var i = 1; i < line.length - 1; i++) {
    final a = line[i - 1], b = line[i], c = line[i + 1];
    final h1 = math.atan2((b.lat - a.lat) / _mLat, (b.lng - a.lng) / _mLng);
    final h2 = math.atan2((c.lat - b.lat) / _mLat, (c.lng - b.lng) / _mLng);
    var d = (h2 - h1).abs() * 180 / math.pi;
    if (d > 180) d = 360 - d;
    worst = math.max(worst, d);
  }
  return worst;
}

LatLng ll(TimedPoint p) => (lat: p.lat, lng: p.lng);

void main() {
  group('smoothWalkTrack', () {
    test('GPS titrashi (±8 m zigzag) yo\'qoladi', () {
      final raw = walkEast(120, jitter: 8);
      final smooth = smoothWalkTrack(raw);
      final axis = [at(0, 0), at(0, 1.3 * 120)];
      expect(maxDeviation([for (final p in raw) ll(p)], axis), closeTo(8, 0.5));
      // Uchlaridan uzoqda chetlanish ~1 m dan oshmaydi.
      final inner = smooth.sublist(15, smooth.length - 15);
      expect(maxDeviation([for (final p in inner) ll(p)], axis), lessThan(1.5));
    });

    test('uchlari va vaqtlar o\'zgarmaydi', () {
      final raw = walkEast(30, jitter: 5);
      final smooth = smoothWalkTrack(raw);
      expect(smooth, hasLength(raw.length));
      expect(smooth.first, raw.first);
      expect(smooth.last, raw.last);
      for (var i = 0; i < raw.length; i++) {
        expect(smooth[i].time, raw[i].time);
      }
    });

    test('90° burilish saqlanadi (burchak kesilmaydi)', () {
      final smooth = smoothWalkTrack(walkL(60));
      final corner = at(0, 1.3 * 60);
      final nearest = smooth
          .map((p) => distanceMeters(p.lat, p.lng, corner.lat, corner.lng))
          .reduce(math.min);
      expect(nearest, lessThan(4));
    });

    test('siyrak nuqtalar (30 s oraliq) deyarli o\'zgarmaydi', () {
      final raw = [
        for (var i = 0; i < 6; i++) tp(i.isEven ? 6 : -6, 40.0 * i, 30 * i),
      ];
      final smooth = smoothWalkTrack(raw);
      for (var i = 0; i < raw.length; i++) {
        expect(
          distanceMeters(raw[i].lat, raw[i].lng, smooth[i].lat, smooth[i].lng),
          lessThan(0.1),
        );
      }
    });

    test('2 tadan kam nuqta — nusxa', () {
      final one = [tp(0, 0, 0)];
      expect(smoothWalkTrack(one), one);
      expect(smoothWalkTrack(const []), isEmpty);
    });
  });

  group('walkAnchors', () {
    test('to\'g\'ri yo\'lda har ≤ 80 m da tayanch, uchlari bor', () {
      final smooth = smoothWalkTrack(walkEast(400));
      final anchors = walkAnchors(smooth);
      expect(anchors.first, smooth.first);
      expect(anchors.last, smooth.last);
      for (var i = 1; i < anchors.length; i++) {
        final d = distanceMeters(
          anchors[i - 1].lat,
          anchors[i - 1].lng,
          anchors[i].lat,
          anchors[i].lng,
        );
        expect(d, lessThanOrEqualTo(walkMaxAnchorGapM + 2));
        expect(d, greaterThanOrEqualTo(walkMinAnchorGapM));
      }
    });

    test('burilish nuqtasi tayanch bo\'ladi', () {
      final anchors = walkAnchors(smoothWalkTrack(walkL(60)));
      final corner = at(0, 1.3 * 60);
      expect(
        anchors
            .map((p) => distanceMeters(p.lat, p.lng, corner.lat, corner.lng))
            .reduce(math.min),
        lessThan(6),
      );
    });

    test('tayanchlar vaqt bo\'yicha tartibda', () {
      final anchors = walkAnchors(smoothWalkTrack(walkL(90, jitter: 4)));
      for (var i = 1; i < anchors.length; i++) {
        expect(anchors[i].time.isAfter(anchors[i - 1].time), isTrue);
      }
    });

    test('juda qisqa yurish — ikki uchi', () {
      final anchors = walkAnchors(smoothWalkTrack(walkEast(8)));
      expect(anchors, hasLength(2));
    });
  });

  group('walkChunks', () {
    test('bo\'laklar ≤ size, qo\'shnilari umumiy nuqtada tutashadi', () {
      final anchors = [for (var i = 0; i < 30; i++) tp(0, 20.0 * i, 15 * i)];
      final chunks = walkChunks(anchors, size: 12);
      expect(chunks, hasLength(3));
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(12));
        expect(c.length, greaterThanOrEqualTo(2));
      }
      for (var i = 1; i < chunks.length; i++) {
        expect(chunks[i].first, chunks[i - 1].last);
      }
      expect(chunks.first.first, anchors.first);
      expect(chunks.last.last, anchors.last);
    });

    test('bitta tayanch — bo\'lak yo\'q', () {
      expect(walkChunks([tp(0, 0, 0)]), isEmpty);
    });
  });

  group('acceptWalkMatch', () {
    final raw = walkEast(150, jitter: 6);
    final length = 1.3 * 150;

    test('izdan 5 m yondagi yo\'lak — qabul', () {
      final path = [for (var e = 0.0; e <= length; e += 10) at(5, e)];
      expect(acceptWalkMatch(path, raw), isTrue);
    });

    test('100 m naridagi parallel ko\'cha — rad', () {
      final path = [at(0, 0), at(100, 0), at(100, length), at(0, length)];
      expect(acceptWalkMatch(path, raw), isFalse);
    });

    test('izga yaqin, lekin juda uzun (aylanma ilmoq) — rad', () {
      final path = <LatLng>[
        at(0, 0),
        at(0, length / 2),
        // Yon yo'lakka 120 m kirib qaytgan.
        at(120, length / 2),
        at(120, length / 2 + 10),
        at(0, length / 2 + 10),
        at(0, length),
      ];
      expect(acceptWalkMatch(path, raw), isFalse);
    });

    test('uchi izdan uzoq (boshqa joydan boshlangan) — rad', () {
      final path = [at(0, -60), at(0, length)];
      expect(acceptWalkMatch(path, raw), isFalse);
    });

    test('bo\'sh yo\'l yoki bo\'sh iz — rad', () {
      expect(acceptWalkMatch(const [], raw), isFalse);
      expect(acceptWalkMatch([at(0, 0), at(0, 10)], const []), isFalse);
    });
  });

  group('stitchWalkParts', () {
    test('tutashgan uchdagi takror nuqta bir marta', () {
      final out = stitchWalkParts([
        [at(0, 0), at(0, 20)],
        [at(0, 20), at(0, 40)],
      ]);
      expect(out, [at(0, 0), at(0, 20), at(0, 40)]);
    });

    test('ulanishdagi borib-qaytgan dumcha kesiladi', () {
      // Via-nuqta yon yo'lakka tushgan: 1-bo'lak yon yo'lakka 15 m kirib
      // tugaydi, 2-bo'lak o'sha yerdan qaytib davom etadi.
      final out = stitchWalkParts([
        [at(0, 0), at(0, 50), at(15, 50)],
        [at(15, 50), at(0, 50), at(0, 100)],
      ]);
      expect(maxDeviation(out, [at(0, 0), at(0, 100)]), lessThan(0.5));
      expect(walkLength(out), closeTo(100, 1));
    });

    test('uzun haqiqiy burilish kesilmaydi', () {
      final parts = [
        [at(0, 0), at(0, 50), at(80, 50)],
        [at(80, 50), at(80, 120)],
      ];
      final out = stitchWalkParts(parts);
      expect(walkLength(out), closeTo(50 + 80 + 70, 1));
    });

    test('uzilgan bo\'laklar to\'g\'ri ulanadi', () {
      final out = stitchWalkParts([
        [at(0, 0), at(0, 20)],
        [at(0, 25), at(0, 40)],
      ]);
      expect(out, hasLength(4));
    });
  });

  group('removeWalkSpurs', () {
    test('via-nuqtaga kirib-qaytgan dumchalar kesiladi', () {
      // To'g'ri yo'lak, ikki joyda yon yo'lakka 20 va 30 m kirib-qaytgan.
      final line = [
        at(0, 0),
        at(0, 40),
        at(20, 40),
        at(0, 40),
        at(0, 90),
        at(30, 90),
        at(0, 90),
        at(0, 150),
      ];
      final out = removeWalkSpurs(line);
      expect(walkLength(out), closeTo(150, 1));
      expect(maxDeviation(out, [at(0, 0), at(0, 150)]), lessThan(0.5));
    });

    test('kvartal atrofidan aylanish (qaytmasdan) saqlanadi', () {
      final line = [at(0, 0), at(0, 60), at(60, 60), at(60, 120)];
      expect(removeWalkSpurs(line), line);
    });

    test('uzun borib-qaytish (> 80 m) kesilmaydi', () {
      final line = [at(0, 0), at(0, 40), at(60, 40), at(0, 40), at(0, 80)];
      expect(walkLength(removeWalkSpurs(line)), closeTo(200, 1));
    });
  });

  group('maxOffTrack + acceptWalkMatch', () {
    test('kesma o\'rtasidagi chetlanish ham topiladi', () {
      final track = [at(0, 0), at(0, 100)];
      // Uchlari izda, o'rtasi 40 m chetda (2 ta nuqta).
      expect(
        maxOffTrack([at(0, 0), at(40, 50), at(0, 100)], track),
        closeTo(40, 1),
      );
      expect(maxOffTrack([at(5, 0), at(5, 100)], track), closeTo(5, 0.5));
    });

    test('xodim bormagan joydan aylanma (60 m chetda) — rad', () {
      final raw = walkEast(100, jitter: 3);
      final path = [at(0, 0), at(0, 30), at(60, 40), at(0, 50), at(0, 130)];
      expect(acceptWalkMatch(path, raw), isFalse);
      expect(walkMatchProblem(path, raw), startsWith('izdan chetda'));
    });
  });

  group('mergeParallelWalks', () {
    test('borib-qaytish (12 m yondagi parallel yo\'lak) bitta chiziqqa', () {
      final there = [at(0, 0), at(0, 200)];
      final back = [at(12, 200), at(12, 0)];
      final out = mergeParallelWalks([there, back]);
      expect(out.first, there);
      expect(maxDeviation(out[1], there), lessThan(0.5));
      expect(walkLength(out[1]), closeTo(200, 2));
    });

    test('bitta chiziq ichida borib-qaytish ham ustma-ust', () {
      final line = [at(0, 0), at(0, 200), at(10, 200), at(10, 0)];
      final out = mergeParallelWalks([line]).single;
      expect(maxDeviation(out, [at(0, 0), at(0, 200)]), lessThan(0.5));
    });

    test('uzoqdagi (40 m) alohida yo\'l o\'zgarmaydi', () {
      final a = [at(0, 0), at(0, 200)];
      final b = [at(40, 0), at(40, 200)];
      final out = mergeParallelWalks([a, b]);
      expect(out[1], b);
    });

    test('faqat yaqin qismi yopishadi, qolgan asosiy chiziq joyida', () {
      final a = [at(0, 0), at(0, 100)];
      // 0..100 da a ga 10 m yaqin, keyin 100..200 da a dan uzoqlashgan.
      final b = [at(10, 0), at(10, 100), at(60, 100), at(60, 200)];
      final out = mergeParallelWalks([a, b])[1];
      final near = out.where((p) => p.lng < _lng0 + 90 * _mLng).toList();
      expect(maxDeviation(near, a), lessThan(0.5));
      // Uzoq qismi (60 m shimolda) o'zgarmagan.
      final far = out.where((p) => p.lng > _lng0 + 101 * _mLng).toList();
      expect(far, isNotEmpty);
      expect(maxDeviation(far, [at(60, 100), at(60, 200)]), lessThan(0.5));
    });

    test('qaytishdagi kichik ilmoq (30 m chetga) ham chiziqqa', () {
      final a = [at(0, 0), at(0, 300)];
      final b = [
        at(5, 300),
        at(5, 160),
        at(30, 150),
        at(30, 120),
        at(5, 110),
        at(5, 0),
      ];
      final out = mergeParallelWalks([a, b])[1];
      expect(maxDeviation(out, a), lessThan(0.5));
    });

    test('katta ilmoq (60 m chetga — boshqa yo\'l) saqlanadi', () {
      final a = [at(0, 0), at(0, 300)];
      final b = [
        at(5, 300),
        at(5, 180),
        at(60, 170),
        at(60, 130),
        at(5, 120),
        at(5, 0),
      ];
      final out = mergeParallelWalks([a, b])[1];
      expect(maxDeviation([at(60, 150)], out), lessThan(1));
    });

    test('oxiridagi qisqa ilgak chiziqqa qo\'yiladi', () {
      final a = [at(0, 0), at(0, 300)];
      final b = [at(5, 300), at(5, 100), at(28, 95)];
      final out = mergeParallelWalks([a, b])[1];
      expect(maxDeviation(out, a), lessThan(0.5));
    });

    test(
      'bukilish ustidan vatar emas — oldingi chiziq bo\'ylab (D ilmoq yo\'q)',
      () {
        // Borishda 13 m bukilish, qaytishda to'g'ri.
        final there = [
          at(0, 0),
          at(0, 100),
          at(13, 105),
          at(13, 125),
          at(0, 130),
          at(0, 230),
        ];
        final back = [at(-3, 230), at(-3, 0)];
        final out = mergeParallelWalks([there, back])[1];
        // Qaytish chizig'ining hamma joyi borish chizig'i ustida.
        expect(maxDeviation(out, there), lessThan(0.5));
        // Va bukilish cho'qqisidan o'tadi.
        expect(maxDeviation([at(13, 115)], out), lessThan(0.5));
      },
    );

    test('kesishgan perpendikulyar yo\'l buzilmaydi', () {
      final a = [at(0, 0), at(0, 200)];
      final b = [at(-100, 100), at(100, 100)];
      final out = mergeParallelWalks([a, b])[1];
      expect(walkLength(out), closeTo(200, 3));
      expect(maxDeviation(out, b), lessThan(0.5));
    });
  });

  group('removeWalkSpurs asosiy chiziqqa tegmaydi', () {
    test('ko\'p dumchali uzun chiziq — asosiy yo\'l to\'liq qoladi', () {
      final main = <LatLng>[];
      for (var e = 0; e <= 600; e += 20) {
        main.add(at(0, e.toDouble()));
        if (e % 100 == 40) {
          main
            ..add(at(15, e.toDouble()))
            ..add(at(0, e.toDouble()));
        }
      }
      final out = removeWalkSpurs(main);
      expect(walkLength(out), closeTo(600, 1));
      expect(out.first, main.first);
      expect(out.last, main.last);
      expect(maxDeviation([at(0, 0), at(0, 600)], out), lessThan(0.5));
    });
  });

  group('removeNotches', () {
    final track = [at(0, 0), at(0, 200)];

    test('izdan 18 m chetga chiqib qaytgan o\'simta to\'g\'rilanadi', () {
      final line = [
        at(0, 0),
        at(0, 80),
        at(18, 85),
        at(18, 110),
        at(0, 115),
        at(0, 200),
      ];
      final out = removeNotches(line, track);
      expect(maxDeviation(out, track), lessThan(0.5));
      expect(out.first, line.first);
      expect(out.last, line.last);
    });

    test('GPS ham aylangan burilish (bino atrofi) saqlanadi', () {
      final turn = [
        at(0, 0),
        at(0, 80),
        at(25, 80),
        at(25, 110),
        at(0, 110),
        at(0, 200),
      ];
      // GPS izi ham shu aylanma bo'ylab.
      expect(removeNotches(turn, turn), turn);
    });

    test('kichik chetlanish (< 12 m) o\'zgarmaydi', () {
      final line = [at(0, 0), at(0, 80), at(8, 90), at(0, 100), at(0, 200)];
      expect(removeNotches(line, track), line);
    });

    test('uzun (> 40 m vatar) qism kesilmaydi — asosiy chiziq joyida', () {
      final line = [
        at(0, 0),
        at(0, 50),
        at(30, 50),
        at(30, 150),
        at(0, 150),
        at(0, 200),
      ];
      expect(removeNotches(line, track), line);
    });
  });

  group('roundCorners', () {
    final corner = [at(0, 0), at(0, 50), at(50, 50)];

    test('uchlari o\'zgarmaydi, burchak yumaloq', () {
      final out = roundCorners(corner);
      expect(out.first, corner.first);
      expect(out.last, corner.last);
      expect(sharpestTurn(corner), closeTo(90, 0.5));
      expect(sharpestTurn(out), lessThan(30));
    });

    test('chiziq yo\'lakdan chiqmaydi (≤ radius/2)', () {
      final out = roundCorners(corner);
      expect(
        maxDeviation(out, corner),
        lessThanOrEqualTo(walkCornerRadiusM / 2),
      );
    });

    test('qisqa kesmalarda radius kichrayadi — egrilar kesishmaydi', () {
      final zig = [at(0, 0), at(0, 4), at(4, 4), at(4, 8)];
      final out = roundCorners(zig);
      // Har nuqta oldingisidan sharqqa yoki shimolga — orqaga qaytmaydi.
      for (var i = 1; i < out.length; i++) {
        expect(out[i].lng, greaterThanOrEqualTo(out[i - 1].lng - 1e-12));
        expect(out[i].lat, greaterThanOrEqualTo(out[i - 1].lat - 1e-12));
      }
    });

    test('2 nuqtali chiziq o\'zgarmaydi', () {
      final line = [at(0, 0), at(0, 10)];
      expect(roundCorners(line), line);
    });
  });

  group('StreetRouter.walkPath', () {
    /// Haqiqiy yo'lak izdan 4 m shimolda: soxta marshrutlovchi so'ralgan
    /// nuqtalarni shu yo'lakka proyeksiya qilib qaytaradi.
    Future<List<List<LatLng>>> footway(List<LatLng> pts) async => [
      [for (final p in pts) (lat: _lat0 + 4 * _mLat, lng: p.lng)],
    ];

    test('avval silliq GPS izi, so\'ng yo\'lakka moslangan chiziq', () async {
      var updates = 0;
      final calls = <List<LatLng>>[];
      final router = StreetRouter(
        onUpdate: () => updates++,
        walkRequester: (pts) {
          calls.add(pts);
          return footway(pts);
        },
      );
      addTearDown(router.dispose);
      final raw = walkEast(300, jitter: 7);

      final first = router.walkPath(raw);
      // Xom izdagi 7 m titrash yo'q.
      final axis = [at(0, 0), at(0, 1.3 * 300)];
      final inner = first.sublist(20, first.length - 20);
      expect(maxDeviation(inner, axis), lessThan(2));
      expect(router.isBusy, isTrue);

      await router.whenIdle();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(updates, greaterThan(0));

      final matched = router.walkPath(raw);
      final walkway = [at(4, 0), at(4, 1.3 * 300)];
      expect(maxDeviation(matched, walkway), lessThan(0.5));
      // Har so'rov ≤ walkChunkSize nuqta, bo'laklar uzluksiz.
      expect(calls, isNotEmpty);
      for (final c in calls) {
        expect(c.length, lessThanOrEqualTo(walkChunkSize));
      }
      for (var i = 1; i < calls.length; i++) {
        expect(calls[i].first, calls[i - 1].last);
      }
    });

    test('mos kelmagan marshrut (boshqa ko\'cha) — silliq iz qoladi', () async {
      final router = StreetRouter(
        onUpdate: () {},
        walkRequester: (pts) async => [
          [for (final p in pts) (lat: p.lat + 150 * _mLat, lng: p.lng)],
        ],
      );
      addTearDown(router.dispose);
      final raw = walkEast(200, jitter: 5);
      router.walkPath(raw);
      await router.whenIdle();
      final line = router.walkPath(raw);
      expect(maxDeviation(line, [at(0, 0), at(0, 260)]), lessThan(6));
    });

    test('mos kelmagan bo\'lak ikkiga bo\'linib qayta so\'raladi', () async {
      // Ikkinchi yarmida yo'lak yo'q (xaritada o'tish joyi yo'q) —
      // marshrutlovchi 150 m aylanma beradi; birinchi yarmi yo'lak.
      final split = 1.3 * 150;
      final sizes = <int>[];
      final router = StreetRouter(
        onUpdate: () {},
        walkRequester: (pts) async {
          sizes.add(pts.length);
          final crossesGap = pts.any(
            (p) => p.lng > _lng0 + (split + 10) * _mLng,
          );
          return [
            [
              for (final p in pts)
                (lat: _lat0 + (crossesGap ? 150 : 4) * _mLat, lng: p.lng),
            ],
          ];
        },
      );
      addTearDown(router.dispose);
      final raw = walkEast(300, jitter: 6);
      router.walkPath(raw);
      await router.whenIdle();
      final line = router.walkPath(raw);
      // Birinchi qismi yo'lakda (4 m shimolda), qolgani silliq iz — hech
      // qayeri 150 m naridagi aylanmada emas.
      expect(
        sizes.length,
        greaterThan(walkChunks(walkAnchors(smoothWalkTrack(raw))).length),
      );
      expect(maxDeviation(line, [at(0, 0), at(0, 1.3 * 300)]), lessThan(8));
      final start = line.where((p) => p.lng < _lng0 + 60 * _mLng).toList();
      expect(maxDeviation(start, [at(4, 0), at(4, 60)]), lessThan(1));
    });

    test('marshrutlovchi xatosi — silliq iz, qayta so\'ralmaydi', () async {
      var calls = 0;
      final router = StreetRouter(
        onUpdate: () {},
        walkRequester: (pts) async {
          calls++;
          throw StateError('internet yo\'q');
        },
      );
      addTearDown(router.dispose);
      final raw = walkEast(100, jitter: 5);
      router.walkPath(raw);
      await router.whenIdle();
      final before = calls;
      final line = router.walkPath(raw);
      await router.whenIdle();
      expect(calls, before);
      expect(line.length, greaterThanOrEqualTo(2));
      expect(maxDeviation(line, [at(0, 0), at(0, 130)]), lessThan(6));
    });

    test('qisqa yurish (< 30 m) — marshrutlovchisiz', () async {
      var calls = 0;
      final router = StreetRouter(
        onUpdate: () {},
        walkRequester: (pts) async {
          calls++;
          return const [];
        },
      );
      addTearDown(router.dispose);
      final line = router.walkPath(walkEast(15, jitter: 3));
      expect(line.length, greaterThanOrEqualTo(2));
      expect(router.isBusy, isFalse);
      expect(calls, 0);
    });

    test('bir xil iz qayta so\'ralganda yangi so\'rov yo\'q (kesh)', () async {
      var calls = 0;
      final router = StreetRouter(
        onUpdate: () {},
        walkRequester: (pts) {
          calls++;
          return footway(pts);
        },
      );
      addTearDown(router.dispose);
      final raw = walkEast(200);
      router.walkPath(raw);
      await router.whenIdle();
      final n = calls;
      router.walkPath(raw);
      router.walkPath([...raw]);
      expect(router.isBusy, isFalse);
      expect(calls, n);
    });

    test('bitta nuqta — o\'zi', () {
      final router = StreetRouter(
        onUpdate: () {},
        walkRequester: (_) async => const [],
      );
      addTearDown(router.dispose);
      expect(router.walkPath([tp(0, 0, 0)]), [at(0, 0)]);
    });
  });

  group('buildSpeedTrack samples', () {
    test('piyoda bo\'lak nuqtalari vaqtlari bilan keladi', () {
      final raw = walkEast(120, jitter: 2);
      final walk = buildSpeedTrack(
        raw,
      ).where((p) => p.kind == TrackPieceKind.walk).toList();
      expect(walk, isNotEmpty);
      for (final p in walk) {
        expect(p.samples, hasLength(p.points.length));
        for (var i = 0; i < p.points.length; i++) {
          expect(p.points[i], ll(p.samples[i]));
        }
        expect(p.samples.first.time, p.from);
        expect(p.samples.last.time, p.to);
      }
    });

    test('uzun sakrashda bo\'lingan piyoda bo\'laklar ham samples bilan', () {
      final raw = [
        ...walkEast(60),
        // 50 m sakrash (maxWalkChord dan uzun) — bo'lak bo'linadi.
        for (var s = 0; s <= 60; s++) tp(0, 1.3 * 60 + 50 + 1.3 * s, 61 + s),
      ];
      final walk = buildSpeedTrack(
        raw,
      ).where((p) => p.kind == TrackPieceKind.walk).toList();
      expect(walk.length, greaterThanOrEqualTo(2));
      for (final p in walk) {
        expect(p.samples, hasLength(p.points.length));
        expect(p.samples.first.time, p.from);
        expect(p.samples.last.time, p.to);
      }
    });

    test('withPoints faqat chiziqni almashtiradi', () {
      final piece = buildSpeedTrack(walkEast(60)).first;
      final moved = piece.withPoints([at(4, 0), at(4, 78)]);
      expect(moved.points, [at(4, 0), at(4, 78)]);
      expect(moved.kind, piece.kind);
      expect(moved.from, piece.from);
      expect(moved.to, piece.to);
      expect(moved.samples, piece.samples);
    });
  });
}
