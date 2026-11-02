import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef LatLng = ({double lat, double lng});

/// Bino konturlari (OpenStreetMap, Overpass API) — chiziq hech qachon bino
/// ustidan o'tmasligi uchun. Katta yo'l, xiyobon, hovli — taqiqlanmaydi.
///
/// Hudud 0.01° (~1 km) li kataklarga bo'linib yuklanadi va xotirada
/// saqlanadi, telefonda ham (30 kun) — keyingi safar internetsiz tayyor. Overpass'ga faqat katak chegarasi
/// yuboriladi — xodim, nuqta yoki token emas.
class BuildingIndex {
  BuildingIndex._();

  static final BuildingIndex instance = BuildingIndex._();

  static const _tile = 0.01; // ~1 km: so'rov yengil, server kam rad etadi
  static const _diskTtl = Duration(days: 30);
  static const _cell = 0.0005; // ~50 m qidiruv katagi
  /// Asosiy server ba'zan band (502/504) — bir marta qayta urinish, keyin
  /// zaxira server.
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Alohida Dio: ilovaning auth sarlavhalari tashqi xizmatga ketmasin.
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 45),
      // User-Agent'siz so'rovni Overpass rad etadi (406).
      headers: {'User-Agent': 'SkorXodimlar/1.0 (uz.skor.hodimlar)'},
    ),
  );

  final _polygons = <List<LatLng>>[];
  final _boxes = <({double s, double w, double n, double e})>[];
  final _grid = <int, List<int>>{};
  final _loadedTiles = <int>{};
  final _seenWays = <int>{};
  final _loading = <int, Future<void>>{};

  /// Hech bo'lmasa bitta katak yuklanganmi (aks holda tekshiruv yo'q).
  bool get isReady => _loadedTiles.isNotEmpty;

  static int _tileKey(int ty, int tx) => ty * 100000 + tx;
  static int _cellKey(int cy, int cx) => cy * 1000000 + cx;

  /// [points] atrofidagi (+[padM]) hudud binolari yuklanmagan bo'lsa
  /// yuklaydi. Xato bo'lsa jim o'tadi (keyingi chaqiruvda qayta urinadi).
  Future<void> ensure(Iterable<LatLng> points, {double padM = 150}) async {
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final p in points) {
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
    }
    if (s > n) return;
    final padLat = padM / 111320;
    final padLng = padM / (111320 * math.cos(s * math.pi / 180));
    final ty0 = ((s - padLat) / _tile).floor(),
        ty1 = ((n + padLat) / _tile).floor();
    final tx0 = ((w - padLng) / _tile).floor(),
        tx1 = ((e + padLng) / _tile).floor();
    // Butun shahar bo'ylab yurgan kun ham: ko'pi bilan 144 katak (~12×12 km).
    if ((ty1 - ty0 + 1) * (tx1 - tx0 + 1) > 144) return;
    final jobs = <Future<void>>[];
    for (var ty = ty0; ty <= ty1; ty++) {
      for (var tx = tx0; tx <= tx1; tx++) {
        final key = _tileKey(ty, tx);
        if (_loadedTiles.contains(key)) continue;
        jobs.add(
          _loading[key] ??= _loadTile(
            ty,
            tx,
          ).whenComplete(() => _loading.remove(key)),
        );
      }
    }
    await Future.wait(jobs);
  }

  Future<void> _loadTile(int ty, int tx) async {
    final s = ty * _tile, w = tx * _tile;
    final n = s + _tile, e = w + _tile;
    if (await _loadFromDisk(ty, tx)) return;
    final q =
        '[out:json][timeout:40];'
        'way["building"]($s,$w,$n,$e);'
        'out geom;';
    for (final url in _endpoints) {
      try {
        final res = await _dio.post<dynamic>(
          url,
          data: {'data': q},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        final data = res.data;
        final elements = data is Map ? data['elements'] : null;
        if (elements is! List) continue;
        final tilePolys = <List<LatLng>>[];
        for (final el in elements.whereType<Map<dynamic, dynamic>>()) {
          final id = el['id'];
          final geom = el['geometry'];
          if (id is! int || geom is! List || !_seenWays.add(id)) continue;
          final poly = <LatLng>[
            for (final g in geom.whereType<Map<dynamic, dynamic>>())
              if (g['lat'] is num && g['lon'] is num)
                (
                  lat: (g['lat'] as num).toDouble(),
                  lng: (g['lon'] as num).toDouble(),
                ),
          ];
          if (poly.length >= 4) {
            _add(poly);
            tilePolys.add(poly);
          }
        }
        _loadedTiles.add(_tileKey(ty, tx));
        unawaited(_saveToDisk(ty, tx, tilePolys));
        return;
      } catch (_) {}
    }
  }

  static Future<File> _file(int ty, int tx) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/buildings/${ty}_$tx.json');
  }

  Future<bool> _loadFromDisk(int ty, int tx) async {
    try {
      final f = await _file(ty, tx);
      if (!f.existsSync()) return false;
      if (DateTime.now().difference(f.lastModifiedSync()) > _diskTtl) {
        return false;
      }
      final data = jsonDecode(await f.readAsString());
      if (data is! List) return false;
      for (final flat in data.whereType<List<dynamic>>()) {
        final poly = <LatLng>[
          for (var i = 0; i + 1 < flat.length; i += 2)
            (
              lat: (flat[i] as num).toDouble(),
              lng: (flat[i + 1] as num).toDouble(),
            ),
        ];
        if (poly.length >= 4) _add(poly);
      }
      _loadedTiles.add(_tileKey(ty, tx));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToDisk(int ty, int tx, List<List<LatLng>> polys) async {
    try {
      final f = await _file(ty, tx);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        jsonEncode([
          for (final p in polys)
            [
              for (final q in p) ...[
                double.parse(q.lat.toStringAsFixed(6)),
                double.parse(q.lng.toStringAsFixed(6)),
              ],
            ],
        ]),
      );
    } catch (_) {}
  }

  void _add(List<LatLng> poly) {
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final p in poly) {
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
    }
    final i = _polygons.length;
    _polygons.add(poly);
    _boxes.add((s: s, w: w, n: n, e: e));
    for (var cy = (s / _cell).floor(); cy <= (n / _cell).floor(); cy++) {
      for (var cx = (w / _cell).floor(); cx <= (e / _cell).floor(); cx++) {
        (_grid[_cellKey(cy, cx)] ??= []).add(i);
      }
    }
  }

  /// Test uchun: konturni to'g'ridan-to'g'ri qo'shish.
  @visibleForTesting
  void addForTest(List<LatLng> poly) {
    _add(poly);
    _loadedTiles.add(-1);
  }

  @visibleForTesting
  void clearForTest() {
    _polygons.clear();
    _boxes.clear();
    _grid.clear();
    _loadedTiles.clear();
    _seenWays.clear();
  }

  Set<int> _candidates(LatLng a, LatLng b) {
    final out = <int>{};
    final s = math.min(a.lat, b.lat), n = math.max(a.lat, b.lat);
    final w = math.min(a.lng, b.lng), e = math.max(a.lng, b.lng);
    for (var cy = (s / _cell).floor(); cy <= (n / _cell).floor(); cy++) {
      for (var cx = (w / _cell).floor(); cx <= (e / _cell).floor(); cx++) {
        final l = _grid[_cellKey(cy, cx)];
        if (l != null) out.addAll(l);
      }
    }
    out.removeWhere((i) {
      final bx = _boxes[i];
      return bx.n < s || bx.s > n || bx.e < w || bx.w > e;
    });
    return out;
  }

  /// [a]→[b] kesmasining bino ichidagi qismlari (0..1 parametr oraliqlari).
  List<(double, double)> insideIntervals(LatLng a, LatLng b) {
    final kx = math.cos(a.lat * math.pi / 180);
    final ax = a.lng * kx, ay = a.lat;
    final dx = b.lng * kx - ax, dy = b.lat - ay;
    final out = <(double, double)>[];
    for (final i in _candidates(a, b)) {
      final poly = _polygons[i];
      final ts = <double>[0, 1];
      for (var k = 1; k < poly.length; k++) {
        final px = poly[k - 1].lng * kx, py = poly[k - 1].lat;
        final ex = poly[k].lng * kx - px, ey = poly[k].lat - py;
        final den = dx * ey - dy * ex;
        if (den == 0) continue;
        final t = ((px - ax) * ey - (py - ay) * ex) / den;
        final u = ((px - ax) * dy - (py - ay) * dx) / den;
        if (t > 0 && t < 1 && u >= 0 && u <= 1) ts.add(t);
      }
      ts.sort();
      for (var k = 1; k < ts.length; k++) {
        final t0 = ts[k - 1], t1 = ts[k];
        if (t1 - t0 < 1e-9) continue;
        final m = (t0 + t1) / 2;
        if (_inside(poly, ay + dy * m, (ax + dx * m) / kx)) {
          out.add((t0, t1));
        }
      }
    }
    out.sort((x, y) => x.$1.compareTo(y.$1));
    return out;
  }

  static bool _inside(List<LatLng> poly, double lat, double lng) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.lat > lat) != (b.lat > lat) &&
          lng < (b.lng - a.lng) * (lat - a.lat) / (b.lat - a.lat) + a.lng) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// [p] bino ichida bo'lsa — eng yaqin devordan [offsetM] m tashqaridagi
  /// nuqta (eshik oldi), aks holda [p] o'zi. Marshrutlovchi bino ichidagi
  /// nuqtaga yo'l bermaydi / xato qaytaradi.
  LatLng outside(LatLng p, {double offsetM = 3}) {
    if (!isReady) return p;
    for (final i in _candidates(p, p)) {
      final poly = _polygons[i];
      if (!_inside(poly, p.lat, p.lng)) continue;
      final kx = math.cos(p.lat * math.pi / 180);
      var best = p;
      var bestD = double.infinity;
      var nx = 0.0, ny = 0.0;
      for (var k = 1; k < poly.length; k++) {
        final ax = (poly[k - 1].lng - p.lng) * kx, ay = poly[k - 1].lat - p.lat;
        final bx = (poly[k].lng - p.lng) * kx, by = poly[k].lat - p.lat;
        final dx = bx - ax, dy = by - ay;
        final l2 = dx * dx + dy * dy;
        final t = l2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / l2).clamp(0.0, 1.0);
        final qx = ax + dx * t, qy = ay + dy * t;
        final d = qx * qx + qy * qy;
        if (d < bestD) {
          bestD = d;
          final n = math.sqrt(d);
          nx = n == 0 ? 0 : qx / n;
          ny = n == 0 ? 0 : qy / n;
          best = (lat: p.lat + qy, lng: p.lng + qx / kx);
        }
      }
      final step = offsetM / 111320;
      return (lat: best.lat + ny * step, lng: best.lng + nx * step / kx);
    }
    return p;
  }

  static double _meters(LatLng a, LatLng b) {
    final kx = math.cos(a.lat * math.pi / 180);
    final x = (b.lng - a.lng) * kx * 111320, y = (b.lat - a.lat) * 111320;
    return math.sqrt(x * x + y * y);
  }

  /// Kesma binoni [toleranceM] metrdan ko'p kesib o'tadimi (bino chetiga
  /// tegib o'tgan trotuar — GPS/xarita farqi — hisobga olinmaydi).
  bool crosses(LatLng a, LatLng b, {double toleranceM = 4}) {
    if (!isReady) return false;
    final len = _meters(a, b);
    for (final (t0, t1) in insideIntervals(a, b)) {
      if ((t1 - t0) * len > toleranceM) return true;
    }
    return false;
  }

  /// Butun chiziq binolar ustidan o'tmaydimi.
  bool isClean(List<LatLng> line, {double toleranceM = 4}) {
    for (var i = 1; i < line.length; i++) {
      if (crosses(line[i - 1], line[i], toleranceM: toleranceM)) return false;
    }
    return true;
  }

  /// Chiziqning bino ichidagi qismlari kesib tashlanadi: chiziq bino
  /// devori (eshik) oldida to'xtaydi va chiqqan joyidan davom etadi.
  List<List<LatLng>> clipOutside(List<LatLng> line, {double toleranceM = 4}) {
    if (!isReady || line.length < 2) return [line];
    final out = <List<LatLng>>[];
    var cur = <LatLng>[line.first];
    for (var i = 1; i < line.length; i++) {
      final a = line[i - 1], b = line[i];
      final len = _meters(a, b);
      final cuts = [
        for (final iv in insideIntervals(a, b))
          if ((iv.$2 - iv.$1) * len > toleranceM) iv,
      ];
      LatLng at(double t) =>
          (lat: a.lat + (b.lat - a.lat) * t, lng: a.lng + (b.lng - a.lng) * t);
      for (final (t0, t1) in cuts) {
        if (cur.isNotEmpty) cur.add(at(t0));
        if (cur.length >= 2) out.add(cur);
        cur = t1 < 1 - 1e-9 ? [at(t1)] : <LatLng>[];
      }
      if (cuts.isEmpty && cur.isEmpty) cur.add(a);
      if (cur.isNotEmpty) cur.add(b);
    }
    if (cur.length >= 2) out.add(cur);
    return out;
  }
}
