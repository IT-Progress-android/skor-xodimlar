import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skore_hodimlar/core/services/gps_fix_filter.dart';

final _t0 = DateTime(2026, 10, 15, 10);

/// [northM] metr shimolga, [sec] soniyada, aniqlik va Doppler tezligi bilan.
Position _fix(double northM, int sec, {double acc = 5, double speed = 1.4}) =>
    Position(
      latitude: 41.3 + northM / 111320,
      longitude: 69.24,
      timestamp: _t0.add(Duration(seconds: sec)),
      accuracy: acc,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );

void main() {
  test('turgan joy — hamma o\'lchovlarning aniq o\'rtachasi', () {
    // Bino ichida: kelgandagi birinchi o'lchov 20 m chetda, keyingilari
    // haqiqiy joy (0 m) atrofida ±8 m sochilgan, aniqlik 20 m — hammasi
    // drift doirasida, filtr ularni tashlaydi.
    final f = GpsFixFilter()..accept(_fix(20, 0, acc: 25, speed: 0));
    expect(f.standing!.lat, closeTo(41.3 + 20 / 111320, 1e-9));
    for (var s = 1; s <= 30; s++) {
      expect(f.accept(_fix(s.isEven ? 8 : -8, s, acc: 20, speed: 0)), isNull);
    }
    // Heartbeat endi birinchi o'lchovni emas, o'rtachani yuboradi.
    final north = (f.standing!.lat - 41.3) * 111320;
    expect(north.abs(), lessThan(1.5));
    expect(f.last!.lat, closeTo(41.3 + 20 / 111320, 1e-9));
  });

  test('aniqligi 50 m dan yomon o\'lchov tashlanadi', () {
    final f = GpsFixFilter();
    expect(f.accept(_fix(0, 0, acc: 80)), isNull);
    expect(f.accept(_fix(0, 1, acc: 8)), isNotNull);
  });

  test('bir joyda turganda titrash yuborilmaydi', () {
    final f = GpsFixFilter()..accept(_fix(0, 0, speed: 0));
    var accepted = 0;
    for (var s = 1; s <= 30; s++) {
      // ±6 m atrofida, Doppler 0
      if (f.accept(_fix(s.isEven ? 6 : -6, s, speed: 0)) != null) accepted++;
    }
    expect(accepted, 0);
  });

  test('yurganda har soniyalik nuqtalar qabul qilinadi', () {
    final f = GpsFixFilter()..accept(_fix(0, 0));
    var accepted = 0;
    for (var s = 1; s <= 20; s++) {
      if (f.accept(_fix(s * 1.5 * 3, s, speed: 4.5)) != null) accepted++;
    }
    // Birinchi 1 ta Doppler tasdig'ini kutadi, qolganlari o'tadi.
    expect(accepted, greaterThanOrEqualTo(18));
  });

  test('imkonsiz sakrash (GPS xatosi) tashlanadi', () {
    final f = GpsFixFilter()
      ..accept(_fix(0, 0, speed: 10))
      ..accept(_fix(10, 1, speed: 10))
      ..accept(_fix(20, 2, speed: 10));
    // 1 soniyada 500 m
    expect(f.accept(_fix(520, 3, speed: 10)), isNull);
    expect(f.accept(_fix(30, 4, speed: 10)), isNotNull);
  });

  test('bitta Dopplersiz sakrash izni ochmaydi, 3 tasi ketma-ket — ochadi', () {
    final f = GpsFixFilter()..accept(_fix(0, 0, speed: 0));
    expect(f.accept(_fix(40, 1, speed: 0)), isNull);
    expect(f.accept(_fix(45, 2, speed: 0)), isNull);
    expect(f.accept(_fix(50, 3, speed: 0)), isNotNull);
  });
}
