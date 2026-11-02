import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';

void main() {
  final t0 = DateTime(2026, 10, 14, 10);

  TimedPoint p(double lat, double lng, int min) =>
      (lat: lat, lng: lng, time: t0.add(Duration(minutes: min)));

  test('25 m ichida 10+ daqiqa turish bitta to\'xtash bo\'ladi', () {
    final points = [
      p(41.3000, 69.2400, 0),
      p(41.3001, 69.2401, 4), // ~14 m
      p(41.2999, 69.2399, 8),
      p(41.3001, 69.2400, 12),
      // Boshqa joyga ketdi
      p(41.3200, 69.2700, 20),
      p(41.3400, 69.3000, 25),
    ];
    final stops = detectStaffStops(points);
    expect(stops, hasLength(1));
    expect(stops.first.from, t0);
    expect(stops.first.to, t0.add(const Duration(minutes: 12)));
    expect(stops.first.lat, closeTo(41.3, 0.001));
  });

  test('25 m dan chiqib-kirib yursa to\'xtash emas', () {
    final points = [
      p(41.3000, 69.2400, 0),
      p(41.3004, 69.2400, 4), // ~45 m
      p(41.3000, 69.2400, 8),
      p(41.3004, 69.2400, 12),
      p(41.3200, 69.2700, 20),
    ];
    expect(detectStaffStops(points), isEmpty);
  });

  test('qisqa to\'xtash (svetofor) metka bo\'lmaydi', () {
    final points = [
      p(41.3000, 69.2400, 0),
      p(41.3001, 69.2401, 3),
      p(41.3300, 69.2800, 6),
    ];
    expect(detectStaffStops(points), isEmpty);
  });

  test('bir kunda bir nechta to\'xtash', () {
    final points = [
      p(41.3000, 69.2400, 0),
      p(41.3001, 69.2401, 15),
      p(41.3500, 69.3000, 30),
      p(41.3501, 69.3001, 45),
    ];
    final stops = detectStaffStops(points);
    expect(stops, hasLength(2));
    expect(stops[1].from, t0.add(const Duration(minutes: 30)));
  });

  test('backend javobini o\'qiydi, faqat soat berilsa ham', () {
    final stop = StaffStop.fromJson({
      'lat': '41.31',
      'lng': 69.24,
      'boshlanish': '10:24',
      'tugash': '10:42',
      'nom': "Bog'ishamol ko'chasi, 12-uy",
      'rasm_url': '',
    }, day: DateTime(2026, 10, 14));
    expect(stop, isNotNull);
    expect(stop!.duration, const Duration(minutes: 18));
    expect(stop.rasmUrl, isNull);
  });

  group('workWindow', () {
    final day = DateTime(2026, 10, 14);
    final now = DateTime(2026, 10, 14, 15);

    test('keldim bosmagan — GPS ko\'rsatilmaydi', () {
      expect(
        workWindow(checkIn: null, checkOut: null, day: day, now: now),
        isNull,
      );
    });

    test('keldim–ketdim oralig\'i', () {
      final w = workWindow(
        checkIn: '08:57',
        checkOut: '18:00',
        day: day,
        now: now,
      )!;
      expect(w.from, DateTime(2026, 10, 14, 8, 57));
      expect(w.to, DateTime(2026, 10, 14, 18));
    });

    test('sessiya ochiq — hozirgacha', () {
      final w = workWindow(
        checkIn: '08:57',
        checkOut: null,
        day: day,
        now: now,
      )!;
      expect(w.to, now);
    });
  });

  test('isoWithOffset — soniya va offset bilan', () {
    final s = isoWithOffset(DateTime(2026, 10, 14, 9, 30, 5));
    expect(s, startsWith('2026-10-14T09:30:05'));
    expect(RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s), isTrue);
    expect(
      DateTime.parse(s).isAtSameMomentAs(DateTime(2026, 10, 14, 9, 30, 5)),
      isTrue,
    );
  });

  group('dwell', () {
    test('100 m ichida u yoq-bu yoqqa yurish bitta nuqta bo\'ladi', () {
      final pts = [
        p(41.3000, 69.2400, 0),
        // ~50 m atrofida 5 daqiqa aylanadi
        p(41.3004, 69.2402, 1),
        p(41.2997, 69.2398, 2),
        p(41.3003, 69.2404, 3),
        p(41.2998, 69.2399, 4),
        p(41.3001, 69.2401, 5),
        // ketdi
        p(41.3100, 69.2400, 8),
      ];
      final dwells = detectDwells(pts);
      expect(dwells, hasLength(1));
      final path = collapseDwells(pts, dwells);
      // Turish — bitta joy (boshi va oxiri vaqti bilan), keyin ketgan nuqta.
      expect(path, hasLength(3));
      expect(path[0].lat, path[1].lat);
      expect(path[1].time, dwells.single.to);
      expect(path.last.lat, 41.31);
    });

    test('to\'g\'ri sekin yurish yig\'ilmaydi', () {
      // 3 daqiqada 180 m shimolga
      final pts = [
        for (var m = 0; m <= 180; m += 10)
          p(
            41.3 + m / 111320,
            69.24,
            0,
          ).copyWithTime(t0.add(Duration(seconds: m))),
      ];
      expect(detectDwells(pts), isEmpty);
    });
  });

  test('GPS sakrashi turish joyini bo\'lib yubormaydi', () {
    final pts = [
      for (var k = 0; k < 6; k++)
        p(41.3000 + (k.isEven ? 0.0002 : -0.0002), 69.24, k),
      // bitta nuqta 300 m ga sakradi va darhol qaytdi
      p(
        41.3030,
        69.24,
        6,
      ).copyWithTime(t0.add(const Duration(minutes: 6, seconds: 30))),
      for (var k = 7; k < 12; k++)
        p(41.3000 + (k.isEven ? 0.0002 : -0.0002), 69.24, k),
      p(41.3200, 69.24, 20),
    ];
    final dwells = detectDwells(pts);
    expect(dwells, hasLength(1));
    expect(dwells.first.duration, const Duration(minutes: 11));
  });

  group('borib-qaytish turish emas', () {
    // Ko'chaning bir tomonidan 200 m shimolga, burilib (tunel), ikkinchi
    // tomonidan qaytadi — 1,3 m/s, har 3 s da nuqta, ~6 daqiqa.
    final walk = <TimedPoint>[
      for (var s = 0; s <= 160; s += 3)
        (
          lat: 41.3 + 1.3 * s / 111320,
          lng: 69.24,
          time: t0.add(Duration(seconds: s)),
        ),
      for (var s = 0; s <= 160; s += 3)
        (
          lat: 41.3 + 1.3 * (160 - s) / 111320,
          lng: 69.2403,
          time: t0.add(Duration(seconds: 190 + s)),
        ),
    ];

    test('detectDwells va detectStaffStops topmaydi', () {
      expect(detectDwells(walk), isEmpty);
      expect(
        detectStaffStops(walk, minDuration: const Duration(minutes: 5)),
        isEmpty,
      );
      expect(collapseDwells(walk, detectDwells(walk)), hasLength(walk.length));
    });

    test('backend bergan shunday "to\'xtash" harakat deb topiladi', () {
      expect(
        isStationaryBetween(walk, walk.first.time, walk.last.time),
        isFalse,
      );
    });

    test('turishdan chiqib ketish yurishi turishga kirmaydi', () {
      // Ofisda 30 daqiqa (siyrak nuqtalar), keyin har 3 s da sharqqa
      // 1,3 m/s yurib, 100 m dan chiqib ketadi.
      final pts = <TimedPoint>[
        p(41.3000, 69.2400, 0),
        p(41.3001, 69.2401, 15),
        p(41.3000, 69.2400, 30),
        for (var s = 3; s <= 150; s += 3)
          (
            lat: 41.3,
            lng: 69.24 + 1.3 * s / 84000,
            time: t0.add(Duration(minutes: 30, seconds: s)),
          ),
      ];
      final w = detectDwells(pts).single;
      // Yurishning dastlabki ~20 s i hali aniqlanmaydi.
      expect(
        w.to.difference(t0.add(const Duration(minutes: 30))).inSeconds,
        lessThanOrEqualTo(20),
      );
      expect(distanceMeters(w.lat, w.lng, 41.3, 69.24), lessThan(15));
    });

    test('siyrak nuqtali haqiqiy turish — turish', () {
      final pts = [
        p(41.3000, 69.2400, 0),
        p(41.3001, 69.2401, 30), // server titrashni tashlagan
        for (var s = 0; s < 120; s += 3)
          (
            lat: 41.3001 + 1.3 * s / 111320,
            lng: 69.2401,
            time: t0.add(Duration(minutes: 30, seconds: s)),
          ),
      ];
      expect(isStationaryBetween(pts, pts.first.time, pts.last.time), isTrue);
    });
  });

  test('uzoq turib boshqa tomondan chiqsa ham — turish', () {
    final pts = [
      p(41.2994, 69.24, 0), // janubdan kirdi
      for (var k = 1; k < 12; k++) p(41.3000, 69.2400 + k * 0.00001, k),
      p(41.3007, 69.24, 12), // shimoldan chiqdi (~150 m)
      p(41.3200, 69.24, 20),
    ];
    expect(detectDwells(pts), hasLength(1));
  });

  test('cleanTrack: sakrash va titrash tashlanadi', () {
    final pts = [
      p(41.3000, 69.24, 0),
      p(41.30001, 69.24, 1), // ~1 m — titrash
      p(41.3500, 69.24, 2), // 5 km — sakrash
      p(41.3010, 69.24, 3), // ~110 m / 3 daq — normal
    ];
    final out = cleanTrack(pts);
    expect(out, hasLength(2));
    expect(out.last.lat, 41.301);
  });
  test('removeExcursions: sakrab ketib sekin qaytgan iz tashlanadi', () {
    final t0 = DateTime(2026, 10, 31, 9, 13);
    TimedPoint q(double north, double east, int sec) => (
      lat: 40.1333 + north / 111320,
      lng: 67.8227 + east / 85200,
      time: t0.add(Duration(seconds: sec)),
    );
    final pts = [
      q(0, 0, 0),
      q(-95, -217, 12), // 237 m / 12 s — sakrash
      q(-88, -194, 22),
      q(-71, -178, 33),
      q(-37, -110, 61),
      q(-43, -91, 73),
      q(-4, -3, 142), // joyiga qaytdi
      q(-4, 8, 270),
    ];
    final out = removeExcursions(pts);
    expect(out, hasLength(3));
    expect(out.every((p) => p.lng > 67.8226), isTrue);
  });
  test('removeExcursions: sakrashdan keyin yana uzoqlashgan yurish qoladi', () {
    final t0 = DateTime(2026, 10, 29, 12, 56);
    TimedPoint q(double east, int sec) => (
      lat: 40.1333,
      lng: 67.8227 + east / 85200,
      time: t0.add(Duration(seconds: sec)),
    );
    // 130 m / 7 s, keyin 280 m gacha borib, qaytdi.
    final pts = [
      q(0, 0),
      q(130, 7),
      q(200, 60),
      q(280, 120),
      q(150, 200),
      q(5, 270),
    ];
    expect(removeExcursions(pts), hasLength(6));
  });
  test('removeExcursions: qaytmagan tez harakat qoladi', () {
    final t0 = DateTime(2026, 10, 31, 9, 17);
    TimedPoint q(double east, int sec) => (
      lat: 40.1333,
      lng: 67.8227 + east / 85200,
      time: t0.add(Duration(seconds: sec)),
    );
    // Mashinada: 15 m/s bilan ketdi va qaytmadi.
    final pts = [q(0, 0), q(150, 10), q(300, 20), q(450, 30), q(600, 40)];
    expect(removeExcursions(pts), hasLength(5));
  });
  test('removeExcursions: uzilishdan keyin sakrab, tez qaytgan iz '
      '(Sobir, 02.11 08:46–08:51) tashlanadi', () {
    TimedPoint r(double lat, double lng, int min, int sec) =>
        (lat: lat, lng: lng, time: DateTime(2026, 11, 2, 8, min, sec));
    // 08:46:38 dan keyin 3,8 daqiqa nuqta yo'q, 08:50:24 da ~650 m narida
    // paydo bo'ldi (o'rtacha 2,9 m/s — kirish tezlik bilan tutilmaydi),
    // 08:50:52 → 08:50:59 da 283 m / 7 s (40 m/s) bilan qaytdi. Xodim shu
    // orada ofisga qarab ~305 m yurgan.
    final pts = [
      r(40.1335532, 67.8232348, 46, 18),
      r(40.1335648, 67.8232711, 46, 19),
      r(40.1335701, 67.8233102, 46, 20),
      r(40.1335917, 67.8233341, 46, 22),
      r(40.1333022, 67.8227433, 46, 38),
      r(40.1358583, 67.8295767, 50, 24),
      r(40.1358697, 67.8296249, 50, 26),
      r(40.1358898, 67.829689, 50, 28),
      r(40.1358935, 67.8297241, 50, 29),
      r(40.1358964, 67.8297678, 50, 30),
      r(40.1359827, 67.8297978, 50, 31),
      r(40.136384, 67.8299104, 50, 34),
      r(40.1364455, 67.8298866, 50, 35),
      r(40.1364823, 67.8299082, 50, 36),
      r(40.1364283, 67.8298556, 50, 37),
      r(40.1363623, 67.8297907, 50, 38),
      r(40.1363339, 67.8297838, 50, 39),
      r(40.1363271, 67.8298205, 50, 40),
      r(40.1362827, 67.8298304, 50, 42),
      r(40.136245, 67.8298766, 50, 45),
      r(40.1361835, 67.8298526, 50, 46),
      r(40.1359997, 67.8294547, 50, 50),
      r(40.1359409, 67.8290875, 50, 51),
      r(40.1358797, 67.8287721, 50, 52),
      r(40.1347194, 67.8258027, 50, 59),
      r(40.1346676, 67.8257311, 51, 0),
      r(40.1346149, 67.8256061, 51, 1),
      r(40.1345788, 67.8254738, 51, 2),
      r(40.1345494, 67.8253493, 51, 3),
      r(40.1345325, 67.8252752, 51, 4),
      r(40.1345183, 67.8252178, 51, 5),
      r(40.1345026, 67.8251579, 51, 6),
      r(40.1344878, 67.8251027, 51, 7),
      r(40.1344667, 67.8250369, 51, 8),
      r(40.1344304, 67.8249344, 51, 9),
      r(40.1343783, 67.8248147, 51, 10),
      r(40.1343456, 67.8247539, 51, 11),
    ];
    for (final out in [removeExcursions(pts), cleanTrack(pts)]) {
      // 08:50:24–08:50:52 dagi 19 ta soxta nuqtaning birortasi qolmaydi.
      expect(out.any((p) => p.lng > 67.828), isFalse);
      expect(out.any((p) => p.time == DateTime(2026, 11, 2, 8, 46, 38)),
          isTrue);
      expect(out.last, pts.last);
    }
    expect(removeExcursions(pts), hasLength(pts.length - 19));
  });
  test('removeReturnJumps: signal uzilgan mashina harakati qoladi', () {
    final t0 = DateTime(2026, 11, 2, 9);
    TimedPoint q(double east, int sec) => (
      lat: 40.1333,
      lng: 67.8227 + east / 85200,
      time: t0.add(Duration(seconds: sec)),
    );
    // 15 m/s bilan ketyapti, 20 s nuqta yo'q (300 m / 20 s = 15 m/s),
    // keyin 12 s da 420 m (35 m/s) — lekin hech qayerga qaytmagan.
    final pts = [
      q(0, 0),
      q(150, 10),
      q(300, 20),
      q(600, 40),
      q(1020, 52),
      q(1170, 62),
    ];
    expect(removeReturnJumps(pts), hasLength(6));
  });
  test('removeSpikes: borib-qaytgan bitta nuqta tashlanadi', () {
    final pts = [
      p(41.3000, 69.2400, 0),
      p(41.3002, 69.2400, 1),
      p(41.3030, 69.2400, 2), // ~310 m chetga otildi
      p(41.3004, 69.2400, 3), // joyiga qaytdi
      p(41.3006, 69.2400, 4),
    ];
    final out = removeSpikes(pts);
    expect(out, hasLength(4));
    expect(out.any((e) => e.lat == 41.3030), isFalse);
  });

  test('removeSpikes: to\'g\'ri yo\'l o\'zgarmaydi', () {
    final pts = [for (var i = 0; i < 5; i++) p(41.30 + i * 0.001, 69.24, i)];
    expect(removeSpikes(pts), hasLength(5));
  });

  test('splitTrackAtGaps: uzoq uzilish va masofa — yangi bo\'lak', () {
    final pts = [
      p(41.3000, 69.24, 0),
      p(41.3010, 69.24, 1),
      p(41.3200, 69.24, 20), // 19 daqiqa nuqta yo'q, ~2 km
      p(41.3210, 69.24, 21),
    ];
    final segs = splitTrackAtGaps(pts);
    expect(segs, hasLength(2));
    expect(segs.first, hasLength(2));
  });

  test('splitTrackAtGaps: bir joyda uzoq turish uzilish emas', () {
    final pts = [p(41.3000, 69.24, 0), p(41.3001, 69.24, 30)];
    expect(splitTrackAtGaps(pts), hasLength(1));
  });
  test('centerStop: metka turgan joyning o\'rtasiga suriladi', () {
    final pts = [
      for (var i = 0; i < 10; i++) p(41.3000 + (i % 3) * 0.0001, 69.2400, i),
      p(41.3050, 69.2400, 11), // ketdi
    ];
    final st = StaffStop(
      lat: 41.3020, // ~200 m chetda
      lng: 69.2410,
      from: t0,
      to: t0.add(const Duration(minutes: 11)),
    );
    final c = centerStop(st, pts);
    expect(c.lat, closeTo(41.3001, 0.0002));
    expect(c.lng, closeTo(69.24, 0.0001));
    expect(c.from, st.from);
  });
  test('splitTrackAtGaps: 250 m dan uzoq sakrash — punktir', () {
    final t = DateTime(2026, 10, 15, 10);
    final pts = [
      (lat: 41.3000, lng: 69.24, time: t),
      (lat: 41.3040, lng: 69.24, time: t.add(const Duration(seconds: 30))),
    ];
    expect(splitTrackAtGaps(pts), hasLength(2));
  });
  test('splitTrackAtGaps: ikki tomondan uzilgan yakka nuqta tashlanadi', () {
    final pts = [
      p(41.3000, 69.24, 0),
      p(41.3001, 69.24, 1),
      p(41.3100, 69.24, 2), // ~1 km chetda yakka nuqta
      p(41.3002, 69.24, 3),
      p(41.3003, 69.24, 4),
    ];
    final segs = splitTrackAtGaps(pts);
    expect(segs, hasLength(1));
    expect(segs.first, hasLength(4));
  });
  test('splitTrackAtGaps: siyrak piyoda nuqtalar uzluksiz chiziq', () {
    // 2 daqiqada bitta nuqta, ~120 m oraliq — ilgari har biri "yakka nuqta"
    // deb o'chib, qaytish yo'li chizilmay qolardi.
    final pts = [
      for (var i = 0; i < 6; i++) p(41.3000 + i * 0.0011, 69.24, i * 2),
    ];
    final segs = splitTrackAtGaps(pts);
    expect(segs, hasLength(1));
    expect(segs.first, hasLength(6));
  });

  test('unmatchedRawRuns: backend moslamagan nuqtalar chiziladi', () {
    final t = DateTime(2026, 10, 16, 11);
    TimedPoint at(double lat, int min) =>
        (lat: lat, lng: 69.24, time: t.add(Duration(minutes: min)));
    final matched = [
      RouteSegment(
        kind: RouteSegmentKind.road,
        from: t,
        to: t.add(const Duration(minutes: 10)),
        points: const [(lat: 41.30, lng: 69.24), (lat: 41.31, lng: 69.24)],
      ),
      RouteSegment(
        kind: RouteSegmentKind.gap,
        from: t.add(const Duration(minutes: 10)),
        to: t.add(const Duration(minutes: 30)),
        points: const [(lat: 41.31, lng: 69.24), (lat: 41.30, lng: 69.24)],
      ),
    ];
    final raw = [
      at(41.300, 0),
      at(41.310, 10),
      at(41.308, 15), // "uzilish" ichida, lekin real nuqta bor
      at(41.305, 20),
      at(41.302, 40), // backend hali hisoblamagan oxiri
    ];
    final (:runs, :emptyGaps) = unmatchedRawRuns(matched, raw);
    expect(emptyGaps, isEmpty); // punktir chizilmaydi
    expect(runs, hasLength(1));
    // Moslangan bo'lak uchidan boshlanadi, hamma qolgan nuqtalar ichida.
    expect(runs.first.first.lat, 41.31);
    expect(runs.first.map((e) => e.lat), containsAll([41.308, 41.305, 41.302]));
  });

  test('unmatchedRawRuns: nuqtasiz uzilish — punktir', () {
    final t = DateTime(2026, 10, 16, 11);
    final matched = [
      RouteSegment(
        kind: RouteSegmentKind.gap,
        from: t,
        to: t.add(const Duration(minutes: 30)),
        points: const [(lat: 41.31, lng: 69.24), (lat: 41.30, lng: 69.24)],
      ),
    ];
    final (:runs, :emptyGaps) = unmatchedRawRuns(matched, [
      (lat: 41.31, lng: 69.24, time: t),
      (lat: 41.30, lng: 69.24, time: t.add(const Duration(minutes: 30))),
    ]);
    expect(emptyGaps, {0});
    expect(runs, hasLength(1)); // ikki chetdagi real nuqta
  });

  test('needsStreetSnap: yaqin va juda uzoq oraliq moslanmaydi', () {
    expect(
      needsStreetSnap((lat: 41.3, lng: 69.24), (lat: 41.30005, lng: 69.24)),
      isFalse,
    );
    expect(
      needsStreetSnap((lat: 41.3, lng: 69.24), (lat: 41.3008, lng: 69.24)),
      isTrue,
    );
    expect(
      needsStreetSnap((lat: 41.3, lng: 69.24), (lat: 41.36, lng: 69.24)),
      isFalse,
    );
  });

  test('plausibleStreetPath: katta aylanma rad etiladi', () {
    const a = (lat: 41.3000, lng: 69.2400);
    const b = (lat: 41.3009, lng: 69.2400); // ~100 m
    // ~3 km chetga aylanib ketgan yo'l — rad.
    expect(
      plausibleStreetPath(const [a, (lat: 41.3000, lng: 69.2009), b], a, b),
      isFalse,
    );
    expect(
      plausibleStreetPath(const [a, (lat: 41.3000, lng: 69.2008), b], a, b),
      isFalse,
    );
    // Burchakdan aylanib o'tish (~170 m) — qabul.
    expect(
      plausibleStreetPath(const [a, (lat: 41.3000, lng: 69.2407), b], a, b),
      isTrue,
    );
    // Boshqa ko'chaga yopishgan (uchi 100 m chetda).
    expect(
      plausibleStreetPath(
        const [(lat: 41.3000, lng: 69.2412), (lat: 41.3009, lng: 69.2412)],
        a,
        b,
      ),
      isFalse,
    );
  });

  test('plausibleStreetPath: burilib qaytgan ilmoq rad etiladi', () {
    const a = (lat: 41.3000, lng: 69.2400);
    const b = (lat: 41.3009, lng: 69.2400); // ~100 m shimolga
    expect(
      plausibleStreetPath(
        const [
          a,
          (lat: 41.3006, lng: 69.2400),
          (lat: 41.3002, lng: 69.2401), // 45 m orqaga
          b,
        ],
        a,
        b,
      ),
      isFalse,
    );
  });

  test('trimToEnds: uchlardagi ortiqcha qism kesiladi', () {
    const a = (lat: 41.3000, lng: 69.2400);
    const b = (lat: 41.3009, lng: 69.2400);
    final path = trimToEnds(
      const [
        (lat: 41.2997, lng: 69.2400), // a dan oldinroq
        (lat: 41.3000, lng: 69.2400),
        (lat: 41.3005, lng: 69.2400),
        (lat: 41.3009, lng: 69.2400),
        (lat: 41.3012, lng: 69.2400), // b dan nariroq
        (lat: 41.3009, lng: 69.2401),
      ],
      a,
      b,
    );
    expect(path.first, a);
    expect(path.last, b);
    expect(path, hasLength(3));
  });

  test('removeSpurs: chiziqdan borib-qaytgan dumcha olib tashlanadi', () {
    const line = [
      (lat: 41.3000, lng: 69.2400),
      (lat: 41.3005, lng: 69.2400),
      (lat: 41.3005, lng: 69.2397), // ~25 m g'arbga dumcha
      (lat: 41.30051, lng: 69.2400),
      (lat: 41.3010, lng: 69.2400),
    ];
    final out = removeSpurs(line);
    expect(out, hasLength(4));
    expect(out.any((p) => p.lng == 69.2397), isFalse);
  });

  test('nearestOnLines: metka yaqin chiziqqa suriladi, uzoq bo\'lsa yo\'q', () {
    const lines = [
      [(lat: 41.3000, lng: 69.2400), (lat: 41.3010, lng: 69.2400)],
    ];
    // Chiziqdan ~34 m sharqda.
    final q = nearestOnLines((lat: 41.3005, lng: 69.2404), lines);
    expect(q, isNotNull);
    expect(q!.lng, closeTo(69.2400, 1e-9));
    expect(q.lat, closeTo(41.3005, 1e-7));
    // ~170 m chetda — surilmaydi.
    expect(nearestOnLines((lat: 41.3005, lng: 69.2420), lines), isNull);
  });

  test('removeBacktracks: bir necha nuqtali borib-qaytgan dumcha olinadi', () {
    final out = removeBacktracks(const [
      (lat: 41.3000, lng: 69.2400),
      (lat: 41.3005, lng: 69.2400), // T tutashuv
      (lat: 41.3005, lng: 69.2403), // o'ngga ~25 m
      (lat: 41.3005, lng: 69.2406), // ~50 m
      (lat: 41.3005, lng: 69.2403),
      (lat: 41.30051, lng: 69.24001), // qaytdi
      (lat: 41.3010, lng: 69.2400),
    ]);
    expect(out.every((p) => p.lng < 69.2402), isTrue);
    expect(out.last, (lat: 41.3010, lng: 69.2400));
  });

  test('trimEndHooks: uchidagi keskin burilgan qisqa ilgak kesiladi', () {
    final out = trimEndHooks(const [
      (lat: 41.3000, lng: 69.2400),
      (lat: 41.3010, lng: 69.2400),
      (lat: 41.3020, lng: 69.2400),
      (lat: 41.3020, lng: 69.2402), // ~17 m o'ngga ilgak
    ]);
    expect(out.last, (lat: 41.3020, lng: 69.2400));
    // Uzun burilish (haqiqiy yo'l) saqlanadi.
    final keep = trimEndHooks(const [
      (lat: 41.3000, lng: 69.2400),
      (lat: 41.3020, lng: 69.2400),
      (lat: 41.3020, lng: 69.2420),
    ]);
    expect(keep.length, 3);
  });

  test('clipOutsideCircles: zona ichidagi qism chizilmaydi', () {
    const zone = (lat: 41.3010, lng: 69.2400, radius: 50.0);
    final out = clipOutsideCircles(
      const [
        [(lat: 41.3000, lng: 69.2400), (lat: 41.3020, lng: 69.2400)],
        [(lat: 41.3009, lng: 69.2400), (lat: 41.3011, lng: 69.2400)],
      ],
      const [zone],
    );
    expect(out.length, 2);
    for (final l in out) {
      for (final p in l) {
        expect(
          distanceMeters(p.lat, p.lng, zone.lat, zone.lng),
          greaterThanOrEqualTo(49.9),
        );
      }
    }
  });

  test('dropEndConnectors: bino ichiga tortilgan ulovchi tashlanadi', () {
    const a = (lat: 41.3000, lng: 69.2400);
    const b = (lat: 41.3010, lng: 69.2405);
    final out = dropEndConnectors(
      const [a, (lat: 41.3010, lng: 69.2400), b],
      a,
      b,
    );
    expect(out.last, (lat: 41.3010, lng: 69.2400));
  });

  test(
    'roadFallbackPath: kvartal atrofidan aylanish qabul, km aylanma rad',
    () {
      const a = (lat: 41.3000, lng: 69.2400);
      const b = (lat: 41.3004, lng: 69.2400);
      const around = [
        a,
        (lat: 41.3000, lng: 69.2403),
        (lat: 41.3004, lng: 69.2403),
        b,
      ];
      expect(roadFallbackPath(around, a, b), isTrue);
      expect(
        roadFallbackPath(const [a, (lat: 41.3000, lng: 69.2009), b], a, b),
        isFalse,
      );
    },
  );

  group('liveStops', () {
    final t0 = DateTime(2026, 10, 16, 10);
    // 15 daqiqa bir joyda (±20 m), har 30 soniyada nuqta.
    List<TimedPoint> stay(DateTime from, int minutes, double lat) => [
      for (var k = 0; k <= minutes * 2; k++)
        (
          lat: lat + (k.isEven ? 0.0001 : -0.0001),
          lng: 69.24,
          time: from.add(Duration(seconds: 30 * k)),
        ),
    ];

    test('hali shu yerda — ongoing, raqamli ro\'yxatda yo\'q', () {
      final route = stay(t0, 15, 41.30);
      final r = liveStops(const [], route, t0.add(const Duration(minutes: 16)));
      expect(r.ongoing, isNotNull);
      expect(r.ongoing!.from, t0);
      expect(r.stops, isEmpty);
    });

    test('ketgandan keyin — oddiy to\'xtash, yakuniy vaqti bilan', () {
      final route = [
        ...stay(t0, 15, 41.30),
        for (var k = 1; k <= 10; k++)
          (
            lat: 41.30 + k * 0.001,
            lng: 69.24,
            time: t0.add(Duration(minutes: 15, seconds: 30 * k)),
          ),
      ];
      final r = liveStops(const [], route, t0.add(const Duration(minutes: 21)));
      expect(r.ongoing, isNull);
      expect(r.stops.length, 1);
      expect(r.stops.single.duration, const Duration(minutes: 15));
    });

    test('10 daqiqadan kam — hech narsa; boshqa kun — ongoing yo\'q', () {
      final short = stay(t0, 5, 41.30);
      expect(
        liveStops(const [], short, t0.add(const Duration(minutes: 6))).ongoing,
        isNull,
      );
      final long = stay(t0, 15, 41.30);
      final r = liveStops(
        const [],
        long,
        t0.add(const Duration(minutes: 16)),
        today: false,
      );
      expect(r.ongoing, isNull);
      expect(r.stops.length, 1);
    });
  });

  test(
    'simplifyExcursions: yo\'l bo\'ylab zigzag to\'g\'rilanadi, burchak qoladi',
    () {
      final t = DateTime(2026, 10, 16, 10);
      TimedPoint p(double lat, double lng, int s) =>
          (lat: lat, lng: lng, time: t.add(Duration(seconds: s)));
      // Shimolga 300 m, o'rtada g'arbga ~45 m sakrab qaytgan.
      final zig = [
        p(41.3000, 69.2400, 0),
        p(41.3008, 69.2400, 60),
        p(41.3010, 69.23946, 80),
        p(41.3014, 69.23946, 110),
        p(41.3016, 69.2400, 130),
        p(41.3027, 69.2400, 200),
      ];
      final out = simplifyExcursions(zig);
      expect(out.length, 2);
      // 60 m lik burchak (L shakl) — bino ma'lumoti yo'q, saqlanadi.
      final corner = [
        p(41.3000, 69.2400, 0),
        p(41.30054, 69.2400, 60),
        p(41.30054, 69.24072, 120),
      ];
      expect(simplifyExcursions(corner).length, 3);
      // To'g'ri chiziq bino ustidan o'tsa — zigzag ham qoladi.
      expect(
        simplifyExcursions(zig, clean: (a, b) => false).length,
        zig.length,
      );
    },
  );

  test(
    'removeStubLines: asosiy chiziqqa tegib turgan qisqa chiziq olinadi',
    () {
      const main = [(lat: 41.3000, lng: 69.2400), (lat: 41.3020, lng: 69.2400)];
      const stub = [
        (lat: 41.3010, lng: 69.24001),
        (lat: 41.3010, lng: 69.2404),
      ];
      const far = [(lat: 41.3100, lng: 69.2500), (lat: 41.3101, lng: 69.2500)];
      final out = removeStubLines(const [main, stub, far]);
      expect(out, const [main, far]);
    },
  );

  test('joinTouchingLines: turish nuqtasidagi dumcha ham olinadi', () {
    final lines = joinTouchingLines(const [
      [
        (lat: 41.3000, lng: 69.2400),
        (lat: 41.3005, lng: 69.2400),
        (lat: 41.3005, lng: 69.2397), // turish nuqtasi (dumcha uchi)
      ],
      [
        (lat: 41.3005, lng: 69.2397),
        (lat: 41.30051, lng: 69.2400),
        (lat: 41.3010, lng: 69.2400),
      ],
    ]);
    expect(lines, hasLength(1));
    final out = removeSpurs(lines.single);
    expect(out.any((p) => p.lng == 69.2397), isFalse);
    // Metka endi asosiy chiziqqa suriladi.
    final pin = nearestOnLines((lat: 41.3005, lng: 69.2397), [out]);
    expect(pin!.lng, closeTo(69.2400, 1e-6));
  });

  test('looksLikeDriving: tezlik bo\'yicha', () {
    final t = DateTime(2026, 10, 16, 11);
    final a = (lat: 41.3, lng: 69.24, time: t);
    final walk = (
      lat: 41.3009,
      lng: 69.24,
      time: t.add(const Duration(minutes: 1)),
    );
    final car = (
      lat: 41.3009,
      lng: 69.24,
      time: t.add(const Duration(seconds: 10)),
    );
    expect(looksLikeDriving(a, walk), isFalse);
    expect(looksLikeDriving(a, car), isTrue);
  });

  test('parseMatchedRoute: bo\'laklar o\'qiladi, buzuqlari tashlanadi', () {
    final segs = parseMatchedRoute({
      'bolaklar': [
        {
          'tur': 'uzilish',
          'boshlanish': '2026-10-15T11:00:00+05:00',
          'tugash': '2026-10-15T11:40:00+05:00',
          'nuqtalar': [
            [41.32, 69.25],
            [41.30, 69.24],
          ],
        },
        {
          'tur': 'yol',
          'rejim': 'avto',
          'boshlanish': '2026-10-15T09:00:00+05:00',
          'tugash': '2026-10-15T09:30:00+05:00',
          'nuqtalar': [
            [41.31, 69.27],
            {'lat': 41.312, 'lng': 69.28},
          ],
        },
        {'tur': 'nomalum', 'boshlanish': '09:00', 'tugash': '10:00'},
        {
          'tur': 'real',
          'boshlanish': '10:00',
          'tugash': '10:05',
          'nuqtalar': [
            [41.31, 69.27],
          ],
        },
      ],
    }, day: DateTime(2026, 10, 15));
    expect(segs, hasLength(2));
    expect(segs!.first.kind, RouteSegmentKind.road);
    expect(segs.first.mode, 'avto');
    expect(segs.first.points.last.lng, 69.28);
    expect(segs.last.kind, RouteSegmentKind.gap);
    expect(parseMatchedRoute({'success': true}), isNull);
  });

  test('parseMatchedRouteFull: server rejimi versiya yoki yol bo\'lagidan', () {
    Map<String, dynamic> seg(String tur) => {
      'tur': tur,
      'boshlanish': '2026-10-15T09:00:00+05:00',
      'tugash': '2026-10-15T09:10:00+05:00',
      'nuqtalar': [
        [41.31, 69.27],
        [41.312, 69.28],
      ],
    };
    // Hozirgi backend (OSRM sozlanmagan): faqat `real` — telefon rejimi.
    final old = parseMatchedRouteFull({
      'bolaklar': [seg('real')],
    })!;
    expect(old.serverAuthoritative, isFalse);
    expect(old.versiya, isNull);

    // OSRM ishlayapti — `yol` bo'lagi bor.
    expect(
      parseMatchedRouteFull({
        'bolaklar': [seg('real'), seg('yol')],
      })!.serverAuthoritative,
      isTrue,
    );

    // Yangi algoritm `versiya` yuboradi (hamma bo'lak `real` bo'lsa ham).
    final v = parseMatchedRouteFull({
      'versiya': '3',
      'hisoblangan_vaqt': '2026-10-20T15:40:00+05:00',
      'bolaklar': [seg('real')],
    })!;
    expect(v.serverAuthoritative, isTrue);
    expect(v.versiya, 3);
    expect(v.hisoblanganVaqt, '2026-10-20T15:40:00+05:00');

    // Backend hozir `hisoblangan_at` nomi bilan yuboradi.
    expect(
      parseMatchedRouteFull({
        'hisoblangan_at': '2026-10-23T18:00:10+05:00',
        'bolaklar': [seg('real')],
      })!.hisoblanganVaqt,
      '2026-10-23T18:00:10+05:00',
    );
    expect(parseMatchedRouteFull({'success': true}), isNull);
  });
  group('dropShortZoneExits', () {
    final t0 = DateTime(2026, 11, 2, 8, 46);
    ZonedPoint z(int sec, bool? inside) => (
      lat: 40.0,
      lng: 67.0,
      time: t0.add(Duration(seconds: sec)),
      inside: inside,
    );
    List<int> secs(List<ZonedPoint> ps) => [
      for (final p in ps) p.time.difference(t0).inSeconds,
    ];

    test('46 soniyalik chiqib-kirish (Sobir, 08:50) tashlanadi', () {
      final out = dropShortZoneExits([
        z(0, true),
        z(264, false),
        z(290, false),
        z(310, false),
        z(311, true),
      ]);
      expect(secs(out), [0, 311]);
    });

    test('uzoq yurish (50 daqiqa) qoladi', () {
      final out = dropShortZoneExits([
        z(0, true),
        z(60, false),
        z(3060, false),
        z(3070, true),
      ]);
      expect(secs(out), [0, 60, 3060, 3070]);
    });

    test('qaytmagan yoki noma\'lum chiqishga tegilmaydi', () {
      expect(
        secs(dropShortZoneExits([z(0, true), z(10, false), z(20, false)])),
        [0, 10, 20],
      );
      expect(
        secs(dropShortZoneExits([z(0, false), z(10, false), z(20, true)])),
        [0, 10, 20],
      );
      expect(
        secs(dropShortZoneExits([z(0, true), z(10, false), z(20, null)])),
        [0, 10, 20],
      );
    });
  });

  group('timeInZone', () {
    final start = DateTime(2026, 10, 15, 9);
    ZoneSample out(int min, [int sec = 0]) =>
        (time: start.add(Duration(minutes: min, seconds: sec)), outside: true);

    test('tashqarida yurilgan vaqt ayiriladi, ichkarida davom etadi', () {
      // 10:00–10:30 tashqarida (har 20 s nuqta), keyin qaytdi.
      final samples = [for (var s = 0; s <= 30 * 60; s += 20) out(60, s)];
      final d = timeInZone(
        start: start,
        end: start.add(const Duration(hours: 3)),
        samples: samples,
      );
      expect(d, const Duration(hours: 2, minutes: 30));
    });

    test('hozir tashqarida — soat to\'xtagan', () {
      final now = start.add(const Duration(hours: 2));
      final samples = [for (var s = 0; s <= 600; s += 5) out(110, s)];
      // 10:50 da chiqdi, oxirgi nuqta 11:00, hozir 11:00.
      final d = timeInZone(
        start: start,
        end: now,
        samples: samples,
        outsideNow: true,
      );
      expect(d, const Duration(hours: 1, minutes: 50));
    });

    test('uzoq uzilish — ikki alohida chiqish', () {
      final samples = [out(10), out(11), out(40), out(41)];
      final d = timeInZone(
        start: start,
        end: start.add(const Duration(hours: 1)),
        samples: samples,
      );
      expect(d, const Duration(minutes: 58));
    });

    test('keldimdan oldingi nuqtalar hisobga olinmaydi', () {
      final samples = [out(-30), out(-29), out(-28)];
      expect(
        timeInZone(
          start: start,
          end: start.add(const Duration(hours: 1)),
          samples: samples,
        ),
        const Duration(hours: 1),
      );
    });
  });
}

extension on TimedPoint {
  TimedPoint copyWithTime(DateTime t) => (lat: lat, lng: lng, time: t);
}
