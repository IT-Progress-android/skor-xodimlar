import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:skore_hodimlar/features/rahbar/data/building_index.dart';
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';
import 'package:skore_hodimlar/features/rahbar/data/walk_path.dart';
import 'package:skore_hodimlar/features/rahbar/data/walk_route_store.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

export 'package:skore_hodimlar/features/rahbar/data/building_index.dart'
    show BuildingIndex, LatLng;

/// Siyrak GPS nuqtalari orasini ko'chalar bo'ylab to'ldiradi (Yandex
/// piyoda / avto marshrutlovchisi). Backend yo'lga moslay olmagan joylar
/// uchun: to'g'ri chiziq binolar ustidan o'tmasin.
///
/// Natija keshlanadi; so'rovlar navbat bilan, bir vaqtda ko'pi bilan
/// [_maxInFlight] ta. Natija kelganda [onUpdate] chaqiriladi — xarita qayta
/// chiziladi. Ishonchli ko'cha yo'li topilmasa — `null`, chiziq u yerda
/// uziladi (binolar ustidan to'g'ri chiziq hech qachon chizilmaydi).
class StreetRouter {
  StreetRouter({
    required this.onUpdate,
    WalkRouteRequester? walkRequester,
    this.walkStore,
  }) : _walkRequester = walkRequester ?? _yandexWalkRoutes {
    ready = _loadSaved();
  }

  final VoidCallback onUpdate;

  /// Saqlangan piyoda natijalari ([walkPath]) yuklangach tugaydi. Tarixni
  /// chizishdan oldin kutilsa — saqlanganlar uchun Yandex'ga so'rov ketmaydi.
  late final Future<void> ready;

  /// Piyoda natijalarini telefonda saqlash (`null` — saqlanmaydi).
  final WalkRouteStore? walkStore;

  /// Saqlanadigan piyoda natijalari (bo'sh ro'yxat — mos yo'l yo'q).
  final _saved = <String, List<LatLng>>{};
  Timer? _saveTimer;

  /// Saqlanadigan piyoda natijalari soni chegarasi (~2–3 MB).
  static const _maxSaved = 4000;

  /// Piyoda marshrut so'rovchisi (testda soxta beriladi).
  final WalkRouteRequester _walkRequester;

  /// Bino konturlari: yuklangan bo'lsa yagona taqiq — bino ustidan o'tish.
  /// Katta yo'l, xiyobon, kichik ko'cha kesib o'tilishi mumkin.
  final BuildingIndex buildings = BuildingIndex.instance;

  static const _maxInFlight = 4;
  static const _maxCache = 3000;

  final _cache = <String, List<LatLng>?>{};
  final _queue = Queue<({String key, Future<List<LatLng>?> Function() run})>();
  final _queued = <String>{};
  int _inFlight = 0;

  /// Har yangi natija bilan oshadi ([walkPath] memosi eskiradi).
  int _version = 0;
  final _walkMemo = <String, List<LatLng>>{};
  bool _disposed = false;
  Timer? _notify;

  static String _key(LatLng a, LatLng b, bool car) =>
      '${car ? 'c' : 'p'}'
      '${a.lat.toStringAsFixed(5)},${a.lng.toStringAsFixed(5)}>'
      '${b.lat.toStringAsFixed(5)},${b.lng.toStringAsFixed(5)}';

  /// [a] → [b] oralig'i ko'chalar bo'ylab (uchlari bilan) yoki `null` (hali
  /// tayyor emas yoki to'g'ri chiziq qoladi). Tayyor bo'lmasa so'rov
  /// navbatga qo'yiladi.
  List<LatLng>? path(TimedPoint a, TimedPoint b, {bool? car}) {
    final pa = (lat: a.lat, lng: a.lng), pb = (lat: b.lat, lng: b.lng);
    if (!needsStreetSnap(pa, pb)) return null;
    final isCar = car ?? looksLikeDriving(a, b);
    final key = _key(pa, pb, isCar);
    if (_cache.containsKey(key)) return _cache[key];
    if (_queued.add(key)) {
      _queue.add((key: key, run: () => _request(a, b, isCar)));
      _pump();
    }
    return null;
  }

