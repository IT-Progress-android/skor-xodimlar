import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/features/rahbar/data/speed_track.dart';
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';

/// Shimolga [speed] m/s bilan har soniyada bitta nuqta.
List<TimedPoint> _line(
  DateTime start,
  int seconds,
  double speed, {
  double lat0 = 40.1,
  double lng = 67.84,
}) {
  const mPerDegLat = 111320.0;
  return [
    for (var s = 0; s <= seconds; s++)
      (
        lat: lat0 + speed * s / mPerDegLat,
        lng: lng,
        time: start.add(Duration(seconds: s)),
      ),
  ];
}

List<TrackPieceKind> _kinds(List<TrackPiece> p) => [for (final x in p) x.kind];

void main() {
  final t0 = DateTime(2026, 10, 27, 10);

  test('piyoda — haqiqiy nuqtalar, bitta bo\'lak', () {
    final pts = _line(t0, 300, 1.4);
    final r = buildSpeedTrack(pts);
    expect(_kinds(r), [TrackPieceKind.walk]);
    expect(r.single.points, hasLength(pts.length));
  });

  test('piyoda → mashina → piyoda', () {
    final walk1 = _line(t0, 120, 1.3);
    final drive = _line(
      walk1.last.time.add(const Duration(seconds: 1)),
      180,
      12,
      lat0: walk1.last.lat,
    );
    final walk2 = _line(
      drive.last.time.add(const Duration(seconds: 1)),
      120,
      1.3,
      lat0: drive.last.lat,
    );
    final r = buildSpeedTrack([...walk1, ...drive, ...walk2]);
    expect(_kinds(r), [
      TrackPieceKind.walk,
      TrackPieceKind.vehicle,
      TrackPieceKind.walk,
    ]);
    // Bo'laklar uzilmaydi.
    expect(r[0].points.last, r[1].points.first);
    expect(r[1].points.last, r[2].points.first);
  });

  test('svetoforda 30 s turish mashina qismini bo\'lmaydi', () {
    final d1 = _line(t0, 120, 12);
    final stop = _line(
      d1.last.time.add(const Duration(seconds: 1)),
      30,
      0.3,
      lat0: d1.last.lat,
    );
    final d2 = _line(
      stop.last.time.add(const Duration(seconds: 1)),
      120,
      12,
      lat0: stop.last.lat,
    );
    final r = buildSpeedTrack([...d1, ...stop, ...d2]);
    expect(_kinds(r), [TrackPieceKind.vehicle]);
  });

  test('shahar ichida svetoforlar bilan safar — bitta mashina bo\'lagi', () {
    // 25 s 15 m/s, 60 s turish, 20 s 14 m/s, 90 s turish, 30 s 15 m/s.
    final pts = <TimedPoint>[];
    var t = t0;
    var lat = 40.1;
    void go(int sec, double speed) {
      for (var s = 0; s < sec; s++) {
        pts.add((lat: lat, lng: 67.84, time: t));
        t = t.add(const Duration(seconds: 1));
        lat += speed / 111320;
      }
    }

    go(120, 1.3); // piyoda mashinaga borgan
    go(25, 15);
    go(60, 0);
    go(20, 14);
    go(90, 0);
    go(30, 15);
    go(120, 1.3); // tushib yurdi
    final r = buildSpeedTrack(pts);
    expect(_kinds(r), [
      TrackPieceKind.walk,
      TrackPieceKind.vehicle,
      TrackPieceKind.walk,
    ]);
  });

  test('qisqa tezlashish (yugurib o\'tish) mashina emas', () {
    final a = _line(t0, 120, 1.3);
    final run = _line(
      a.last.time.add(const Duration(seconds: 1)),
      15,
      6,
      lat0: a.last.lat,
    );
    final b = _line(
      run.last.time.add(const Duration(seconds: 1)),
      120,
      1.3,
      lat0: run.last.lat,
    );
    final r = buildSpeedTrack([...a, ...run, ...b]);
    expect(_kinds(r), [TrackPieceKind.walk]);
  });

  test('mashina qismi uchun backend yo\'li bo\'lsa — o\'sha chiziladi', () {
    final drive = _line(t0, 180, 12);
    final road = RouteSegment(
      kind: RouteSegmentKind.road,
      from: t0,
      to: drive.last.time,
      points: const [
        (lat: 40.1, lng: 67.8401),
        (lat: 40.105, lng: 67.8402),
        (lat: 40.1194, lng: 67.8401),
      ],
    );
    final r = buildSpeedTrack(drive, matched: [road]);
    expect(_kinds(r), [TrackPieceKind.vehicle]);
    expect(r.single.points, contains((lat: 40.105, lng: 67.8402)));
  });

  test('piyoda qismiga backend yo\'li ishlatilmaydi', () {
    final walk = _line(t0, 300, 1.3);
    final road = RouteSegment(
      kind: RouteSegmentKind.road,
      from: t0,
      to: walk.last.time,
      points: const [(lat: 41.0, lng: 69.0), (lat: 41.1, lng: 69.1)],
    );
    final r = buildSpeedTrack(walk, matched: [road]);
    expect(r.single.kind, TrackPieceKind.walk);
    expect(r.single.points, isNot(contains((lat: 41.0, lng: 69.0))));
  });

  test('qisqa bo\'shliq — punktir, uzuni — ulanmaydi', () {
    final a = _line(t0, 60, 1.3);
    final b = _line(
      a.last.time.add(const Duration(minutes: 3)),
      60,
      1.3,
      lat0: a.last.lat + 0.0004, // ~45 m
    );
    final c = _line(
      b.last.time.add(const Duration(minutes: 20)),
      60,
      1.3,
      lat0: b.last.lat + 0.02, // ~2,2 km
    );
    final r = buildSpeedTrack([...a, ...b, ...c]);
    expect(_kinds(r), [
      TrackPieceKind.walk,
      TrackPieceKind.gap,
      TrackPieceKind.walk,
      TrackPieceKind.missing,
      TrackPieceKind.walk,
    ]);
  });

  test('bo\'shliqda backend yo\'li bo\'lsa — transport bo\'lib chiziladi', () {
    final a = _line(t0, 60, 1.3);
    final gapStart = a.last.time;
    final b = _line(
      gapStart.add(const Duration(minutes: 8)),
      60,
      1.3,
      lat0: a.last.lat + 0.03,
    );
    final road = RouteSegment(
      kind: RouteSegmentKind.road,
      from: gapStart.add(const Duration(seconds: 20)),
      to: b.first.time.subtract(const Duration(seconds: 20)),
      points: [
        (lat: a.last.lat, lng: 67.8401),
        (lat: b.first.lat, lng: 67.8401),
      ],
    );
    final r = buildSpeedTrack([...a, ...b], matched: [road]);
    expect(_kinds(r), [
      TrackPieceKind.walk,
      TrackPieceKind.vehicle,
      TrackPieceKind.walk,
    ]);
  });

  test('ikki uchi ofisda bo\'lgan bo\'shliq ko\'rsatilmaydi', () {
    final a = _line(t0, 30, 1.3);
    final b = _line(
      a.last.time.add(const Duration(hours: 2)),
      30,
      1.3,
      lat0: a.last.lat + 0.0005,
    );
    final r = buildSpeedTrack([...a, ...b], inOffice: (_) => true);
    expect(_kinds(r), [TrackPieceKind.walk, TrackPieceKind.walk]);
  });

  test('siyrak piyoda nuqtalari binolarni kesib ulanmaydi', () {
    // Har 40 s da 80 m — orasida qayerdan yurgani noma'lum.
    final pts = [
      for (var i = 0; i < 4; i++)
        (
          lat: 40.1 + i * 80 / 111320,
          lng: 67.84,
          time: t0.add(Duration(seconds: 40 * i)),
        ),
    ];
    final r = buildSpeedTrack(pts);
    expect(r.where((p) => p.kind == TrackPieceKind.walk), isEmpty);
    expect(r.every((p) => p.kind == TrackPieceKind.missing), isTrue);
  });

  test('imkonsiz sakrash (eskirgan nuqta) tashlanadi', () {
    final a = _line(t0, 60, 1.3);
    final fake = (
      lat: a.last.lat + 0.01, // ~1,1 km, 5 s da
      lng: 67.84,
      time: a.last.time.add(const Duration(seconds: 5)),
    );
    final b = _line(
      a.last.time.add(const Duration(seconds: 6)),
      60,
      1.3,
      lat0: a.last.lat,
    );
    final r = buildSpeedTrack([...a, fake, ...b]);
    expect(_kinds(r), [TrackPieceKind.walk]);
  });

  test('vaqt bo\'yicha takror nuqta tashlanadi', () {
    final pts = _line(t0, 60, 1.3);
    final r = buildSpeedTrack([...pts, pts.last]);
    expect(r.single.points, hasLength(pts.length));
  });

  group('dropIsolatedStubs', () {
    TrackPiece piece(TrackPieceKind kind, double north) => TrackPiece(
      kind,
      [(lat: 40.1, lng: 67.84), (lat: 40.1 + north / 111320, lng: 67.84)],
      t0,
      t0.add(const Duration(minutes: 1)),
    );

    test("ikki tomoni uzilgan qisqa piyoda bo'lak tashlanadi", () {
      final out = dropIsolatedStubs([
        piece(TrackPieceKind.walk, 200),
        piece(TrackPieceKind.missing, 300),
        piece(TrackPieceKind.walk, 30),
        piece(TrackPieceKind.missing, 300),
        piece(TrackPieceKind.walk, 200),
      ]);
      expect(_kinds(out), [
        TrackPieceKind.walk,
        TrackPieceKind.missing,
        TrackPieceKind.missing,
        TrackPieceKind.walk,
      ]);
    });

    test('punktir yoki mashina bilan ulangan qisqa bo\'lak qoladi', () {
      final out = dropIsolatedStubs([
        piece(TrackPieceKind.missing, 300),
        piece(TrackPieceKind.walk, 30),
        piece(TrackPieceKind.gap, 40),
        piece(TrackPieceKind.vehicle, 500),
      ]);
      expect(out, hasLength(4));
    });

    test("yolg'iz, lekin uzun bo'lak qoladi", () {
      expect(
        dropIsolatedStubs([piece(TrackPieceKind.walk, 150)]),
        hasLength(1),
      );
      expect(dropIsolatedStubs([piece(TrackPieceKind.walk, 80)]), isEmpty);
    });

    test("ikki sakrash orasidagi qisqa zanjir butunlay tashlanadi "
        "(Javohir, 30.10 17:49)", () {
      final out = dropIsolatedStubs([
        piece(TrackPieceKind.walk, 400),
        piece(TrackPieceKind.missing, 206),
        piece(TrackPieceKind.vehicle, 29),
        piece(TrackPieceKind.walk, 32),
        piece(TrackPieceKind.missing, 287),
        piece(TrackPieceKind.walk, 260),
      ]);
      expect(_kinds(out), [
        TrackPieceKind.walk,
        TrackPieceKind.missing,
        TrackPieceKind.missing,
        TrackPieceKind.walk,
      ]);
    });
  });
}
