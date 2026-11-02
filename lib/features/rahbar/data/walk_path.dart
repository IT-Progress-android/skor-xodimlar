import 'dart:math' as math;

import 'package:skore_hodimlar/features/rahbar/data/building_index.dart'
    show LatLng;
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';

/// Piyoda yurish chizig'i — yo'laklar bo'ylab, silliq (Yandex Go'dagi kabi).
///
/// Xom GPS izi piyodada 5–20 m "titraydi": to'g'ridan chizilsa chiziq
/// qaltiraydi. Shuning uchun:
/// 1. [smoothWalkTrack] — vaqt bo'yicha Gauss silliqlash (titrash ketadi,
///    burilishlar qoladi);
/// 2. [walkAnchors] — silliq izdan tayanch nuqtalar (burilishlar + har
///    [walkMaxAnchorGapM] m da bitta);
/// 3. [walkChunks] — tayanchlar Yandex piyoda marshrutlovchisiga bir so'rovda
///    (boshi/oxiri `wayPoint`, o'rtasi `viaPoint`) beriladi: marshrut
///    yo'laklar, hovli, bog' yo'lchalari bo'ylab **bitta uzluksiz** yo'l
///    bo'ladi (juft-juft so'rovlardagi ulanish zigzaglari yo'q);
/// 4. [acceptWalkMatch] — yo'l haqiqiy izga mos kelmasa (boshqa ko'chadan
///    aylanib ketgan) rad etiladi, o'rniga silliqlangan iz chiziladi;
/// 5. [stitchWalkParts] + [roundCorners] — bo'laklar ulanadi, ulanishdagi
///    dumchalar kesiladi, burchaklar biroz yumaloqlanadi.

/// Silliqlash oynasi (Gauss sigma). Piyoda ~1,3 m/s — 4 s ≈ 5 m.
const walkSmoothSigma = Duration(seconds: 4);

/// Tayanchlar uchun Douglas–Peucker chegarasi (metr): bundan kichik
/// chetlanish burilish emas. GPS xatosidan kichik bo'lsa tayanchlar
/// yonma-yon ikki yo'lakka navbat bilan tushib, yo'l ular orasida zigzag
/// qiladi.
const walkAnchorToleranceM = 12.0;

/// Tayanchlar orasi shundan kam bo'lmasin (ulanishda dumcha chiqmasin).
const walkMinAnchorGapM = 15.0;

/// To'g'ri qismda ham shu masofada tayanch qo'yiladi — marshrutlovchi
/// parallel ko'chaga o'tib ketmasin.
const walkMaxAnchorGapM = 80.0;

/// Bitta so'rovdagi nuqtalar soni (2 ta `wayPoint` + `viaPoint`lar).
const walkChunkSize = 12;

/// Haqiqiy nuqta yo'ldan shundan uzoq bo'lsa — mos emas (GPS xatosi
/// chegarasi).
const walkMatchToleranceM = 25.0;

/// Nuqtalarning kamida shuncha qismi yo'lga yaqin bo'lishi kerak.
const walkMatchCoverage = 0.85;

/// Yo'lning har bir joyi silliq izdan shundan uzoq bo'lmasin — xodim
/// bormagan joydan (bino orqasidan, yon yo'lakdan) aylanib o'tmasin. Bino yonida GPS
/// 30–40 m adashadi — undan kichik chegara to'g'ri yo'lakni ham rad etadi.
const walkMaxOffTrackM = 45.0;

/// Burchak yumaloqlash radiusi (metr) — chiziq yo'lakdan chiqmaydigan darajada.
const walkCornerRadiusM = 5.0;

LatLng _ll(TimedPoint p) => (lat: p.lat, lng: p.lng);

double _d(LatLng a, LatLng b) => distanceMeters(a.lat, a.lng, b.lat, b.lng);

double walkLength(List<LatLng> l) {
  var t = 0.0;
  for (var i = 1; i < l.length; i++) {
    t += _d(l[i - 1], l[i]);
  }
  return t;
}

