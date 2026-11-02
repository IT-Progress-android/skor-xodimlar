import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';

/// Harakat tarixini **tezlikka qarab** chizish (Zonic usuli + mashina
/// uchun backend):
///
/// - **Piyoda** — telefon yuborgan, Zonic filtridan o'tgan haqiqiy GPS
///   nuqtalari ([TrackPiece.samples] bilan). Xaritada ular yo'laklar
///   bo'ylab moslanadi va silliqlanadi (`walk_path.dart`): katta ko'chaga
///   emas, hovli, bog' yo'lchalariga ham.
/// - **Transport** — shu vaqt uchun backend yo'lga moslagan (`yol`) bo'lak
///   bo'lsa, o'sha; bo'lmasa haqiqiy nuqtalar.
/// - **Ma'lumot yo'q** — binolar ustidan to'g'ri chiziq tortilmaydi. Qisqa
///   va piyodaga mos oraliq xira punktir, uzunlari umuman ulanmaydi.
enum TrackPieceKind {
  walk,
  vehicle,

  /// Qisqa, ishonchli bo'shliq — punktir.
  gap,

  /// Uzun yoki noma'lum bo'shliq — chizilmaydi.
  missing,
}

typedef LatLng = ({double lat, double lng});

class TrackPiece {
  const TrackPiece(
    this.kind,
    this.points,
    this.from,
    this.to, {
    this.fromRoad = false,
    this.samples = const [],
  });

  final TrackPieceKind kind;

  /// Piyoda bo'lakning vaqtli haqiqiy nuqtalari ([points] bilan bir xil
  /// tartibda) — yo'laklar bo'ylab moslash uchun. Boshqa turlarda bo'sh.
  final List<TimedPoint> samples;

  /// Shu bo'lak, faqat chizig'i boshqa (masalan, yo'lakka moslangan).
  TrackPiece withPoints(List<LatLng> points) =>
      TrackPiece(kind, points, from, to, fromRoad: fromRoad, samples: samples);

  /// Backend yo'lga moslagan (`yol`) chiziq — haqiqiy nuqtalar emas.
  final bool fromRoad;
  final List<LatLng> points;
  final DateTime from;
  final DateTime to;

  Duration get duration => to.difference(from);
}

/// Transportga "kirish": [speedWindow] dagi tezlik shundan yuqori
/// (≈25 km/soat) va kamida [minVehicleSeed] davom etsa — bu aniq mashina
/// (piyoda/yugurish bunga yetmaydi).
const vehicleEnterSpeedMs = 7.0;

/// Transportda "qolish": kirilgan transport bo'lagi tezlik shundan
/// (≈9 km/soat, piyodadan tez) tushmaguncha ikki tomonga davom etadi —
/// tezlanish va sekinlashish ham mashina.
const vehicleStaySpeedMs = 2.5;

/// Kirish uchun eng qisqa tez qism.
const minVehicleSeed = Duration(seconds: 8);

/// Tezlik shu oraliqdagi siljishdan hisoblanadi (bitta nuqtaning GPS
/// xatosi piyodani "mashina" qilib qo'ymasin).
const speedWindow = Duration(seconds: 20);

/// Ikki transport qismi orasidagi shundan qisqa "sekin" qism (svetofor,
/// tirbandlik) — transport hisoblanadi. Shahar ichida mashina 20–40 s
/// yurib, 20–90 s to'xtaydi.
const maxStopInsideVehicle = Duration(minutes: 2);

/// Shundan uzoq nuqta kelmasa — bo'shliq.
const pieceGapTime = Duration(seconds: 90);

/// Vaqtdan qat'i nazar shundan uzoq sakrash ham bo'shliq.
const pieceJumpMeters = 250.0;

/// Shu chegaradagi bo'shliq punktir bilan ko'rsatiladi; kattasi
/// ulanmaydi.
const shortGapMaxTime = Duration(minutes: 5);
const shortGapMaxMeters = 60.0;

/// Piyoda bo'lakda ikki nuqta orasi shundan uzoq bo'lsa — o'rtadagi yo'l
/// noma'lum (1 Hz da piyoda 1–5 m yuradi): to'g'ri chiziq binolarni kesib
/// o'tmasin, bo'lak shu joyda uziladi.
const maxWalkChord = 40.0;

/// Transport bo'lagida (backend yo'li bo'lmasa) shu chegara.
const maxVehicleChord = 100.0;

/// Shahar ichida bundan tez "sakrash" — GPS xatosi yoki eskirgan nuqta,
/// tashlanadi (~90 km/soat).
const maxCitySpeedMs = 25.0;

/// Transport qismi uchun backend `yol` bo'laklari vaqtning shuncha qismini
/// qoplasa — ular ishlatiladi.
const roadCoverage = 0.6;

