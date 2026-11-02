import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/services/location_heartbeat.dart';
import 'package:skore_hodimlar/features/rahbar/data/location_outage.dart';

void main() {
  group('Lokatsiya nazorati (xodim)', () {
    test('holat o\'zgarishi hodisa nomiga aylanadi', () {
      expect(healthEventName(LocationHealth.gpsOff), 'location_off');
      expect(
        healthEventName(LocationHealth.permissionReduced),
        'permission_reduced',
      );
      expect(healthEventName(LocationHealth.ok), 'location_on');
    });

    group('batareya kam xabari (15% va 10%, kuniga bir martadan)', () {
      const today = '2026-10-30';
      ({bool report, String? reported}) step(
        int? current, {
        bool charging = false,
        String? reported,
      }) => lowBatteryStep(
        current: current,
        charging: charging,
        reported: reported,
        today: today,
      );

      test('15% dan past — bir marta, keyin 10% gacha jim', () {
        expect(step(30), (report: false, reported: null));
        final a = step(15);
        expect(a, (report: true, reported: '$today:15'));
        expect(step(13, reported: a.reported).report, isFalse);
        expect(step(11, reported: a.reported).report, isFalse);
      });

      test('10% dan past — yana bir marta, keyin umuman jim', () {
        final b = step(10, reported: '$today:15');
        expect(b, (report: true, reported: '$today:15,10'));
        expect(step(5, reported: b.reported).report, isFalse);
        expect(step(1, reported: b.reported).report, isFalse);
      });

      test('quvvatlab 15% dan oshib yana tushsa — bugun qayta yo\'q', () {
        expect(step(40, reported: '$today:15'), (
          report: false,
          reported: '$today:15',
        ));
        expect(step(14, reported: '$today:15').report, isFalse);
      });

      test('ilova 8% da ochilsa — bitta xabar, ikkala chegara belgilanadi', () {
        expect(step(8), (report: true, reported: '$today:15,10'));
      });

      test('quvvatlanayotganda yo\'q, uzilganda — xabar', () {
        expect(step(12, charging: true).report, isFalse);
        expect(step(12).report, isTrue);
      });

      test('kecha yuborilgan — bugun yana', () {
        expect(step(14, reported: '2026-10-29:15,10'), (
          report: true,
          reported: '$today:15',
        ));
      });

      test('batareya o\'qilmadi — holat o\'zgarmaydi', () {
        expect(step(null, reported: '$today:15'), (
          report: false,
          reported: '$today:15',
        ));
      });
    });
  });

  group('Lokatsiya uzilishi (rahbar)', () {
    test('live elementida signal yo\'q', () {
      final s = SignalLoss.fromLive({
        'signal_holat': 'yoq',
        'signal_sabab': 'location_off',
        'signal_yoq_min': 12,
      });
      expect(s, const SignalLoss(reason: 'location_off', minutes: 12));
    });

    test('signal bor yoki backend maydon bermasa — null', () {
      expect(SignalLoss.fromLive({'signal_holat': 'bor'}), isNull);
      expect(SignalLoss.fromLive({'holat': 'hududda'}), isNull);
      expect(SignalLoss.fromLive(null), isNull);
    });

    test('noma\'lum sabab — no_signal', () {
      final s = SignalLoss.fromLive({
        'signal_holat': 'yoq',
        'signal_sabab': 'something_new',
      });
      expect(s?.reason, 'no_signal');
      expect(s?.minutes, isNull);
    });

    test('uzilishlar ro\'yxati: yangisi tepada, qoidabuzarlik bayrog\'i', () {
      final list = parseLocationOutages({
        'uzilishlar': [
          {
            'boshlandi': '2026-10-27T10:42:00+05:00',
            'tugadi': '2026-10-27T10:56:00+05:00',
            'sabab': 'location_off',
            'davomiylik_min': 14,
          },
          {
            'boshlandi': '2026-10-27T15:10:00+05:00',
            'tugadi': null,
            'sabab': 'phone_died',
            'davomiylik_min': 20,
          },
          {'sabab': 'location_off'}, // vaqtsiz — tashlanadi
        ],
      })!;
      expect(list, hasLength(2));
      expect(list.first.reason, 'phone_died');
      expect(list.first.ongoing, isTrue);
      expect(list.first.violation, isFalse);
      expect(list.last.minutes, 14);
      expect(list.last.violation, isTrue);
    });

    test('server qoidabuzarlik bayrog\'ini o\'zi bersa — shu', () {
      final list = parseLocationOutages({
        'uzilishlar': [
          {
            'boshlandi': '2026-10-27T10:00:00+05:00',
            'tugadi': '2026-10-27T10:30:00+05:00',
            'sabab': 'no_signal',
            'qoidabuzarlik': false,
          },
        ],
      })!;
      expect(list.single.violation, isFalse);
      expect(list.single.minutes, 30);
    });

    test('endpoint yo\'q / boshqa javob — null', () {
      expect(parseLocationOutages({}), isNull);
      expect(parseLocationOutages({'message': 'Not found'}), isNull);
    });
  });

  group('Uzilish belgisi joyi', () {
    DateTime t(int h, int m, [int sec = 0]) =>
        DateTime(2026, 10, 25, h, m, sec);
    LocationOutage out(DateTime from, DateTime? to) => LocationOutage(
      from: from,
      to: to,
      reason: 'location_off',
      minutes: 10,
      violation: true,
    );
    final route = [
      (lat: 1.0, lng: 1.0, time: t(9, 0)),
      (lat: 2.0, lng: 2.0, time: t(10, 14, 30)),
      (lat: 3.0, lng: 3.0, time: t(10, 26)),
      (lat: 4.0, lng: 4.0, time: t(12, 0)),
    ];

    test('uzilish va ulanish paytiga eng yaqin nuqta', () {
      final o = out(t(10, 15), t(10, 25));
      expect(outageAnchor(o, route), (lat: 2.0, lng: 2.0));
      expect(outageEndAnchor(o, route), (lat: 3.0, lng: 3.0));
    });

    test(
      'nuqta uzilishdan keyin kelgan bo\'lsa ham (server kechikib biladi)',
      () {
        // 10:12 da uzildi deb yozilgan, GPS nuqtasi 10:14:30 da.
        expect(outageAnchor(out(t(10, 12), t(10, 20)), route), (
          lat: 2.0,
          lng: 2.0,
        ));
      },
    );

    test('nuqta 5 daqiqadan uzoq — belgi yo\'q (yolg\'on bo\'lmasin)', () {
      final o = out(t(11, 0), t(11, 30));
      expect(outageAnchor(o, route), isNull);
      expect(outageEndAnchor(o, route), isNull);
    });

    test('nuqta yo\'q yoki uzilish davom etyapti — belgi yo\'q', () {
      expect(outageAnchor(out(t(10, 0), t(10, 5)), []), isNull);
      expect(outageEndAnchor(out(t(10, 15), null), route), isNull);
    });
  });

  group('Uzilishlarni birlashtirish', () {
    DateTime t(int h, int m, [int sec = 0]) =>
        DateTime(2026, 10, 29, h, m, sec);
    LocationOutage o(
      DateTime from,
      DateTime? to, {
      String reason = 'no_signal',
      bool violation = true,
    }) => LocationOutage(
      from: from,
      to: to,
      reason: reason,
      minutes: to == null ? 0 : to.difference(from).inMinutes,
      violation: violation,
    );

    // Eshmatov, 29.10 — serverdan kelgan haqiqiy vaqtlar.
    final real = [
      o(t(15, 21, 28), t(15, 21, 28)),
      o(t(13, 39, 3), t(15, 5, 1)),
      o(t(13, 22, 41), t(13, 30, 2)),
      o(t(13, 9, 57), t(13, 22, 3)),
      o(t(12, 54, 45), t(13, 1, 1), reason: 'no_internet', violation: false),
      o(t(12, 44, 53), t(12, 55, 2)),
      o(t(9, 41, 41), t(11, 18, 31)),
      o(t(9, 11, 43), t(9, 41, 30)),
    ];

    test(
      'soniyalik tanaffus va ustma-ust — bitta; haqiqiy ulanish — alohida',
      () {
        final m = mergeOutages(real);
        expect(
          [for (final x in m) (x.from, x.to)],
          [
            (t(9, 11, 43), t(11, 18, 31)),
            (t(12, 44, 53), t(13, 1, 1)),
            (t(13, 9, 57), t(13, 30, 2)),
            (t(13, 39, 3), t(15, 5, 1)),
          ],
        );
        expect(m.first.minutes, 126);
        expect(m[1].reason, 'no_signal');
        expect(m[1].violation, isTrue);
      },
    );

    test('1 daqiqadan qisqa tugagan uzilish tashlanadi', () {
      expect(mergeOutages([o(t(15, 21, 28), t(15, 21, 50))]), isEmpty);
      expect(mergeOutages([o(t(15, 21), null)]), hasLength(1));
    });

    test('davom etayotgan uzilishga qo\'shilsa — hali tugamagan', () {
      final m = mergeOutages([o(t(10, 0), null), o(t(10, 30), t(10, 40))]);
      expect(m, hasLength(1));
      expect(m.first.ongoing, isTrue);
    });
  });

  test('belgi chiziqning eng yaqin uchiga qo\'yiladi', () {
    // ~0.001° ≈ 111 m (kenglik bo'yicha).
    final lines = [
      [(lat: 40.0, lng: 67.0), (lat: 40.001, lng: 67.0)],
      [(lat: 40.003, lng: 67.0), (lat: 40.004, lng: 67.0)],
    ];
    expect(nearestLineEnd((lat: 40.0015, lng: 67.0), lines), (
      lat: 40.001,
      lng: 67.0,
    ));
    expect(nearestLineEnd((lat: 40.01, lng: 67.0), lines), isNull);
  });

  group('Xaritadagi belgilar', () {
    DateTime t(int h, int m) => DateTime(2026, 10, 29, h, m);
    LocationOutage o(int h1, int m1, int h2, int m2) => LocationOutage(
      from: t(h1, m1),
      to: t(h2, m2),
      reason: 'no_signal',
      minutes: 0,
      violation: true,
    );
    // ~0.001° ≈ 111 m.
    ({double lat, double lng, DateTime time}) p(double lat, int h, int m) =>
        (lat: lat, lng: 67.0, time: t(h, m));

    test('bir joydagi uzilishlar bitta belgiga yig\'iladi', () {
      final route = [p(40.0, 9, 9), p(40.0001, 9, 25), p(40.01, 12, 0)];
      final marks = outageMarks([o(9, 10, 9, 20), o(9, 26, 11, 0)], route);
      expect(marks, hasLength(1));
      expect(marks.first.start, isTrue);
      expect(marks.first.time, t(9, 10));
      expect(marks.first.outages, hasLength(2));
    });

    test('qayta ulangan joy uzoq bo\'lsa — alohida halqa belgisi', () {
      final route = [p(40.0, 9, 9), p(40.005, 9, 21)];
      final marks = outageMarks([o(9, 10, 9, 20)], route);
      expect([for (final m in marks) m.start], [true, false]);
    });

    test('qayta ulangan joy uzilgan joyga yaqin — faqat uzilish belgisi', () {
      final route = [p(40.0, 9, 9), p(40.0005, 9, 21)];
      expect(outageMarks([o(9, 10, 9, 20)], route), hasLength(1));
    });
  });

  group('Hudud ichida siyrak nuqtalar', () {
    DateTime t(int h, int m) => DateTime(2026, 10, 30, h, m);
    LocationOutage o(int h1, int m1, [int? h2, int? m2]) => LocationOutage(
      from: t(h1, m1),
      to: h2 == null ? null : t(h2, m2!),
      reason: 'no_signal',
      minutes: 0,
      violation: true,
    );
    // Hudud: lat < 40.001.
    bool zone(double lat, double lng) => lat < 40.001;
    ({double lat, double lng, DateTime time}) p(double lat, int h, int m) =>
        (lat: lat, lng: 67.0, time: t(h, m));

    test('oxirgi nuqta hududda, keyin chiqmagan — uzilish shu joyda', () {
      // Ergashev, 30.10: oxirgi nuqta 14:01 da hududda, uzilish 15:20 da.
      final route = [p(40.0005, 13, 50), p(40.0, 14, 1)];
      expect(outageAnchor(o(15, 20), route), isNull);
      expect(outageAnchor(o(15, 20), route, inZone: zone), (
        lat: 40.0,
        lng: 67.0,
      ));
    });

    test('keyingi nuqta hududdan tashqarida — joy noma\'lum', () {
      // Eshmatov, 29.10: 09:40 da hududda, 12:44 da uzildi, 12:54 da tashqarida.
      final route = [p(40.0, 9, 40), p(40.01, 12, 54)];
      expect(outageAnchor(o(12, 44, 13, 1), route, inZone: zone), isNull);
    });

    test('hududda qayta ulangan — keyingi nuqta', () {
      final route = [p(40.0, 9, 0), p(40.0002, 11, 0)];
      expect(outageEndAnchor(o(9, 5, 10, 0), route, inZone: zone), (
        lat: 40.0002,
        lng: 67.0,
      ));
    });

    test('yaqin belgi bilan qo\'shilgan uzilish yo\'qolmaydi', () {
      // 09:51–10:00 boshi noma'lum, oxiri 10:08 dagi uzilish joyida.
      final route = [p(40.0, 9, 30), p(40.0, 10, 0), p(40.0001, 10, 8)];
      final a = o(9, 51, 10, 0);
      final b = o(10, 8, 12, 6);
      final marks = outageMarks([a, b], route);
      expect(marks, hasLength(1));
      expect(marks.first.outages, containsAll([a, b]));
    });
  });

  group('outagesFromPoints', () {
    DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 10, 30, h, m, s);
    LocationOutage o(
      DateTime from,
      DateTime? to, {
      String reason = 'no_signal',
      bool violation = true,
    }) => LocationOutage(
      from: from,
      to: to,
      reason: reason,
      minutes: (to ?? from).difference(from).inMinutes,
      violation: violation,
    );
    List<DateTime> every(DateTime from, DateTime to, Duration step) => [
      for (var t = from; t.isBefore(to); t = t.add(step)) t,
    ];

    test('nuqtalar kelib turgan vaqt uzilish emas (Sobir)', () {
      final res = outagesFromPoints(
        [o(at(8, 31, 49), at(9, 18, 2))],
        every(at(8, 48, 2), at(9, 20), const Duration(seconds: 20)),
      );
      expect(res, hasLength(1));
      expect(res.single.from, at(8, 31, 49));
      expect(res.single.to, at(8, 48, 2));
      expect(res.single.minutes, 16);
    });

    test("ketma-ket server yozuvlari haqiqiy bo'shliqlarga bo'linadi", () {
      final res = outagesFromPoints(
        [
          o(at(9, 7), at(13, 6)),
          o(at(13, 6), at(14, 45)),
          o(at(14, 45), at(16, 9)),
          o(at(16, 8), at(17, 0), reason: 'no_internet', violation: false),
        ],
        [
          at(9, 7, 40),
          ...every(at(12, 41), at(15, 0), const Duration(minutes: 1)),
          ...every(at(16, 6), at(17, 30), const Duration(minutes: 1)),
        ],
      );
      expect(res.map((e) => (e.from, e.to)), [
        (at(9, 7, 40), at(12, 41)),
        (at(14, 59), at(16, 6)),
      ]);
      expect(res.every((e) => e.violation), isTrue);
    });

    test("bo'lakka eng ko'p ustma-ust tushgan yozuvning sababi beriladi", () {
      final res = outagesFromPoints(
        [
          o(at(10, 0), at(10, 5)),
          o(at(10, 5), at(10, 30), reason: 'no_internet', violation: false),
        ],
        [at(10, 2)],
      );
      expect(res, hasLength(1));
      expect(res.single.reason, 'no_internet');
      expect(res.single.violation, isFalse);
    });

    test('davom etayotgan uzilish oxirgi nuqtadan boshlanadi', () {
      final res = outagesFromPoints(
        [o(at(8, 58), null)],
        [at(8, 58, 23), at(9, 1)],
        now: at(9, 40),
      );
      expect(res, hasLength(1));
      expect(res.single.from, at(9, 1));
      expect(res.single.ongoing, isTrue);
    });

    test("signal qaytgan bo'lsa davom etayotgan uzilish yopiladi", () {
      final res = outagesFromPoints(
        [o(at(9, 0), null)],
        every(at(9, 10), at(9, 40), const Duration(seconds: 30)),
        now: at(9, 40),
      );
      expect(res, hasLength(1));
      expect(res.single.to, at(9, 10));
    });

    test("signal qisqa qaytgan bo'laklar bitta uzilish", () {
      final res = outagesFromPoints(
        [o(at(14, 37), at(16, 45))],
        [at(15, 42), at(15, 55), at(16, 14), at(16, 15)],
      );
      expect(res, hasLength(1));
      expect(res.single.from, at(14, 37));
      expect(res.single.to, at(16, 45));
    });

    test("nuqta bo'lmasa server yozuvi o'zgarmaydi", () {
      final res = outagesFromPoints([o(at(9, 0), at(9, 30))], []);
      expect(res.single.from, at(9, 0));
      expect(res.single.to, at(9, 30));
    });
  });
}