/// Vaqt bo'yicha Gauss silliqlash: har nuqta ±3σ ichidagi qo'shnilarning
/// og'irlikli o'rtachasi. Uchlari o'zgarmaydi (chiziq to'xtash joyidan
/// boshlanadi). Nuqtalar siyrak bo'lsa (σ dan ko'p oraliq) deyarli
/// o'zgarmaydi.
List<TimedPoint> smoothWalkTrack(
  List<TimedPoint> points, {
  Duration sigma = walkSmoothSigma,
}) {
  if (points.length < 3) return [...points];
  final s = sigma.inMilliseconds / 1000;
  if (s <= 0) return [...points];
  final reach = 3 * s;
  final out = <TimedPoint>[points.first];
  var lo = 0;
  for (var i = 1; i < points.length - 1; i++) {
    final t = points[i].time;
    while (lo < i &&
        t.difference(points[lo].time).inMilliseconds / 1000 > reach) {
      lo++;
    }
    var w = 0.0, lat = 0.0, lng = 0.0;
    for (var k = lo; k < points.length; k++) {
      final dt = points[k].time.difference(t).inMilliseconds / 1000;
      if (dt > reach) break;
      final wk = math.exp(-(dt * dt) / (2 * s * s));
      w += wk;
      lat += points[k].lat * wk;
      lng += points[k].lng * wk;
    }
    out.add((lat: lat / w, lng: lng / w, time: t));
  }
  out.add(points.last);
  return out;
}

/// Douglas–Peucker (metrda) — saqlanadigan indekslar.
List<int> _dpKeep(List<TimedPoint> pts, double tol) {
  final keep = List<bool>.filled(pts.length, false);
  keep[0] = keep[pts.length - 1] = true;
  final kx = math.cos(pts.first.lat * math.pi / 180) * 111320;
  const ky = 111320.0;
  final stack = <(int, int)>[(0, pts.length - 1)];
  while (stack.isNotEmpty) {
    final (i, j) = stack.removeLast();
    if (j - i < 2) continue;
    final a = pts[i], b = pts[j];
    final bx = (b.lng - a.lng) * kx, by = (b.lat - a.lat) * ky;
    final len2 = bx * bx + by * by;
    var maxDev = -1.0;
    var k = i + 1;
    for (var m = i + 1; m < j; m++) {
      final px = (pts[m].lng - a.lng) * kx, py = (pts[m].lat - a.lat) * ky;
      final t = len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
      final dx = px - bx * t, dy = py - by * t;
      final dev = math.sqrt(dx * dx + dy * dy);
      if (dev > maxDev) {
        maxDev = dev;
        k = m;
      }
    }
    if (maxDev <= tol) continue;
    keep[k] = true;
    stack
      ..add((i, k))
      ..add((k, j));
  }
  return [
    for (var i = 0; i < pts.length; i++)
      if (keep[i]) i,
  ];
}

/// Marshrutlovchi uchun tayanch nuqtalar: burilishlar (Douglas–Peucker),
/// bir-biridan kamida [walkMinAnchorGapM], ko'pi bilan [walkMaxAnchorGapM]
/// (oraliqqa izdagi nuqta qo'shiladi). Uchlari doim qoladi.
List<TimedPoint> walkAnchors(List<TimedPoint> smoothed) {
  if (smoothed.length < 2) return [...smoothed];
  final idx = _dpKeep(smoothed, walkAnchorToleranceM);
  // Uzun to'g'ri qismlarga oraliq tayanchlar.
  final dense = <int>[idx.first];
  for (var n = 1; n < idx.length; n++) {
    final from = dense.last, to = idx[n];
    var last = from;
    var run = 0.0;
    for (var k = from + 1; k < to; k++) {
      run += _d(_ll(smoothed[k - 1]), _ll(smoothed[k]));
      if (run >= walkMaxAnchorGapM) {
        dense.add(k);
        last = k;
        run = 0;
      }
    }
    if (last != to) dense.add(to);
  }
  // Juda yaqinlari tashlanadi (oxirgisi doim qoladi).
  final out = <TimedPoint>[smoothed[dense.first]];
  for (var n = 1; n < dense.length; n++) {
    final p = smoothed[dense[n]];
    final isLast = n == dense.length - 1;
    if (_d(_ll(out.last), _ll(p)) < walkMinAnchorGapM) {
      if (isLast && out.length > 1) {
        out[out.length - 1] = p;
      } else if (isLast) {
        out.add(p);
      }
      continue;
    }
    out.add(p);
  }
  return out;
}