/// Backend yo'li va haqiqiy nuqta orasidagi ulovchi shundan uzun bo'lsa
/// qo'shilmaydi.
const _maxConnector = 150.0;

LatLng _ll(TimedPoint p) => (lat: p.lat, lng: p.lng);

double _dist(LatLng a, LatLng b) => distanceMeters(a.lat, a.lng, b.lat, b.lng);

/// [raw] — vaqt bo'yicha tartiblangan, tozalangan tarix nuqtalari.
/// [matched] — backend `/marshrut` bo'laklari (bo'lmasa bo'sh).
/// [inOffice] — nuqta xodimning o'z ish zonasi ichidami: ikki uchi ham
/// zonada bo'lgan bo'shliq (xodim ofisda o'tirgan — u yerda nuqta
/// yuborilmaydi) umuman ko'rsatilmaydi.
List<TrackPiece> buildSpeedTrack(
  List<TimedPoint> raw, {
  List<RouteSegment> matched = const [],
  bool Function(LatLng p)? inOffice,
}) {
  final roads = [
    for (final s in matched)
      if (s.kind == RouteSegmentKind.road) s,
  ];
  final pieces = <TrackPiece>[];

  final runs = _splitRuns(_dropTeleports(raw));
  for (var r = 0; r < runs.length; r++) {
    if (r > 0) {
      final gap = _gapPiece(runs[r - 1].last, runs[r].first, roads, inOffice);
      if (gap != null) pieces.add(gap);
    }
    for (final piece in _runPieces(runs[r], roads)) {
      pieces.addAll(_splitLongChords(piece));
    }
  }
  return pieces;
}

/// Oldingi qabul qilingan nuqtadan [maxCitySpeedMs] dan tez yetib bo'lmaydigan
/// nuqtalar tashlanadi.
List<TimedPoint> _dropTeleports(List<TimedPoint> raw) {
  final out = <TimedPoint>[];
  for (final p in raw) {
    if (out.isNotEmpty) {
      final a = out.last;
      final sec = p.time.difference(a.time).inMilliseconds / 1000;
      if (sec > 0 &&
          distanceMeters(a.lat, a.lng, p.lat, p.lng) / sec > maxCitySpeedMs) {
        continue;
      }
    }
    out.add(p);
  }
  return out;
}

/// Haqiqiy nuqtalardan chizilgan bo'lakni uzun to'g'ri chiziqlarda uzadi.
/// Backend yo'li ishlatilgan transport bo'lagi tegilmaydi (u yo'l bo'ylab).
/// Vaqtlar nuqtalarda yo'q — bo'laklar orasida chiziqli taqsimlanadi
/// (faqat ko'rsatish uchun).
List<TrackPiece> _splitLongChords(TrackPiece piece) {
  final limit = switch (piece.kind) {
    TrackPieceKind.walk => maxWalkChord,
    TrackPieceKind.vehicle when !piece.fromRoad => maxVehicleChord,
    _ => null,
  };
  if (limit == null || piece.points.length < 2) return [piece];
  final out = <TrackPiece>[];
  var cur = <LatLng>[piece.points.first];
  final n = piece.points.length;
  final timed = piece.samples.length == n;
  DateTime timeAt(int i) => timed
      ? piece.samples[i].time
      : piece.from.add(
          Duration(milliseconds: piece.duration.inMilliseconds * i ~/ (n - 1)),
        );
  List<TimedPoint> samplesOf(int from, int to) =>
      timed ? piece.samples.sublist(from, to + 1) : const [];
  var curStart = 0;
  for (var i = 1; i < n; i++) {
    final a = piece.points[i - 1], b = piece.points[i];
    final d = _dist(a, b);
    if (d > limit) {
      if (cur.length >= 2) {
        out.add(
          TrackPiece(
            piece.kind,
            cur,
            timeAt(curStart),
            timeAt(i - 1),
            samples: samplesOf(curStart, i - 1),
          ),
        );
      }
      out.add(
        TrackPiece(
          d <= shortGapMaxMeters ? TrackPieceKind.gap : TrackPieceKind.missing,
          [a, b],
          timeAt(i - 1),
          timeAt(i),
        ),
      );
      cur = [b];
      curStart = i;
    } else {
      cur.add(b);
    }
  }
  if (cur.length >= 2) {
    out.add(
      TrackPiece(
        piece.kind,
        cur,
        timeAt(curStart),
        piece.to,
        samples: samplesOf(curStart, n - 1),
      ),
    );
  }
  return out;
}