  /// [points] ketma-ketligini chiziq qiladi. Bino konturlari yuklangan
  /// bo'lsa ([BuildingIndex.isReady]) har oraliq uchun:
  /// 1. ko'cha / yo'lak yo'li bor va to'g'ri chiziqdan deyarli uzun emas
  ///    (≤ 1.3× + 20 m) — shu yo'l;
  /// 2. aks holda to'g'ri chiziq bino ustidan o'tmasa — to'g'ri chiziq
  ///    (katta yo'l, yer osti o'tish joyi, xiyobon kesib o'tiladi — aylanib
  ///    yurilmaydi va uzilmaydi);
  /// 3. aks holda binolarni chetlab o'tgan ko'cha yo'li;
  /// 4. bo'lmasa — to'g'ri chiziqning faqat bino tashqarisidagi qismi
  ///    (bino ichiga kirgan bo'lsa chiziq devor / eshik oldida to'xtaydi).
  ///
  /// Konturlar yo'q bo'lsa (internet yoki Overpass xatosi) — faqat ko'cha
  /// yo'li, topilmagan uzun oraliq chizilmaydi.
  List<List<LatLng>> snap(List<TimedPoint> points) {
    if (points.length < 2) return const [];
    final anchors = <TimedPoint>[points.first];
    for (var i = 1; i < points.length; i++) {
      final prev = anchors.last, cur = points[i];
      if (needsStreetSnap(
        (lat: prev.lat, lng: prev.lng),
        (lat: cur.lat, lng: cur.lng),
      )) {
        anchors.add(cur);
      }
    }
    if (anchors.length == 1) anchors.add(points.last);
    // Yo'l bo'ylab GPS zigzagi (keng ko'chaning narigi tomoniga "o'tib-
    // qaytish") — to'g'ri yuriladi. Binolar ma'lum bo'lsa, bino ustidan
    // o'tmaydigan har qanday chetlanish (burchak ham) to'g'rilanadi.
    final simplified = buildings.isReady
        ? simplifyExcursions(
            anchors,
            // GPS siljishi (80 m gacha) — bino ustidan o'tmasa, eng qisqa
            // to'g'ri yo'nalish tanlanadi.
            toleranceM: 80,
            minRatio: 1.5,
            clean: (a, b) => !buildings.crosses(
              (lat: a.lat, lng: a.lng),
              (lat: b.lat, lng: b.lng),
            ),
          )
        : simplifyExcursions(anchors);
    // Nusxa: 3 tadan kam nuqtada [simplifyExcursions] o'sha ro'yxatni
    // qaytaradi — `clear()` uni ham bo'shatib yuborardi.
    final kept = [...simplified];
    anchors
      ..clear()
      ..addAll(_dropDetourPoints(kept));
    final lines = <List<LatLng>>[];
    var cur = <LatLng>[];
    void close() {
      if (cur.length >= 2) lines.add(cur);
      cur = <LatLng>[];
    }

    bool same(LatLng x, LatLng y) =>
        distanceMeters(x.lat, x.lng, y.lat, y.lng) < 1;

    // To'g'ri chiziqning faqat bino tashqarisidagi qismlari.
    void addStraight(LatLng pa, LatLng pb) {
      final parts = buildings.clipOutside([pa, pb]);
      if (parts.isEmpty) {
        close();
        return;
      }
      for (final part in parts) {
        if (cur.isNotEmpty && same(cur.last, part.first)) {
          cur.addAll(part.skip(1));
        } else {
          close();
          cur.addAll(part);
        }
      }
      if (!same(cur.last, pb)) close();
    }

    for (var i = 1; i < anchors.length; i++) {
      final a = anchors[i - 1], b = anchors[i];
      final pa = (lat: a.lat, lng: a.lng), pb = (lat: b.lat, lng: b.lng);
      final d = distanceMeters(pa.lat, pa.lng, pb.lat, pb.lng);
      final street = path(a, b);
      if (!buildings.isReady) {
        // Binolar noma'lum: ko'cha yo'li (aylanmasiz) yoki — katta yo'lni,
        // yer osti o'tish joyini kesib o'tish — 150 m gacha to'g'ri chiziq.
        if (street != null && _len(street) <= d * 1.3 + 20) {
          cur.addAll(street);
        } else if (d <= 150) {
          if (cur.isEmpty) cur.add(pa);
          cur.add(pb);
        } else if (street != null) {
          cur.addAll(street);
        } else {
          // Yo'l topilmadi — baribir keyingi nuqtagacha uzilmaydi.
          if (cur.isEmpty) cur.add(pa);
          cur.add(pb);
        }
        continue;
      }
      if (street != null && _len(street) <= d * 1.3 + 20) {
        cur.addAll(street);
      } else if (!buildings.crosses(pa, pb)) {
        if (cur.isEmpty) cur.add(pa);
        cur.add(pb);
      } else if (street != null) {
        cur.addAll(street);
      } else {
        addStraight(pa, pb);
      }
    }
    close();
    return lines;
  }