/// Tayanchlarni so'rovlarga bo'ladi: har bo'lak ko'pi bilan [size] nuqta,
/// qo'shni bo'laklar bitta umumiy nuqtada tutashadi.
List<List<TimedPoint>> walkChunks(
  List<TimedPoint> anchors, {
  int size = walkChunkSize,
}) {
  if (anchors.length < 2) return const [];
  final out = <List<TimedPoint>>[];
  var start = 0;
  while (start < anchors.length - 1) {
    final end = math.min(start + size - 1, anchors.length - 1);
    out.add(anchors.sublist(start, end + 1));
    start = end;
  }
  return out;
}

/// [p] dan [line] gacha eng qisqa masofa (metr).
double distanceToLine(LatLng p, List<LatLng> line) {
  if (line.isEmpty) return double.infinity;
  final kx = math.cos(p.lat * math.pi / 180) * 111320;
  const ky = 111320.0;
  var best = double.infinity;
  for (var i = 0; i < line.length; i++) {
    final a = line[i];
    final b = i + 1 < line.length ? line[i + 1] : a;
    final ax = (a.lng - p.lng) * kx, ay = (a.lat - p.lat) * ky;
    final bx = (b.lng - p.lng) * kx, by = (b.lat - p.lat) * ky;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
    final qx = ax + dx * t, qy = ay + dy * t;
    final d = math.sqrt(qx * qx + qy * qy);
    if (d < best) best = d;
  }
  return best;
}

/// Marshrutlovchi bergan piyoda yo'li haqiqiy izga mosmi:
/// - uchlari izning uchlariga yaqin (≤ 40 m);
/// - nuqtalarning kamida [walkMatchCoverage] qismi yo'ldan ≤
///   [walkMatchToleranceM];
/// - yo'l silliq izdan ko'p uzun emas (≤ 1,4× + 40 m) — boshqa ko'chadan
///   aylanib o'tmagan.
bool acceptWalkMatch(List<LatLng> path, List<TimedPoint> raw) =>
    walkMatchProblem(path, raw) == null;

/// [acceptWalkMatch] ning sababi: mos bo'lsa `null`, aks holda nima
/// buzilgani (log uchun).
String? walkMatchProblem(List<LatLng> path, List<TimedPoint> raw) {
  if (path.length < 2 || raw.isEmpty) return 'bo\'sh';
  final ds = _d(path.first, _ll(raw.first)), de = _d(path.last, _ll(raw.last));
  if (ds > 40 || de > 40) {
    return 'uchlari uzoq (${ds.round()} / ${de.round()} m)';
  }
  var near = 0;
  for (final p in raw) {
    if (distanceToLine(_ll(p), path) <= walkMatchToleranceM) near++;
  }
  final coverage = near / raw.length;
  if (coverage < walkMatchCoverage) {
    return 'qamrov ${(coverage * 100).round()}%';
  }
  final track = [for (final p in smoothWalkTrack(raw)) _ll(p)];
  final off = maxOffTrack(path, track);
  if (off > walkMaxOffTrackM) return 'izdan chetda (${off.round()} m)';
  final rawLen = walkLength(track);
  final len = walkLength(path);
  if (len > rawLen * 1.4 + 40) {
    return 'uzun (${len.round()} m, iz ${rawLen.round()} m)';
  }
  return null;
}

/// [path] ning [track] dan eng uzoq joyi (metr): yo'l har [step] m da
/// tekshiriladi (uzun kesma o'rtasi ham).
double maxOffTrack(List<LatLng> path, List<LatLng> track, {double step = 5}) {
  if (path.isEmpty || track.isEmpty) return double.infinity;
  var worst = distanceToLine(path.first, track);
  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1], b = path[i];
    final n = math.max(1, (_d(a, b) / step).ceil());
    for (var k = 1; k <= n; k++) {
      final t = k / n;
      final q = (
        lat: a.lat + (b.lat - a.lat) * t,
        lng: a.lng + (b.lng - a.lng) * t,
      );
      final d = distanceToLine(q, track);
      if (d > worst) worst = d;
    }
  }
  return worst;
}