/// Uzluksiz oqimlar: vaqt yoki masofa bo'yicha uzilishda bo'linadi.
List<List<TimedPoint>> _splitRuns(List<TimedPoint> raw) {
  final runs = <List<TimedPoint>>[];
  var cur = <TimedPoint>[];
  for (final p in raw) {
    if (cur.isNotEmpty) {
      final a = cur.last;
      if (!p.time.isAfter(a.time)) continue;
      final gap =
          p.time.difference(a.time) > pieceGapTime ||
          distanceMeters(a.lat, a.lng, p.lat, p.lng) > pieceJumpMeters;
      if (gap) {
        runs.add(cur);
        cur = [];
      }
    }
    cur.add(p);
  }
  if (cur.isNotEmpty) runs.add(cur);
  return runs;
}

/// Har bir oraliq (i → i+1) dagi tezlik (m/s): [speedWindow] dagi siljish
/// bo'yicha (ikki ko'rsatkichli oyna, O(n)).
List<double> _windowSpeeds(List<TimedPoint> run) {
  final n = run.length;
  if (n < 2) return const [];
  final half = speedWindow ~/ 2;
  final speeds = List<double>.filled(n - 1, 0);
  var lo = 0, hi = 0;
  for (var i = 0; i < n - 1; i++) {
    final mid = run[i].time.add(run[i + 1].time.difference(run[i].time) ~/ 2);
    while (lo < i && mid.difference(run[lo + 1].time) >= half) {
      lo++;
    }
    if (hi < i + 1) hi = i + 1;
    while (hi < n - 1 && run[hi].time.difference(mid) < half) {
      hi++;
    }
    final a = run[lo], b = run[hi];
    final sec = b.time.difference(a.time).inMilliseconds / 1000;
    if (sec <= 0) continue;
    speeds[i] = distanceMeters(a.lat, a.lng, b.lat, b.lng) / sec;
  }
  return speeds;
}

/// Har bir oraliq transportmi — ikki chegarali qoida:
/// 1. [vehicleEnterSpeedMs] dan tez, kamida [minVehicleSeed] — aniq mashina;
/// 2. undan ikki tomonga tezlik [vehicleStaySpeedMs] dan tushmaguncha —
///    tezlanish/sekinlashish ham mashina.
List<bool> _vehicleFlags(List<TimedPoint> run) {
  final v = _windowSpeeds(run);
  final flags = List<bool>.filled(v.length, false);
  var i = 0;
  while (i < v.length) {
    if (v[i] < vehicleEnterSpeedMs) {
      i++;
      continue;
    }
    var j = i;
    while (j + 1 < v.length && v[j + 1] >= vehicleEnterSpeedMs) {
      j++;
    }
    if (run[j + 1].time.difference(run[i].time) >= minVehicleSeed) {
      var a = i, b = j;
      while (a > 0 && v[a - 1] >= vehicleStaySpeedMs) {
        a--;
      }
      while (b + 1 < v.length && v[b + 1] >= vehicleStaySpeedMs) {
        b++;
      }
      for (var k = a; k <= b; k++) {
        flags[k] = true;
      }
      j = b;
    }
    i = j + 1;
  }
  return flags;
}

/// Bir xil belgili ketma-ket oraliqlar: (boshlanish indeksi, tugash
/// indeksi, transportmi).
typedef _Span = ({int start, int end, bool vehicle});

List<_Span> _spans(List<bool> flags) {
  final out = <_Span>[];
  for (var i = 0; i < flags.length; i++) {
    if (out.isNotEmpty && out.last.vehicle == flags[i]) {
      out[out.length - 1] = (
        start: out.last.start,
        end: i + 1,
        vehicle: flags[i],
      );
    } else {
      out.add((start: i, end: i + 1, vehicle: flags[i]));
    }
  }
  return out;
}

List<_Span> _merge(List<_Span> spans) {
  final out = <_Span>[];
  for (final s in spans) {
    if (out.isNotEmpty && out.last.vehicle == s.vehicle) {
      out[out.length - 1] = (
        start: out.last.start,
        end: s.end,
        vehicle: s.vehicle,
      );
    } else {
      out.add(s);
    }
  }
  return out;
}

/// Transportlar orasidagi qisqa to'xtash (svetofor, tirbandlik) transport
/// bo'ladi — bitta safar bitta rangda.
List<_Span> _smoothSpans(List<_Span> spans, List<TimedPoint> run) {
  Duration len(_Span s) => run[s.end].time.difference(run[s.start].time);
  final out = _merge(spans);
  return _merge([
    for (var i = 0; i < out.length; i++)
      if (!out[i].vehicle &&
          i > 0 &&
          i < out.length - 1 &&
          len(out[i]) <= maxStopInsideVehicle)
        (start: out[i].start, end: out[i].end, vehicle: true)
      else
        out[i],
  ]);
}

