import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';

Position _pos(double lat, DateTime at) => Position(
  latitude: lat,
  longitude: 69.24,
  timestamp: at,
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  group('paket nuqtasi tekshiruvi', paketPointTests);

  final t0 = DateTime(2026, 10, 14, 10);

  test('birinchi nuqta darhol yuboriladi', () {
    expect(
      shouldSendOutsidePing(lastTime: null, lastPos: null, pos: _pos(41.3, t0)),
      isTrue,
    );
  });

  test('har soniyada yangi o\'lchov yuboriladi', () {
    expect(
      shouldSendOutsidePing(
        lastTime: t0,
        lastPos: _pos(41.3, t0),
        pos: _pos(41.3001, t0.add(const Duration(seconds: 1))),
        now: t0.add(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  test('1 soniya o\'tmagan bo\'lsa kutadi', () {
    expect(
      shouldSendOutsidePing(
        lastTime: t0,
        lastPos: _pos(41.3, t0),
        pos: _pos(41.3001, t0.add(const Duration(milliseconds: 400))),
        now: t0.add(const Duration(milliseconds: 400)),
      ),
      isFalse,
    );
  });

  test('o\'sha eski o\'lchov qayta yuborilmaydi', () {
    final p = _pos(41.3, t0);
    expect(
      shouldSendOutsidePing(
        lastTime: t0,
        lastPos: p,
        pos: _pos(41.3, t0),
        now: t0.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
  });

  test('tezlik 1 xona aniqlikda, noma\'lum tezlik null', () {
    expect(gpsSpeedForServer(1.44), 1.4);
    expect(gpsSpeedForServer(1.46), 1.5);
    expect(gpsSpeedForServer(0), 0);
    expect(gpsSpeedForServer(-1), isNull);
    expect(gpsSpeedForServer(double.nan), isNull);
  });

  test('401 va vaqtincha xatolarda nuqta navbatda qoladi', () {
    for (final c in [401, 408, 429, 500, 503]) {
      expect(isRetryableGpsStatus(c), isTrue, reason: '$c');
    }
    for (final c in [200, 201, 400, 404, 422]) {
      expect(isRetryableGpsStatus(c), isFalse, reason: '$c');
    }
  });
}

void paketPointTests() {
  Map<String, dynamic> p({
    Object? lat = 41.3,
    Object? lng = 69.24,
    Object? at,
  }) => {
    'lat': lat,
    'lng': lng,
    'recorded_at': at ?? '2026-10-24T11:35:00.123',
  };

  test('to\'g\'ri nuqta paketga qo\'shiladi', () {
    expect(isValidGpsPaketPoint(p()), isTrue);
  });

  test('lat/lng oralig\'idan tashqari nuqta tashlanadi', () {
    expect(isValidGpsPaketPoint(p(lat: 91.0)), isFalse);
    expect(isValidGpsPaketPoint(p(lng: -181.0)), isFalse);
    expect(isValidGpsPaketPoint(p(lat: double.nan)), isFalse);
    expect(isValidGpsPaketPoint(p(lat: null)), isFalse);
  });

  test('recorded_at yo\'q yoki buzuq nuqta tashlanadi', () {
    expect(isValidGpsPaketPoint({'lat': 41.3, 'lng': 69.24}), isFalse);
    expect(isValidGpsPaketPoint(p(at: 'kecha')), isFalse);
  });
}