/// Xodim bormagan "o'simta"larni kesadi: chiziqning [i]..[j] qismi GPS
/// izidan ([track]) [offTrack] m dan uzoqqa chiqib ketgan, ikki uchi esa
/// yaqin ([maxChord] m ichida) va ularni tutashtiruvchi to'g'ri chiziq izga
/// yaqin bo'lsa — o'sha qism to'g'ri chiziq bilan almashtiriladi. Izga mos
/// burilishlar (bino atrofidan aylanish) o'zgarmaydi: ularda GPS ham
/// chiziq bilan birga aylanadi.
List<LatLng> removeNotches(
  List<LatLng> line,
  List<LatLng> track, {
  double offTrack = 12,
  double maxChord = 40,
  double maxLen = 150,
}) {
  if (line.length < 3 || track.length < 2) return line;
  final off = [for (final p in line) distanceToLine(p, track)];
  final out = <LatLng>[];
  var i = 0;
  while (i < line.length) {
    out.add(line[i]);
    var cut = -1;
    var len = 0.0, worst = 0.0;
    for (var j = i + 1; j < line.length; j++) {
      len += _d(line[j - 1], line[j]);
      if (len > maxLen) break;
      if (off[j - 1] > worst && j - 1 > i) worst = off[j - 1];
      if (worst <= offTrack || off[j] > offTrack) continue;
      final chord = _d(line[i], line[j]);
      if (chord > maxChord || len < chord * 1.3 + 5) continue;
      if (maxOffTrack([line[i], line[j]], track) <= offTrack) cut = j;
    }
    i = cut > 0 ? cut : i + 1;
  }
  return out;
}

/// Ulanish nuqtasi [j] atrofidagi borib-qaytgan dumchani kesadi: [j] dan
/// orqaga [i] va oldinga [m] nuqtalar bir-biriga ≤ 5 m va oradagi yo'l
/// ≤ [maxLen] m bo'lsa — [i]+1..[m] olib tashlanadi.
List<LatLng> _cutSpurAt(List<LatLng> line, int j, {double maxLen = 60}) {
  var cutI = -1, cutM = -1;
  var back = 0.0;
  for (var i = j - 1; i >= 0; i--) {
    back += _d(line[i], line[i + 1]);
    if (back > maxLen) break;
    var fwd = 0.0;
    for (var m = j + 1; m < line.length; m++) {
      fwd += _d(line[m - 1], line[m]);
      if (back + fwd > maxLen) break;
      if (_d(line[i], line[m]) <= 5) {
        cutI = i;
        cutM = m;
      }
    }
  }
  if (cutI < 0) return line;
  return [...line.sublist(0, cutI + 1), ...line.sublist(cutM + 1)];
}

/// Butun chiziq bo'ylab borib-qaytgan dumchalarni kesadi: `viaPoint`
/// yo'lakdan biroz chetda bo'lsa marshrutlovchi unga kirib, o'sha yo'ldan
/// qaytadi — chiziq uzayadi va "tikan" chiqadi. Xodim [maxLen] m ichida
/// o'sha joyga qaytgan bo'lsa ham bu to'xtash (u alohida ko'rsatiladi).
List<LatLng> removeWalkSpurs(List<LatLng> line, {double maxLen = 80}) {
  var out = line;
  for (var j = 1; j < out.length - 1; j++) {
    out = _cutSpurAt(out, j, maxLen: maxLen);
  }
  return out;
}

/// Bo'laklarni bitta chiziqqa ulaydi: tutashgan uchdagi takror nuqta
/// tashlanadi, uzoq bo'lsa to'g'ri ulanadi; ulanish joyidagi dumcha
/// (via-nuqta yon yo'lakka tushgani) kesiladi.
List<LatLng> stitchWalkParts(List<List<LatLng>> parts) {
  var out = <LatLng>[];
  for (final part in parts) {
    if (part.isEmpty) continue;
    if (out.isEmpty) {
      out.addAll(part);
      continue;
    }
    final joint = out.length - 1;
    out.addAll(_d(out.last, part.first) < 1 ? part.skip(1) : part);
    out = _cutSpurAt(out, joint);
  }
  return out;
}