List<TrackPiece> _runPieces(List<TimedPoint> run, List<RouteSegment> roads) {
  if (run.length < 2) return const [];
  final spans = _smoothSpans(_spans(_vehicleFlags(run)), run);
  return [
    for (final s in spans)
      // Qo'shni bo'laklar bitta umumiy nuqtada tutashadi — chiziq uzilmaydi.
      if (s.vehicle)
        _vehiclePiece(run.sublist(s.start, s.end + 1), roads)
      else
        TrackPiece(
          TrackPieceKind.walk,
          [for (final p in run.sublist(s.start, s.end + 1)) _ll(p)],
          run[s.start].time,
          run[s.end].time,
          samples: run.sublist(s.start, s.end + 1),
        ),
  ];
}

/// [from]–[to] oralig'ini kamida [roadCoverage] qismga qoplaydigan backend
/// yo'li; bo'lmasa `null`.
List<LatLng>? _roadPath(List<RouteSegment> roads, DateTime from, DateTime to) {
  final total = to.difference(from).inMilliseconds;
  if (total <= 0) return null;
  var covered = 0;
  final path = <LatLng>[];
  for (final s in roads) {
    final a = s.from.isAfter(from) ? s.from : from;
    final b = s.to.isBefore(to) ? s.to : to;
    final overlap = b.difference(a).inMilliseconds;
    if (overlap <= 0) continue;
    // Bo'lak ko'p qismi bilan shu oraliqda bo'lsagina olinadi (nuqtalarida
    // vaqt yo'q — uni kesib bo'lmaydi).
    final own = s.to.difference(s.from).inMilliseconds;
    if (own > 0 && overlap / own < 0.5) continue;
    covered += overlap;
    path.addAll(s.points);
  }
  if (path.length < 2 || covered / total < roadCoverage) return null;
  return path;
}

/// Backend yo'lining uchlarini haqiqiy nuqtalarga ulaydi (qisqa bo'lsa).
List<LatLng> _connect(LatLng start, List<LatLng> road, LatLng end) => [
  if (_dist(start, road.first) <= _maxConnector) start,
  ...road,
  if (_dist(road.last, end) <= _maxConnector) end,
];

TrackPiece _vehiclePiece(List<TimedPoint> pts, List<RouteSegment> roads) {
  final from = pts.first.time, to = pts.last.time;
  final road = _roadPath(roads, from, to);
  return TrackPiece(
    TrackPieceKind.vehicle,
    road == null
        ? [for (final p in pts) _ll(p)]
        : _connect(_ll(pts.first), road, _ll(pts.last)),
    from,
    to,
    fromRoad: road != null,
  );
}

TrackPiece? _gapPiece(
  TimedPoint a,
  TimedPoint b,
  List<RouteSegment> roads,
  bool Function(LatLng p)? inOffice,
) {
  final pa = _ll(a), pb = _ll(b);
  if (inOffice != null && inOffice(pa) && inOffice(pb)) return null;
  final road = _roadPath(roads, a.time, b.time);
  if (road != null) {
    return TrackPiece(
      TrackPieceKind.vehicle,
      _connect(pa, road, pb),
      a.time,
      b.time,
      fromRoad: true,
    );
  }
  final short =
      b.time.difference(a.time) <= shortGapMaxTime &&
      _dist(pa, pb) <= shortGapMaxMeters;
  return TrackPiece(
    short ? TrackPieceKind.gap : TrackPieceKind.missing,
    [pa, pb],
    a.time,
    b.time,
  );
}

/// Ikki tomoni ham chizilmaydigan bo'shliq ([TrackPieceKind.missing] yoki
/// chiziq boshi/oxiri) bo'lgan, jami [minLength] m dan qisqa chizilgan
/// zanjir (bir yoki bir nechta ketma-ket piyoda/mashina/punktir bo'lak) —
/// hech narsaga ulanmagan "dumcha". Odatda ikki GPS sakrashi orasida qolgan
/// parcha: yo'l haqida ma'lumot bermaydi, faqat chalg'itadi, shuning uchun
/// butunlay tashlanadi.
List<TrackPiece> dropIsolatedStubs(
  List<TrackPiece> pieces, {
  double minLength = 100,
}) {
  double length(List<LatLng> pts) {
    var t = 0.0;
    for (var i = 1; i < pts.length; i++) {
      t += _dist(pts[i - 1], pts[i]);
    }
    return t;
  }

  final keep = List.filled(pieces.length, true);
  var i = 0;
  while (i < pieces.length) {
    if (pieces[i].kind == TrackPieceKind.missing) {
      i++;
      continue;
    }
    var j = i;
    var total = 0.0;
    while (j < pieces.length && pieces[j].kind != TrackPieceKind.missing) {
      total += length(pieces[j].points);
      j++;
    }
    if (total < minLength) {
      for (var k = i; k < j; k++) {
        keep[k] = false;
      }
    }
    i = j;
  }
  return [
    for (var k = 0; k < pieces.length; k++)
      if (keep[k]) pieces[k],
  ];
}