  /// [a]→[b] oralig'ining chiziladigan uzunligi: ko'cha yo'li bo'lsa uniki,
  /// aks holda to'g'ri masofa.
  double _pairLen(TimedPoint a, TimedPoint b) {
    final p = path(a, b);
    return p != null ? _len(p) : distanceMeters(a.lat, a.lng, b.lat, b.lng);
  }

  /// GPS xatosi bilan yo'ldan chetga tushgan nuqtalar tashlanadi (bino
  /// atrofidan aylanib chizilmasin). Har bir B nuqta uchun oldingi A va
  /// keyingi C: A→C ko'cha yo'li bor, B shu yo'ldan ≤ 40 m (GPS xatosi
  /// chegarasi) va B orqali borish A→C dan 15% (+10 m) dan uzun bo'lsa —
  /// B kerak emas: xodim A dan C ga eng qisqa yo'ldan, kelgan va ketgan
  /// yo'nalishi bo'yicha yurgan. Yo'l hali tayyor bo'lmasa B qoladi (so'rov
  /// navbatga qo'yiladi, keyingi chizishda qayta tekshiriladi).
  List<TimedPoint> _dropDetourPoints(List<TimedPoint> pts) {
    if (pts.length < 3) return pts;
    final out = <TimedPoint>[pts.first];
    for (var i = 1; i < pts.length - 1; i++) {
      final a = out.last, b = pts[i], c = pts[i + 1];
      final ac = path(a, c);
      if (ac != null && ac.length >= 2) {
        final near =
            nearestOnLines((lat: b.lat, lng: b.lng), [ac], maxDist: 40) != null;
        final via = _pairLen(a, b) + _pairLen(b, c);
        if (near && via > _len(ac) * 1.15 + 10) continue;
      }
      out.add(b);
    }
    out.add(pts.last);
    return out;
  }

  /// Piyoda bo'lak chizig'i ([walk_path.dart] qoidalari): yo'laklar
  /// bo'ylab moslangan yo'l, u hali tayyor bo'lmasa yoki mos kelmasa —
  /// silliqlangan GPS izi. Har ikkala holatda burchaklar yumaloqlanadi.
  /// Tayyor bo'lmagan bo'laklar navbatga qo'yiladi, natija kelganda
  /// [onUpdate].
  List<LatLng> walkPath(List<TimedPoint> raw) {
    if (raw.length < 2) return [for (final p in raw) (lat: p.lat, lng: p.lng)];
    // Xarita sekundiga bir necha marta qayta chiziladi — natija yangi
    // marshrut kelmaguncha o'zgarmaydi.
    final memoKey =
        '${raw.first.time.microsecondsSinceEpoch}|'
        '${raw.last.time.microsecondsSinceEpoch}|${raw.length}|$_version';
    final memo = _walkMemo[memoKey];
    if (memo != null) return memo;
    final line = _walkPath(raw);
    if (_walkMemo.length >= 200) _walkMemo.remove(_walkMemo.keys.first);
    return _walkMemo[memoKey] = line;
  }