/// Burchaklarni yumaloqlaydi: har burilish [radius] m oldin va keyin
/// boshlanadigan kvadratik egri chiziq bilan almashtiriladi. Chiziq
/// burchakdan ko'pi bilan ~radius/2 chetga chiqadi — yo'lakda qoladi.
List<LatLng> roundCorners(
  List<LatLng> line, {
  double radius = walkCornerRadiusM,
  int steps = 4,
}) {
  if (line.length < 3) return [...line];
  LatLng lerp(LatLng a, LatLng b, double t) =>
      (lat: a.lat + (b.lat - a.lat) * t, lng: a.lng + (b.lng - a.lng) * t);
  final out = <LatLng>[line.first];
  for (var i = 1; i < line.length - 1; i++) {
    final a = line[i - 1], b = line[i], c = line[i + 1];
    final ab = _d(a, b), bc = _d(b, c);
    if (ab < 0.5 || bc < 0.5) {
      out.add(b);
      continue;
    }
    // Qo'shni burchaklar bir-birining egrisiga kirmasin.
    final r = math.min(radius, math.min(ab, bc) / 2.5);
    final p0 = lerp(b, a, r / ab), p2 = lerp(b, c, r / bc);
    out.add(p0);
    for (var s = 1; s < steps; s++) {
      final t = s / steps;
      final u = 1 - t;
      out.add((
        lat: u * u * p0.lat + 2 * u * t * b.lat + t * t * p2.lat,
        lng: u * u * p0.lng + 2 * u * t * b.lng + t * t * p2.lng,
      ));
    }
    out.add(p2);
  }
  out.add(line.last);
  return out;
}

/// Chiziqni har [step] m da nuqtali qiladi (proyeksiya uchun).
List<LatLng> _densify(List<LatLng> line, double step) {
  if (line.length < 2) return [...line];
  final out = <LatLng>[line.first];
  for (var i = 1; i < line.length; i++) {
    final a = line[i - 1], b = line[i];
    final n = math.max(1, (_d(a, b) / step).ceil());
    for (var k = 1; k <= n; k++) {
      final t = k / n;
      out.add((
        lat: a.lat + (b.lat - a.lat) * t,
        lng: a.lng + (b.lng - a.lng) * t,
      ));
    }
  }
  return out;
}

/// Chiziqdagi joy: [line] — ro'yxatdagi indeksi, [pos] — kesma indeksi +
/// kesma ichidagi ulush (0..1).
typedef _Hit = ({LatLng p, double d, int line, double pos});

/// [p] ning [lines] dagi eng yaqin nuqtasi va masofasi.
_Hit? _nearest(LatLng p, List<List<LatLng>> lines) {
  final kx = math.cos(p.lat * math.pi / 180) * 111320;
  const ky = 111320.0;
  LatLng? best;
  var bestD = double.infinity;
  var bestLine = -1;
  var bestPos = 0.0;
  for (var li = 0; li < lines.length; li++) {
    final line = lines[li];
    for (var i = 0; i + 1 < line.length; i++) {
      final a = line[i], b = line[i + 1];
      final ax = (a.lng - p.lng) * kx, ay = (a.lat - p.lat) * ky;
      final bx = (b.lng - p.lng) * kx, by = (b.lat - p.lat) * ky;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final qx = ax + dx * t, qy = ay + dy * t;
      final d = math.sqrt(qx * qx + qy * qy);
      if (d < bestD) {
        bestD = d;
        bestLine = li;
        bestPos = i + t;
        best = (
          lat: a.lat + (b.lat - a.lat) * t,
          lng: a.lng + (b.lng - a.lng) * t,
        );
      }
    }
  }
  return best == null
      ? null
      : (p: best, d: bestD, line: bestLine, pos: bestPos);
}

/// [line] ning [from] va [to] (kesma pozitsiyalari) orasidagi uchlari —
/// [from] dan [to] tomonga tartibda.
List<LatLng> _between(List<LatLng> line, double from, double to) {
  final lo = math.min(from, to), hi = math.max(from, to);
  final inner = [
    for (var v = lo.floor() + 1; v < hi && v < line.length; v++) line[v],
  ];
  return from <= to ? inner : inner.reversed.toList();
}

