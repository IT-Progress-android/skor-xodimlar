import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/features/rahbar/data/live_playback.dart';
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';

TimedPoint _p(DateTime t, double lat) => (lat: lat, lng: 67.84, time: t);

void main() {
  // Telefon soati rahbarnikidan 3 daqiqa orqada — natijaga ta'sir qilmaydi.
  final phone0 = DateTime(2026, 10, 27, 10);
  final now0 = phone0.add(const Duration(minutes: 3));

  test('paket ichidagi nuqtalar real tezlikda, kechikish bilan o\'ynaladi', () {
    final pb = LivePlayback(buffer: const Duration(seconds: 10));
    pb.push(
      1,
      [
        for (var s = 0; s <= 10; s++)
          _p(phone0.add(Duration(seconds: s)), 40.0 + s * 0.0001),
      ],
      source: 'tail',
      now: now0,
    );
    // Boshlanishda — paketning boshi (oxiridan 10 s orqada).
    expect(pb.position(1, now0)!.lat, closeTo(40.0, 1e-9));
    // 5,5 s o'tib — 5 va 6-soniyalar orasida.
    final mid = pb.position(1, now0.add(const Duration(milliseconds: 5500)))!;
    expect(mid.lat, closeTo(40.00055, 1e-9));
    expect(pb.isMoving(1, now0.add(const Duration(seconds: 5))), isTrue);
    // Paket tugadi — oxirgi joyda kutadi.
    final end = pb.position(1, now0.add(const Duration(seconds: 30)))!;
    expect(end.lat, closeTo(40.001, 1e-9));
    expect(pb.isMoving(1, now0.add(const Duration(seconds: 30))), isFalse);
  });

  test('kutib turgan marker keyingi paketda sakramasdan davom etadi', () {
    final pb = LivePlayback(buffer: const Duration(seconds: 10));
    pb.push(
      1,
      [_p(phone0, 40.0), _p(phone0.add(const Duration(seconds: 10)), 40.001)],
      source: 'tail',
      now: now0,
    );
    // 15 s kutildi (paket kechikdi) — marker oxirgi joyda.
    final later = now0.add(const Duration(seconds: 25));
    expect(pb.position(1, later)!.lat, closeTo(40.001, 1e-9));
    pb.push(
      1,
      [_p(phone0.add(const Duration(seconds: 20)), 40.002)],
      source: 'tail',
      now: later,
    );
    // Yangi paket kelgan zahoti — hali ham o'sha joyda (sakrash yo'q)...
    expect(pb.position(1, later)!.lat, closeTo(40.001, 1e-9));
    // ...va 5 s da yarim yo'lda.
    expect(
      pb.position(1, later.add(const Duration(seconds: 5)))!.lat,
      closeTo(40.0015, 1e-9),
    );
  });

  test('juda kechikkan bo\'lsa yangi joyga o\'tadi', () {
    final pb = LivePlayback(
      buffer: const Duration(seconds: 10),
      maxLag: const Duration(seconds: 40),
    );
    pb.push(1, [_p(phone0, 40.0)], source: 'live', now: now0);
    pb.push(
      1,
      [_p(phone0.add(const Duration(minutes: 5)), 40.01)],
      source: 'live',
      now: now0.add(const Duration(seconds: 10)),
    );
    final pos = pb.position(1, now0.add(const Duration(seconds: 20)))!;
    expect(pos.lat, closeTo(40.01, 1e-9));
  });

  test('manba almashsa iz boshidan', () {
    final pb = LivePlayback();
    pb.push(1, [_p(phone0, 40.0)], source: 'live', now: now0);
    pb.push(1, [_p(phone0, 41.0)], source: 'tail', now: now0);
    expect(pb.position(1, now0)!.lat, 41.0);
  });

  test('retain ro\'yxatda yo\'qlarni o\'chiradi', () {
    final pb = LivePlayback();
    pb.push(1, [_p(phone0, 40.0)], source: 'live', now: now0);
    pb.push(2, [_p(phone0, 40.0)], source: 'live', now: now0);
    pb.retain({2});
    expect(pb.position(1, now0), isNull);
    expect(pb.position(2, now0), isNotNull);
  });
}