  List<LatLng> _walkPath(List<TimedPoint> raw) {
    final smooth = smoothWalkTrack(raw);
    final smoothLine = [for (final p in smooth) (lat: p.lat, lng: p.lng)];
    // Juda qisqa — marshrutlovchi kerak emas.
    if (walkLength(smoothLine) < 30) return roundCorners(smoothLine);
    final parts = <List<LatLng>>[];
    for (final chunk in walkChunks(walkAnchors(smooth))) {
      final from = chunk.first.time, to = chunk.last.time;
      final own = [
        for (final p in raw)
          if (!p.time.isBefore(from) && !p.time.isAfter(to)) p,
      ];
      final key =
          'w${chunk.map((p) => '${p.lat.toStringAsFixed(5)},'
              '${p.lng.toStringAsFixed(5)}').join('>')}';
      final matched = _cache[key];
      if (matched == null && !_cache.containsKey(key) && _queued.add(key)) {
        _queue.add((key: key, run: () => _requestWalk(chunk, own)));
        _pump();
      }
      parts.add(
        matched ??
            [
              for (final p in smooth)
                if (!p.time.isBefore(from) && !p.time.isAfter(to))
                  (lat: p.lat, lng: p.lng),
            ],
      );
    }
    // Ulanish va silliq izdagi qisqa borib-qaytishlar ham chizilmaydi.
    // Xodim bormagan o'simtalar (izdan > 12 m chetga chiqib qaytgan) ham.
    return roundCorners(
      removeNotches(removeWalkSpurs(stitchWalkParts(parts)), smoothLine),
    );
  }

  /// [mergeParallelWalks] — natija yangi yo'l kelmaguncha keshlanadi
  /// (xarita sekundiga bir necha marta chiziladi).
  List<List<LatLng>> mergeWalks(List<List<LatLng>> lines) {
    final key = '$_version|${lines.map(identityHashCode).join(',')}';
    final hit = _mergeMemo;
    if (hit != null && hit.key == key) return hit.lines;
    final merged = mergeParallelWalks(lines);
    _mergeMemo = (key: key, lines: merged);
    return merged;
  }

  ({String key, List<List<LatLng>> lines})? _mergeMemo;

  /// Bitta bo'lak: boshi/oxiri `wayPoint`, o'rtasi `viaPoint` — Yandex
  /// piyoda yo'li bitta uzluksiz chiziq. Haqiqiy izga mos variantlardan eng
  /// qisqasi. Mosi bo'lmasa (masalan, xodim xaritada yo'q o'tish joyidan
  /// o'tgan) bo'lak ikkiga bo'linib qayta so'raladi — faqat mos kelmagan
  /// qismi silliq iz bo'ladi. Hech qaysi qismi mos kelmasa — `null`.
  Future<List<LatLng>?> _requestWalk(
    List<TimedPoint> chunk,
    List<TimedPoint> raw,
  ) async {
    final parts = await _matchWalk(chunk, raw);
    if (parts.every((p) => !p.matched)) return null;
    return stitchWalkParts([for (final p in parts) p.line]);
  }

  Future<List<({List<LatLng> line, bool matched})>> _matchWalk(
    List<TimedPoint> chunk,
    List<TimedPoint> raw,
  ) async {
    final List<List<LatLng>> routes;
    try {
      routes = [
        for (final r in await _walkRequester([
          for (final p in chunk) (lat: p.lat, lng: p.lng),
        ]))
          removeWalkSpurs(r),
      ];
    } catch (e) {
      debugPrint('🚶 [PIYODA] ${chunk.length} nuqta: xato — $e');
      rethrow;
    }
    final best = _shortest(routes, (p) => acceptWalkMatch(p, raw));
    debugPrint(
      '🚶 [PIYODA] ${chunk.length} nuqta, ${raw.length} GPS: '
      '${routes.length} variant -> '
      '${best == null ? 'mos emas (${routes.map((r) => walkMatchProblem(r, raw)).join('; ')})' : 'yo\'lak (${best.length} nuqta)'}',
    );
    if (best != null) return [(line: best, matched: true)];
    if (chunk.length < 3) {
      return [
        (
          line: [
            for (final p in smoothWalkTrack(raw)) (lat: p.lat, lng: p.lng),
          ],
          matched: false,
        ),
      ];
    }
    final mid = chunk.length ~/ 2;
    List<TimedPoint> rawOf(List<TimedPoint> c) => [
      for (final p in raw)
        if (!p.time.isBefore(c.first.time) && !p.time.isAfter(c.last.time)) p,
    ];
    final a = chunk.sublist(0, mid + 1), b = chunk.sublist(mid);
    return [...await _matchWalk(a, rawOf(a)), ...await _matchWalk(b, rawOf(b))];
  }

  /// Navbatda yoki jarayonda so'rov bormi.
  bool get isBusy => _inFlight > 0 || _queue.isNotEmpty;

  int get pendingCount => _inFlight + _queue.length;

  void _pump() {
    while (!_disposed && _inFlight < _maxInFlight && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _inFlight++;
      unawaited(
        job
            .run()
            .then((p) => _store(job.key, p, save: job.key.startsWith('w')))
            .catchError((Object _) => _store(job.key, null))
            .whenComplete(() {
              _inFlight--;
              _queued.remove(job.key);
              _pump();
            }),
      );
    }
  }

  /// [save] — natija telefonda saqlanadi (faqat muvaffaqiyatli so'rov:
  /// internet xatosi keyingi safar qayta so'ralsin).
  void _store(String key, List<LatLng>? p, {bool save = false}) {
    if (_disposed) return;
    if (_cache.length >= _maxCache) _cache.remove(_cache.keys.first);
    _cache[key] = p;
    _version++;
    if (save && walkStore != null) {
      _saved.remove(key);
      _saved[key] = p ?? const [];
      while (_saved.length > _maxSaved) {
        _saved.remove(_saved.keys.first);
      }
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 2), _flush);
    }
    if (p == null) return;
    // Bir nechta natija ketma-ket kelsa — xarita bir marta qayta chiziladi.
    _notify ??= Timer(const Duration(milliseconds: 300), () {
      _notify = null;
      if (!_disposed) onUpdate();
    });
  }

  static double _len(List<LatLng> path) {
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += distanceMeters(
        path[i - 1].lat,
        path[i - 1].lng,
        path[i].lat,
        path[i].lng,
      );
    }
    return total;
  }

  /// Bir rejim (avto/piyoda) bo'yicha Yandex bergan hamma variantlar —
  /// uchlari kesilgan, bino ichidagi nuqtaga tortilgan to'g'ri ulovchi va
  /// burchakdagi ortiqcha chiziqlar olingan holda.
  Future<List<List<LatLng>>> _candidates(
    List<RequestPoint> points,
    LatLng pa,
    LatLng pb,
    bool car,
  ) async {
    List<List<Point>> geometries;
    if (car) {
      final (session, result) = await YandexDriving.requestRoutes(
        points: points,
        drivingOptions: const DrivingOptions(routesCount: 3),
      );
      try {
        final r = await result.timeout(const Duration(seconds: 15));
        geometries =
            r.routes?.map((e) => e.geometry.points).toList() ?? const [];
      } finally {
        unawaited(session.close());
      }
    } else {
      final (session, result) = await YandexPedestrian.requestRoutes(
        points: points,
        fitnessOptions: const FitnessOptions(
          avoidSteep: false,
          avoidStairs: false,
        ),
        timeOptions: const TimeOptions(),
      );
      try {
        final r = await result.timeout(const Duration(seconds: 15));
        geometries =
            r.routes?.map((e) => e.geometry.points).toList() ?? const [];
      } finally {
        unawaited(session.close());
      }
    }
    return [
      for (final g in geometries)
        removeSpurs(
          dropEndConnectors(
            trimToEnds(
              [for (final p in g) (lat: p.latitude, lng: p.longitude)],
              pa,
              pb,
            ),
            pa,
            pb,
          ),
        ),
    ];
  }

  static List<LatLng>? _shortest(
    Iterable<List<LatLng>> paths,
    bool Function(List<LatLng>) ok,
  ) {
    List<LatLng>? best;
    var bestLen = double.infinity;
    for (final p in paths) {
      if (!ok(p)) continue;
      final l = _len(p);
      if (l < bestLen) {
        bestLen = l;
        best = p;
      }
    }
    return best;
  }

  Future<List<LatLng>?> _request(TimedPoint a0, TimedPoint b0, bool car) async {
    // Bino ichidagi nuqta (to'xtash markazi) — eshik oldiga suriladi: yo'l
    // shu yerdan boshlanadi / tugaydi, marshrutlovchi xato bermaydi.
    final oa = buildings.outside((lat: a0.lat, lng: a0.lng));
    final ob = buildings.outside((lat: b0.lat, lng: b0.lng));
    final a = (lat: oa.lat, lng: oa.lng, time: a0.time);
    final b = (lat: ob.lat, lng: ob.lng, time: b0.time);
    final points = [
      RequestPoint(
        point: Point(latitude: a.lat, longitude: a.lng),
        requestPointType: RequestPointType.wayPoint,
      ),
      RequestPoint(
        point: Point(latitude: b.lat, longitude: b.lng),
        requestPointType: RequestPointType.wayPoint,
      ),
    ];
    final pa = (lat: a.lat, lng: a.lng), pb = (lat: b.lat, lng: b.lng);
    final elapsed = b.time.difference(a.time);
    bool strict(List<LatLng> p) =>
        plausibleStreetPath(p, pa, pb, elapsed: elapsed);
    bool loose(List<LatLng> p) => roadFallbackPath(p, pa, pb, elapsed: elapsed);

    var own = const <List<LatLng>>[];
    try {
      own = await _candidates(points, pa, pb, car);
    } catch (_) {}
    // Ikkala rejim ham so'raladi: piyoda yo'laklar (eng mayda yo'lchalar
    // ham) ko'pincha avto yo'ldan qisqa va xodim aynan shulardan yurgan.
    var other = const <List<LatLng>>[];
    try {
      other = await _candidates(points, pa, pb, !car);
    } catch (_) {}
    final all = [...own, ...other];
    // Qat'iy tekshiruvdan hech biri o'tmasa ham binolar ustidan to'g'ri
    // chiziq emas — eng yaqin ko'cha yo'li chiziladi.
    // Oxirgi zaxira — uzilish bo'lmasin: uchlari nuqtalarga yaqin har
    // qanday ko'cha yo'li.
    bool any(List<LatLng> p) =>
        p.length >= 2 &&
        distanceMeters(p.first.lat, p.first.lng, pa.lat, pa.lng) <= 60 &&
        distanceMeters(p.last.lat, p.last.lng, pb.lat, pb.lng) <= 60;
    if (!buildings.isReady) {
      return _shortest(all, strict) ??
          _shortest(all, loose) ??
          _shortest(all, any);
    }
    // Avval binolar ustidan o'tmaydigan variantlar. Yandex yo'li OSM bino
    // konturiga bir necha metr "kirib" qolishi mumkin (ikki xarita farqi) —
    // keyin yumshoqroq chegara, oxirida baribir ko'cha yo'li: u to'g'ri
    // chiziqdan (bino ustidan) yaxshiroq va uzilish qoldirmaydi.
    bool clean(List<LatLng> p) => buildings.isClean(p);
    bool nearlyClean(List<LatLng> p) => buildings.isClean(p, toleranceM: 15);
    return _shortest(all, (p) => strict(p) && clean(p)) ??
        _shortest(all, (p) => loose(p) && clean(p)) ??
        _shortest(all, (p) => strict(p) && nearlyClean(p)) ??
        _shortest(all, (p) => loose(p) && nearlyClean(p)) ??
        _shortest(all, (p) => any(p) && nearlyClean(p)) ??
        _shortest(all, strict) ??
        _shortest(all, loose) ??
        _shortest(all, any);
  }

  /// Navbatdagi va jarayondagi hamma so'rovlar tugaguncha kutadi.
  Future<void> whenIdle() async {
    while (!_disposed && (_inFlight > 0 || _queue.isNotEmpty)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _loadSaved() async {
    final store = walkStore;
    if (store == null) return;
    try {
      final saved = await store.load();
      if (_disposed) return;
      for (final e in saved.entries) {
        _saved[e.key] = e.value;
        // Shu sessiyada yangi kelgan natija ustun.
        _cache.putIfAbsent(e.key, () => e.value.isEmpty ? null : e.value);
      }
      if (saved.isNotEmpty) _version++;
    } catch (e) {
      debugPrint('🚶 [PIYODA] saqlangan yo\'llar o\'qilmadi: $e');
    }
  }

  void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final store = walkStore;
    if (store == null) return;
    unawaited(
      store.save(_saved).catchError((Object e) {
        debugPrint('🚶 [PIYODA] yo\'llar saqlanmadi: $e');
      }),
    );
  }

  void dispose() {
    _disposed = true;
    _notify?.cancel();
    _queue.clear();
    // Kutayotgan natijalar yo'qolmasin.
    if (_saveTimer != null) _flush();
  }
}

/// Piyoda marshrut variantlari: [points] dan o'tadigan yo'llar (boshi va
/// oxiri — manzil, o'rtadagilari — o'tish nuqtalari).
typedef WalkRouteRequester =
    Future<List<List<LatLng>>> Function(List<LatLng> points);

Future<List<List<LatLng>>> _yandexWalkRoutes(List<LatLng> points) async {
  final (session, result) = await YandexPedestrian.requestRoutes(
    points: [
      for (var i = 0; i < points.length; i++)
        RequestPoint(
          point: Point(latitude: points[i].lat, longitude: points[i].lng),
          requestPointType: i == 0 || i == points.length - 1
              ? RequestPointType.wayPoint
              : RequestPointType.viaPoint,
        ),
    ],
    fitnessOptions: const FitnessOptions(avoidSteep: false, avoidStairs: false),
    timeOptions: const TimeOptions(),
  );
  try {
    final r = await result.timeout(const Duration(seconds: 15));
    return [
      for (final route in r.routes ?? const <MasstransitRoute>[])
        [
          for (final p in route.geometry.points)
            (lat: p.latitude, lng: p.longitude),
        ],
    ];
  } finally {
    unawaited(session.close());
  }
}