/// Bir yo'ldan borib-qaytish bitta chiziq bo'lib chizilsin: [lines] (vaqt
/// tartibida) ning har bir joyi oldin chizilgan chiziqdan (yoki o'zining
/// [selfGap] m dan oldingi qismidan) [maxDist] m ichida bo'lsa — o'sha
/// chiziq ustiga qo'yiladi. Yonma-yon ikki parallel chiziq o'rniga bitta
/// chiziq qoladi. Uzoqroq (alohida yo'l) qismlar o'zgarmaydi; birinchi
/// chiziq ham o'zgarmaydi (o'zi bilan ustma-ust tushganidan tashqari).
///
/// Chiziqdan chiqib, [loopLen] m ichida yana unga qaytgan "ilmoq" (yoki
/// chiziq oxiridagi [hookLen] m gacha "ilgak") [loopDist] m dan uzoqqa
/// ketmagan bo'lsa — u ham chiziq ustiga qo'yiladi.
List<List<LatLng>> mergeParallelWalks(
  List<List<LatLng>> lines, {
  double maxDist = 20,
  double selfGap = 60,
  double step = 6,
  double loopLen = 100,
  double loopDist = 40,
  double hookLen = 30,
}) {
  final out = <List<LatLng>>[];
  for (final line in lines) {
    if (line.length < 2) {
      out.add(line);
      continue;
    }
    final dense = _densify(line, step);
    final res = <LatLng>[];
    // [res] ning yig'ma uzunligi — o'z oldingi qismini ajratish uchun.
    final cum = <double>[];
    // Har nuqta: chiziqqa qo'yildimi, qo'yilmagan bo'lsa — eng yaqin joy.
    final snapped = <bool>[];
    final hits = <_Hit?>[];
    var changed = false;
    for (final p in dense) {
      final run = res.isEmpty ? 0.0 : cum.last + _d(res.last, p);
      var own = 0;
      while (own < cum.length && cum[own] <= run - selfGap) {
        own++;
      }
      final hit = _nearest(p, [...out, if (own >= 2) res.sublist(0, own)]);
      final q = hit != null && hit.d <= maxDist ? hit.p : p;
      if (!identical(q, p)) changed = true;
      snapped.add(!identical(q, p));
      hits.add(hit);
      cum.add(res.isEmpty ? 0.0 : cum.last + _d(res.last, q));
      res.add(q);
    }
    // Ilmoq va ilgaklar: qo'yilmagan qisqa, yaqin qismlar.
    var i = 0;
    while (i < res.length) {
      if (snapped[i]) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < res.length && !snapped[j + 1]) {
        j++;
      }
      final before = i > 0, after = j + 1 < res.length;
      final len = cum[j] - cum[i];
      final limit = before && after ? loopLen : hookLen;
      final close = [
        for (var k = i; k <= j; k++) hits[k],
      ].every((h) => h != null && h.d <= loopDist);
      if ((before || after) && len <= limit && close) {
        for (var k = i; k <= j; k++) {
          res[k] = hits[k]!.p;
          snapped[k] = true;
        }
        changed = true;
      }
      i = j + 1;
    }
    if (!changed) {
      out.add(line);
      continue;
    }
    // Ikki qo'shni nuqta bir chiziqning turli joylariga qo'yilgan bo'lsa —
    // oralig'i to'g'ri vatar emas, o'sha chiziq bo'ylab (aks holda vatar va
    // chiziq bukilishi kichik "D" ilmoq hosil qiladi).
    final follow = <LatLng>[];
    for (var k = 0; k < res.length; k++) {
      follow.add(res[k]);
      if (k + 1 == res.length || !snapped[k] || !snapped[k + 1]) continue;
      final a = hits[k]!, b = hits[k + 1]!;
      if (a.line != b.line || a.line >= out.length) continue;
      final path = _between(out[a.line], a.pos, b.pos);
      if (path.isEmpty) continue;
      final chord = _d(res[k], res[k + 1]);
      final along = walkLength([res[k], ...path, res[k + 1]]);
      if (along <= math.max(chord * 2.5, chord + 30) && along <= 100) {
        follow.addAll(path);
      }
    }
    out.add(removeWalkSpurs(_dropDuplicates(follow)));
  }
  return out;
}

/// Ketma-ket 0,5 m dan yaqin nuqtalar bittaga.
List<LatLng> _dropDuplicates(List<LatLng> line) {
  final out = <LatLng>[];
  for (final p in line) {
    if (out.isEmpty || _d(out.last, p) >= 0.5) out.add(p);
  }
  if (out.length == 1 && line.length > 1) out.add(line.last);
  return out;
}
