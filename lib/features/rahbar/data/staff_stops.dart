import 'dart:math' as math;

/// Xodim ish vaqtida biror joyda to'xtab turgan oraliq (xaritadagi metka).
///
/// Backend `/rahbar/lokatsiya/toxtashlar/{id}` dan keladi; u hali tayyor
/// bo'lmasa, [detectStaffStops] GPS nuqtalaridan shu yerning o'zida
/// hisoblaydi (u holda [nom], [manzil], [rasmUrl] bo'lmaydi).
class StaffStop {
  final double lat;
  final double lng;
  final DateTime from;
  final DateTime to;
  final String? nom;
  final String? manzil;
  final String? rasmUrl;

  const StaffStop({
    required this.lat,
    required this.lng,
    required this.from,
    required this.to,
    this.nom,
    this.manzil,
    this.rasmUrl,
  });

  Duration get duration => to.difference(from);

  /// `null` — yozuvda koordinata yoki vaqt yo'q.
  static StaffStop? fromJson(Map<String, dynamic> m, {DateTime? day}) {
    final lat = _toDouble(m['lat'] ?? m['latitude']);
    final lng = _toDouble(m['lng'] ?? m['longitude']);
    final from = _toTime(m['boshlanish'] ?? m['from'], day);
    final to = _toTime(m['tugash'] ?? m['to'], day);
    if (lat == 0.0 || lng == 0.0 || from == null || to == null) return null;
    return StaffStop(
      lat: lat,
      lng: lng,
      from: from,
      to: to,
      nom: _nonEmpty(m['nom'] ?? m['name']),
      manzil: _nonEmpty(m['manzil'] ?? m['address']),
      rasmUrl: _nonEmpty(m['rasm_url'] ?? m['photo_url']),
    );
  }
}

/// GPS nuqtasi (vaqti bilan).
typedef TimedPoint = ({double lat, double lng, DateTime time});

/// To'xtash metkasi: xodim [stopRadiusM] ichida kamida [stopMinDuration]
/// turgan joy (backend `/toxtashlar` bilan bir xil qoida). Undan qisqa
/// turish metka bo'lmaydi — faqat chiziq.
const stopRadiusM = 25.0;
const stopMinDuration = Duration(minutes: 10);

/// Ketma-ket nuqtalar [radiusM] ichida kamida [minDuration] tursa — bitta
/// to'xtash. Markaz har yangi nuqta bilan o'rtacha qiymatga suriladi, shuning
/// uchun GPS "sakrashi" bitta joyni ikkiga bo'lib yubormaydi.
List<StaffStop> detectStaffStops(
  List<TimedPoint> points, {
  double radiusM = stopRadiusM,
  Duration minDuration = stopMinDuration,
}) {
  final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
  final stops = <StaffStop>[];

  var i = 0;
  while (i < sorted.length) {
    var sumLat = sorted[i].lat;
    var sumLng = sorted[i].lng;
    var n = 1;
    var j = i + 1;
    while (j < sorted.length) {
      final p = sorted[j];
      if (distanceMeters(sumLat / n, sumLng / n, p.lat, p.lng) > radiusM) {
        break;
      }
      sumLat += p.lat;
      sumLng += p.lng;
      n++;
      j++;
    }
    final c = _trimWalking(sorted, i, j - 1, sumLat / n, sumLng / n, radiusM);
    final from = sorted[c.start].time;
    final to = sorted[c.end].time;
    if (c.n > 0 &&
        to.difference(from) >= minDuration &&
        isStationarySpan(sorted, c.start, c.end)) {
      stops.add(StaffStop(lat: c.lat, lng: c.lng, from: from, to: to));
      i = c.end + 1;
    } else {
      i++;
    }
  }
  return stops;
}

/// [sorted] ning [start]..[end] qismida xodim haqiqatan bir joyda turganmi.
///
/// Markaz bo'yicha radius yetarli emas: ko'chaning bir tomonidan borib,
/// burilib, ikkinchi tomonidan qaytgan odamning o'rtacha nuqtasi u bilan
/// birga 100 m ichida qoladi. Shuning uchun oraliq kamida [window] lik
/// bo'laklarga bo'linib, har birida siljish tezligi olinadi: turganda bu
/// GPS titrashi (2 daqiqada o'nlab metr), yurganda — piyoda ~150 m.
/// Vaqt bo'yicha medianasi [maxSpeed] dan oshsa — harakat. Uzoq bo'shliq
/// (server turgan joydagi titrashni tashlagan) o'z davomiyligi bilan
/// hisoblanadi.
///
/// [window] dan qisqa borib-qaytish (tor joyga kirib chiqish) bo'laklarda
/// ko'rinmaydi — shuning uchun nuqtalar zich ([denseGap] dan yaqin) bo'lgan
/// qismda ketma-ket qadamlar tezligi ham tekshiriladi: piyoda ~1,3 m/s,
/// turganda telefon filtri qadamlarni deyarli nolga tushiradi.
bool isStationarySpan(
  List<TimedPoint> sorted,
  int start,
  int end, {
  Duration window = const Duration(minutes: 2),
  double maxSpeed = 0.4,
  Duration denseGap = const Duration(seconds: 15),
  double maxStepSpeed = 0.8,
}) {
  final chunks = <(double, int)>[]; // (tezlik m/s, davomiylik s)
  var k = start;
  while (k < end) {
    final a = sorted[k];
    var m = k + 1;
    while (m < end && sorted[m].time.difference(a.time) < window) {
      m++;
    }
    final b = sorted[m];
    final sec = b.time.difference(a.time).inSeconds;
    if (sec > 0) {
      chunks.add((distanceMeters(a.lat, a.lng, b.lat, b.lng) / sec, sec));
    }
    k = m;
  }
  final chunkSpeed = _timeMedian(chunks);
  if (chunkSpeed != null && chunkSpeed > maxSpeed) return false;

  final steps = <(double, int)>[];
  for (var i = start; i < end; i++) {
    final a = sorted[i], b = sorted[i + 1];
    final sec = b.time.difference(a.time).inSeconds;
    if (sec <= 0 || sec > denseGap.inSeconds) continue;
    steps.add((distanceMeters(a.lat, a.lng, b.lat, b.lng) / sec, sec));
  }
  final total = sorted[end].time.difference(sorted[start].time).inSeconds;
  final dense = steps.fold<int>(0, (s, e) => s + e.$2);
  final stepSpeed = _timeMedian(steps);
  if (dense * 2 >= total && stepSpeed != null && stepSpeed > maxStepSpeed) {
    return false;
  }
  return true;
}

/// (qiymat, davomiylik) juftlari uchun vaqt bo'yicha mediana.
double? _timeMedian(List<(double, int)> samples) {
  if (samples.isEmpty) return null;
  final sorted = [...samples]..sort((x, y) => x.$1.compareTo(y.$1));
  final total = sorted.fold<int>(0, (s, e) => s + e.$2);
  var acc = 0;
  for (final (value, sec) in sorted) {
    acc += sec;
    if (acc * 2 >= total) return value;
  }
  return sorted.last.$1;
}

/// Turish oralig'i [start]..[end] ning boshi va oxiridan kelish/ketish
/// yurishi qirqiladi — aks holda markaz o'sha tomonga suriladi va chiziq
/// turish joyidan emas, ancha keyindan boshlanadi. Markaz qolgan
/// nuqtalardan qayta hisoblanadi ([radiusM] dan uzoq sakrashlarsiz).
({int start, int end, double lat, double lng, int n}) _trimWalking(
  List<TimedPoint> sorted,
  int start,
  int end,
  double centerLat,
  double centerLng,
  double radiusM,
) {
  var s = start, e = end;
  while (e > s && _walkingAt(sorted, s, e, e)) {
    e--;
  }
  while (s < e && _walkingAt(sorted, s, e, s)) {
    s++;
  }
  var lat = 0.0, lng = 0.0, n = 0;
  for (var k = s; k <= e; k++) {
    final q = sorted[k];
    if (distanceMeters(centerLat, centerLng, q.lat, q.lng) > radiusM) continue;
    lat += q.lat;
    lng += q.lng;
    n++;
  }
  return (
    start: s,
    end: e,
    lat: n == 0 ? centerLat : lat / n,
    lng: n == 0 ? centerLng : lng / n,
    n: n,
  );
}

/// [sorted] ning [start]..[end] chetidagi [k]-nuqtada xodim yuryaptimi:
/// shu oraliq ichida undan ~[window] oldingi (oxiri uchun) yoki keyingi
/// (boshi uchun) nuqtagacha tezlik [minSpeed] dan katta. Faqat zich izda
/// ([window] ichida kamida [minPoints] nuqta — yurganda telefon har necha
/// soniyada yuboradi): siyrak nuqtalardagi GPS titrashi yurish emas.
/// Solishtirish uchun nuqta [minSpan] dan yaqin bo'lsa ham — `false`.
bool _walkingAt(
  List<TimedPoint> sorted,
  int start,
  int end,
  int k, {
  Duration window = const Duration(seconds: 60),
  Duration minSpan = const Duration(seconds: 20),
  int minPoints = 4,
  double minSpeed = 0.6,
}) {
  final p = sorted[k];
  TimedPoint? q;
  var count = 0;
  if (k == end) {
    for (var j = k - 1; j >= start; j--) {
      if (p.time.difference(sorted[j].time) > window) break;
      q = sorted[j];
      count++;
    }
  } else {
    for (var j = k + 1; j <= end; j++) {
      if (sorted[j].time.difference(p.time) > window) break;
      q = sorted[j];
      count++;
    }
  }
  if (q == null || count < minPoints) return false;
  final sec = p.time.difference(q.time).inSeconds.abs();
  if (sec < minSpan.inSeconds) return false;
  return distanceMeters(p.lat, p.lng, q.lat, q.lng) / sec > minSpeed;
}

/// [points] dagi [from]..[to] oralig'i uchun [isStationarySpan].
bool isStationaryBetween(List<TimedPoint> points, DateTime from, DateTime to) {
  final span = [
    for (final p in points)
      if (!p.time.isBefore(from) && !p.time.isAfter(to)) p,
  ]..sort((a, b) => a.time.compareTo(b.time));
  return span.length < 2 || isStationarySpan(span, 0, span.length - 1);
}

/// Ikki nuqta orasidagi masofa (metr, haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// "2026-10-14 10:24:00", ISO-8601 yoki faqat "10:24" ([day] bilan).
DateTime? parseStopTime(dynamic raw, DateTime? day) => _toTime(raw, day);

DateTime? _toTime(dynamic raw, DateTime? day) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final full = DateTime.tryParse(s);
  if (full != null) return full.toLocal();
  final hm = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(s);
  if (hm == null || day == null) return null;
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(hm.group(1)!),
    int.parse(hm.group(2)!),
    int.parse(hm.group(3) ?? '0'),
  );
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

String? _nonEmpty(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Xodimning shu kundagi ish oynasi: birinchi "Keldim" dan oxirgi
/// "Ketdim" gacha (sessiya ochiq bo'lsa — hozirgacha yoki kun oxirigacha).
/// `null` — xodim shu kuni "Keldim" bosmagan, GPS umuman ko'rsatilmaydi.
({DateTime from, DateTime to})? workWindow({
  required String? checkIn,
  required String? checkOut,
  required DateTime day,
  required DateTime now,
}) {
  final from = _toTime(checkIn, day);
  if (from == null) return null;
  final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);
  final open = now.isBefore(endOfDay) ? now : endOfDay;
  var to = _toTime(checkOut, day) ?? open;
  if (to.isBefore(from)) to = open;
  return (from: from, to: to);
}

/// `2026-10-14T13:21:05+05:00` — qurilmaning mahalliy vaqti, offset bilan.
String isoWithOffset(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.abs().toString().padLeft(2, '0');
  final off = l.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  return '${l.year}-${two(l.month)}-${two(l.day)}T${two(l.hour)}:'
      '${two(l.minute)}:${two(l.second)}'
      '$sign${two(off.inHours)}:${two(off.inMinutes % 60)}';
}

/// Xodim bir joyda (radius [radiusM]) kamida [minDuration] turib, u yoq-bu
/// yoqqa yurgan oraliqlar.
///
/// * GPS "sakrashi" — radiusdan chiqib, [outlierWindow] ichida yana qaytgan
///   nuqtalar oraliqni bo'lmaydi (markazga qo'shilmaydi).
/// * To'g'ri sekin yurish "turish" emas: [longStay] dan qisqa oraliqda
///   kirgan va chiqqan nuqtalar bir-biridan [radiusM] dan uzoq bo'lmasligi
///   kerak. [longStay] dan uzoq turilgan bo'lsa, qaysi tomondan chiqqani
///   farqi yo'q.
List<StaffStop> detectDwells(
  List<TimedPoint> points, {
  double radiusM = 100,
  Duration minDuration = const Duration(minutes: 2),
  Duration outlierWindow = const Duration(seconds: 45),
  Duration longStay = const Duration(minutes: 5),
}) {
  final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
  final out = <StaffStop>[];
  var i = 0;
  while (i < sorted.length) {
    var sumLat = sorted[i].lat, sumLng = sorted[i].lng;
    var n = 1;
    var lastIn = i; // oxirgi radius ichidagi nuqta
    var j = i + 1;
    while (j < sorted.length) {
      final p = sorted[j];
      if (distanceMeters(sumLat / n, sumLng / n, p.lat, p.lng) <= radiusM) {
        sumLat += p.lat;
        sumLng += p.lng;
        n++;
        lastIn = j;
        j++;
        continue;
      }
      // Radiusdan chiqdi: tez orada qaytsa — sakrash, o'tkazib yuboriladi.
      var k = j + 1;
      var back = -1;
      while (k < sorted.length &&
          sorted[k].time.difference(sorted[j].time) <= outlierWindow) {
        if (distanceMeters(
              sumLat / n,
              sumLng / n,
              sorted[k].lat,
              sorted[k].lng,
            ) <=
            radiusM) {
          back = k;
          break;
        }
        k++;
      }
      if (back < 0) break;
      j = back;
    }
    final c = _trimWalking(sorted, i, lastIn, sumLat / n, sumLng / n, radiusM);
    final first = sorted[c.start], last = sorted[c.end];
    final dur = last.time.difference(first.time);
    final settled =
        dur >= longStay ||
        distanceMeters(first.lat, first.lng, last.lat, last.lng) <= radiusM;
    if (c.n > 0 &&
        dur >= minDuration &&
        settled &&
        isStationarySpan(sorted, c.start, c.end)) {
      out.add(
        StaffStop(lat: c.lat, lng: c.lng, from: first.time, to: last.time),
      );
      i = c.end + 1;
    } else {
      i++;
    }
  }
  return out;
}

/// Harakat tarixidagi to'xtashlar jonli: [base] (yuklangandagi ro'yxat)
/// [route] ning yangi nuqtalari bilan yangilanadi.
///
/// * Xodim [radiusM] ichida [minStay] dan ko'p turib, **hali o'sha yerda**
///   bo'lsa (oxirgi nuqta shu turishda, [staleAfter] dan eski emas,
///   faqat [today]) — `ongoing`: bu to'xtash raqamli ro'yxatga kirmaydi,
///   vaqti `now` gacha sanaladi.
/// * U ketgach — oddiy raqamli to'xtash bo'ladi (yakuniy vaqti bilan).
///   Mavjud to'xtash bilan ustma-ust tushsa uning tugash vaqti uzaytiriladi.
/// * [hidden] — ko'rsatilmaydigan joylar (masalan, o'z filiali zonasi).
({List<StaffStop> stops, StaffStop? ongoing}) liveStops(
  List<StaffStop> base,
  List<TimedPoint> route,
  DateTime now, {
  bool today = true,
  bool Function(StaffStop stop)? hidden,
  double radiusM = stopRadiusM,
  Duration minStay = stopMinDuration,
  Duration staleAfter = const Duration(minutes: 30),
}) {
  final stops = [...base];
  if (route.isEmpty) return (stops: stops, ongoing: null);
  bool overlaps(StaffStop a, StaffStop b) =>
      !a.to.isBefore(b.from) && !a.from.isAfter(b.to);
  bool isHidden(StaffStop s) => hidden?.call(s) ?? false;
  StaffStop withRange(StaffStop s, DateTime from, DateTime to) => StaffStop(
    lat: s.lat,
    lng: s.lng,
    from: from,
    to: to,
    nom: s.nom,
    manzil: s.manzil,
    rasmUrl: s.rasmUrl,
  );

  final dwells = detectDwells(route, radiusM: radiusM);
  final last = route.last;
  StaffStop? ongoing;
  final tail = dwells.isEmpty ? null : dwells.last;
  if (today &&
      tail != null &&
      tail.to == last.time &&
      now.difference(last.time) <= staleAfter &&
      now.difference(tail.from) >= minStay) {
    ongoing = centerStop(tail, route, radiusM: radiusM);
  }
  for (final d in dwells) {
    if (identical(d, tail) && ongoing != null) continue;
    if (d.duration < minStay) continue;
    final k = stops.indexWhere((st) => overlaps(st, d));
    if (k >= 0) {
      final st = stops[k];
      if (d.to.isAfter(st.to)) stops[k] = withRange(st, st.from, d.to);
      continue;
    }
    final c = centerStop(d, route, radiusM: radiusM);
    if (!isHidden(c)) stops.add(c);
  }
  if (ongoing != null) {
    final o = ongoing;
    final merged = stops.where((st) => overlaps(st, o)).toList();
    stops.removeWhere((st) => overlaps(st, o));
    var from = o.from;
    for (final st in merged) {
      if (st.from.isBefore(from)) from = st.from;
    }
    final info = merged.isEmpty ? o : merged.first;
    ongoing = StaffStop(
      lat: o.lat,
      lng: o.lng,
      from: from,
      to: now,
      nom: info.nom,
      manzil: info.manzil,
      rasmUrl: info.rasmUrl,
    );
    if (isHidden(ongoing)) ongoing = null;
  }
  stops.sort((a, b) => a.from.compareTo(b.from));
  return (stops: stops, ongoing: ongoing);
}

/// Chiziq uchun: bir joyda turilgan oraliqlar ([dwells]) bitta nuqtaga
/// (markaz) yig'iladi — u yerdagi u yoq-bu yoqqa chiziqlar chizilmaydi.
/// Qolgan nuqtalar real, o'zgarishsiz.
List<TimedPoint> collapseDwells(
  List<TimedPoint> points,
  List<StaffStop> dwells,
) {
  final out = <TimedPoint>[];
  var d = 0;
  for (final p in points) {
    while (d < dwells.length && p.time.isAfter(dwells[d].to)) {
      d++;
    }
    if (d < dwells.length && !p.time.isBefore(dwells[d].from)) {
      final w = dwells[d];
      if (out.isEmpty || out.last.time.isBefore(w.from)) {
        // Boshi va oxiri — chiziq keyingi yurishga turish tugagan paytdan
        // ulanadi (aks holda turish davomiyligi "bo'shliq" bo'lib qoladi).
        out.add((lat: w.lat, lng: w.lng, time: w.from));
        if (w.to.isAfter(w.from)) {
          out.add((lat: w.lat, lng: w.lng, time: w.to));
        }
      }
      continue;
    }
    out.add(p);
  }
  return out;
}

/// Server zona belgisi (`inside`) bilan GPS nuqta; `null` — noma'lum.
typedef ZonedPoint = ({double lat, double lng, DateTime time, bool? inside});

/// Zonadan qisqa "chiqib-kirish"larni tashlaydi: ketma-ket tashqaridagi
/// nuqtalar ikki tomonidan zona ichidagi nuqta bilan o'ralgan va birinchisidan
/// oxirgisigacha [maxDuration] dan qisqa bo'lsa — bu GPS sakrashi (yoki
/// rahbar uchun ahamiyatsiz bir daqiqalik chiqish). Aks holda xaritada zona
/// yonida tushunarsiz kichik bo'laklar qoladi. Kun boshi/oxiridagi (hali
/// qaytmagan) chiqish va `inside` noma'lum nuqtalarga tegilmaydi.
List<ZonedPoint> dropShortZoneExits(
  List<ZonedPoint> points, {
  Duration maxDuration = const Duration(minutes: 2),
}) {
  final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
  final drop = List.filled(sorted.length, false);
  var i = 0;
  while (i < sorted.length) {
    if (sorted[i].inside != false) {
      i++;
      continue;
    }
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1].inside == false) {
      j++;
    }
    final bounded =
        i > 0 &&
        sorted[i - 1].inside == true &&
        j + 1 < sorted.length &&
        sorted[j + 1].inside == true;
    if (bounded && sorted[j].time.difference(sorted[i].time) <= maxDuration) {
      for (var k = i; k <= j; k++) {
        drop[k] = true;
      }
    }
    i = j + 1;
  }
  return [
    for (var k = 0; k < sorted.length; k++)
      if (!drop[k]) sorted[k],
  ];
}

/// Server/bazadagi eski (filtrsiz) nuqtalar uchun — Zonic backendidagi
/// tozalash: harakatlanuvchi "tayanch" nuqtadan hisoblanganda tezlik
/// [maxSpeed] dan katta bo'lsa (GPS sakrashi) yoki masofa [minSegment] dan
/// kichik bo'lsa (titrash) — nuqta tashlanadi, tayanch o'zgarmaydi.
List<TimedPoint> cleanTrack(
  List<TimedPoint> points, {
  double maxSpeed = 45,
  double minSegment = 2,
}) {
  if (points.length < 2) return points;
  final out = <TimedPoint>[points.first];
  for (var i = 1; i < points.length; i++) {
    final a = out.last, p = points[i];
    final d = distanceMeters(a.lat, a.lng, p.lat, p.lng);
    final dt = p.time.difference(a.time).inMilliseconds / 1000;
    if (dt > 0 && d / dt > maxSpeed) continue;
    if (d < minSegment) continue;
    out.add(p);
  }
  return removeSpikes(removeExcursions(out));
}

/// GPS "sakrab ketib, sekin qaytishi"ni olib tashlaydi: nuqta bir zumda
/// ([jumpSpeed] m/s dan tez, [minJump] m dan uzoq) chetga otiladi, keyin
/// iz faqat joyiga qaytadi. Sakrashdan oldingi nuqtadan [maxDuration]
/// ichida yana [returnDist] m yaqiniga qaytilgan bo'lsa — oradagi hamma
/// nuqtalar soxta. Qaytilmasa — haqiqiy harakat (masalan, mashinada
/// ketish), tegilmaydi. Sakrashdan keyin yana uzoqlashgan bo'lsa (eng uzoq
/// nuqta sakrash masofasidan [maxDrift] marta uzoq) — bu haqiqiy yurish,
/// u ham tegilmaydi. [cleanTrack] ning tezlik chegarasidan sekin, lekin
/// piyodaga imkonsiz sakrashlar shu bilan tutiladi.
List<TimedPoint> removeExcursions(
  List<TimedPoint> points, {
  double jumpSpeed = 12,
  double minJump = 100,
  double returnDist = 60,
  Duration maxDuration = const Duration(minutes: 5),
  double maxDrift = 1.3,
}) {
  if (points.length < 3) return points;
  final out = <TimedPoint>[points.first];
  var i = 1;
  while (i < points.length) {
    final a = out.last, b = points[i];
    final d = distanceMeters(a.lat, a.lng, b.lat, b.lng);
    final dt = b.time.difference(a.time).inMilliseconds / 1000;
    if (d > minJump && dt > 0 && d / dt > jumpSpeed) {
      var back = -1;
      var far = d;
      for (var j = i + 1; j < points.length; j++) {
        final c = points[j];
        if (c.time.difference(a.time) > maxDuration) break;
        final dc = distanceMeters(a.lat, a.lng, c.lat, c.lng);
        if (dc <= returnDist) {
          back = j;
          break;
        }
        if (dc > far) far = dc;
      }
      if (back > 0 && far <= d * maxDrift) {
        i = back;
        continue;
      }
    }
    out.add(b);
    i++;
  }
  return removeReturnJumps(out);
}

/// Sakrab ketgan izni **qaytish** sakrashidan topadi. [removeExcursions]
/// sakrashga kirishni tezlik bo'yicha qidiradi, lekin kirish signal
/// uzilishidan keyin bo'lsa (masalan, 4 daqiqa nuqta yo'q, keyin 650 m
/// narida) o'rtacha tezlik past chiqadi va u tutilmaydi. Qaytish esa bir
/// zumda bo'ladi: [returnSpeed] m/s dan tez, [minJump] m dan uzoq sakrash
/// C nuqtaga tushganda, [maxDuration] ichida orqaga qarab tayanch A
/// qidiriladi. Xodim shu orada yurgan bo'lishi mumkin, shuning uchun
/// `masofa(A, C) ≤ returnDist + walkSpeed × (t_C − t_A)`. A topilsa, A va C
/// oralig'idagi hamma nuqta soxta. Topilmasa — haqiqiy harakat.
List<TimedPoint> removeReturnJumps(
  List<TimedPoint> points, {
  double returnSpeed = 30,
  double minJump = 100,
  double returnDist = 60,
  double walkSpeed = 2,
  Duration maxDuration = const Duration(minutes: 5),
}) {
  if (points.length < 3) return points;
  final drop = List<bool>.filled(points.length, false);
  for (var i = 2; i < points.length; i++) {
    final b = points[i - 1], c = points[i];
    if (drop[i - 1]) continue;
    final d = distanceMeters(b.lat, b.lng, c.lat, c.lng);
    final dt = c.time.difference(b.time).inMilliseconds / 1000;
    if (d <= minJump || dt <= 0 || d / dt <= returnSpeed) continue;
    for (var j = i - 2; j >= 0; j--) {
      final a = points[j];
      final span = c.time.difference(a.time);
      if (span > maxDuration) break;
      final dc = distanceMeters(a.lat, a.lng, c.lat, c.lng);
      if (dc <= returnDist + walkSpeed * span.inMilliseconds / 1000) {
        for (var k = j + 1; k < i; k++) {
          drop[k] = true;
        }
        break;
      }
    }
  }
  return [
    for (var i = 0; i < points.length; i++)
      if (!drop[i]) points[i],
  ];
}

/// "Igna" sakrashlarini olib tashlaydi: GPS bitta nuqtada chetga otilib,
/// keyingisida joyiga qaytadi (A → B → C, bunda A va C yaqin, B uzoq).
/// Tezlik chegarasidan o'tib ketadigan sekin "sapchish"lar shu bilan
/// tutiladi. Haqiqiy orqaga burilishda oraliq nuqtalar bo'ladi, shuning
/// uchun ikkala yelka ham [minLeg] dan uzun bo'lsagina tekshiriladi.
List<TimedPoint> removeSpikes(List<TimedPoint> points, {double minLeg = 25}) {
  if (points.length < 3) return points;
  final out = <TimedPoint>[points.first];
  for (var i = 1; i < points.length - 1; i++) {
    final a = out.last, b = points[i], c = points[i + 1];
    final ab = distanceMeters(a.lat, a.lng, b.lat, b.lng);
    final bc = distanceMeters(b.lat, b.lng, c.lat, c.lng);
    if (ab > minLeg && bc > minLeg) {
      final ac = distanceMeters(a.lat, a.lng, c.lat, c.lng);
      // Burchak ~20° dan o'tkir — borib-qaytish.
      if (ac < 0.35 * math.min(ab, bc)) continue;
    }
    out.add(b);
  }
  out.add(points.last);
  return out;
}

/// Shundan uzoq vaqt nuqta kelmasa (internet/GPS yo'q, telefon o'chgan,
/// zona ichida) — oraliqdagi yo'l noma'lum.
const trackGapTime = Duration(minutes: 5);

/// Marshrutni uzilishlar bo'yicha bo'laklaydi. Ikki nuqta orasida
/// [maxGap] dan ko'p vaqt o'tgan va [minGapDistance] dan ko'p masofa
/// bo'lsa — u yerda yangi bo'lak boshlanadi (oraliq taxminiy — punktir
/// bilan chiziladi). Bir joyda uzoq turish (masofa kichik) uzilish emas.
/// Vaqtdan qat'i nazar ikki nuqta [maxJump] dan uzoq bo'lsa ham uzilish:
/// undan uzoq to'g'ri chiziq binolar ustidan "kesib" o'tadi.
///
/// Nuqtalar siyrak kelsa ham (masalan, daqiqada bitta, 50–100 m oraliq)
/// piyoda yurish uzluksiz chiziq bo'lib qoladi — har oraliq punktir emas.
List<List<TimedPoint>> splitTrackAtGaps(
  List<TimedPoint> points, {
  Duration maxGap = trackGapTime,
  double minGapDistance = 100,
  double maxJump = 250,
}) {
  bool isGap(TimedPoint a, TimedPoint b) {
    final d = distanceMeters(a.lat, a.lng, b.lat, b.lng);
    return (b.time.difference(a.time) > maxGap && d > minGapDistance) ||
        d > maxJump;
  }

  // Chetga otilgan yakka nuqta (borib-qaytgan "tikan") — GPS xatosi, yo'l
  // emas: u punktirlar "o'rgimchak to'ri"ni hosil qilmasin. Ketma-ket
  // yurishdagi siyrak nuqta esa (oldingi → shu → keyingi deyarli bir
  // yo'nalishda) saqlanadi.
  final pts = [...points];
  for (var i = 1; i < pts.length - 1;) {
    final a = pts[i - 1], b = pts[i], c = pts[i + 1];
    final ab = distanceMeters(a.lat, a.lng, b.lat, b.lng);
    final bc = distanceMeters(b.lat, b.lng, c.lat, c.lng);
    final ac = distanceMeters(a.lat, a.lng, c.lat, c.lng);
    if (isGap(a, b) && isGap(b, c) && ab + bc > 1.8 * ac + 50) {
      pts.removeAt(i);
      if (i > 1) i--;
    } else {
      i++;
    }
  }

  final segments = <List<TimedPoint>>[];
  var cur = <TimedPoint>[];
  for (final p in pts) {
    if (cur.isNotEmpty && isGap(cur.last, p)) {
      segments.add(cur);
      cur = <TimedPoint>[];
    }
    cur.add(p);
  }
  if (cur.isNotEmpty) segments.add(cur);
  return segments;
}

/// GPS aniqligi shundan yomon nuqta chizilmaydi (metr).
const trackMaxAccuracy = 50.0;

/// Harakat chizig'i va jonli marker uchun: aniqligi shundan yomon nuqta
/// ishlatilmaydi (metr). Bino ichida GPS signalni yo'qotib qayta topganda
/// 30–50 m aniqlikdagi 1–3 ta nuqta 30–60 m chetga "sakraydi" — joyida
/// turgan xodimdan uzun, tushunarsiz chiziq tortilardi. 25 m dan yaxshi
/// nuqtalar yurishni to'liq ko'rsatadi (ochiq joyda aniqlik 3–15 m).
const trackDrawAccuracy = 25.0;

/// To'xtash metkasini xodim haqiqatda turgan joyning o'rtasiga qo'yadi:
/// [from]–[to] oralig'idagi nuqtalardan eng zich [radiusM] (100 m)
/// aylana topiladi va metka uning markaziga suriladi. Backend yoki keng
/// (250 m) hisob markazi chetga siljigan bo'lsa ham metka chiziq ustida
/// bo'ladi. Oraliqda nuqta bo'lmasa — o'zgarmaydi.
StaffStop centerStop(
  StaffStop stop,
  List<TimedPoint> points, {
  double radiusM = 100,
}) {
  var pts = [
    for (final p in points)
      if (!p.time.isBefore(stop.from) && !p.time.isAfter(stop.to)) p,
  ];
  if (pts.isEmpty) return stop;
  // Juda ko'p nuqtada hisob og'irlashmasin (n²).
  if (pts.length > 300) {
    final step = pts.length / 300;
    pts = [for (var i = 0; i < 300; i++) pts[(i * step).floor()]];
  }
  ({double lat, double lng}) meanAround(double lat, double lng) {
    var sLat = 0.0, sLng = 0.0, n = 0;
    for (final p in pts) {
      if (distanceMeters(lat, lng, p.lat, p.lng) <= radiusM) {
        sLat += p.lat;
        sLng += p.lng;
        n++;
      }
    }
    return n == 0 ? (lat: lat, lng: lng) : (lat: sLat / n, lng: sLng / n);
  }

  var best = pts.first;
  var bestCount = -1;
  for (final c in pts) {
    var count = 0;
    for (final p in pts) {
      if (distanceMeters(c.lat, c.lng, p.lat, p.lng) <= radiusM) count++;
    }
    if (count > bestCount) {
      bestCount = count;
      best = c;
    }
  }
  var center = meanAround(best.lat, best.lng);
  center = meanAround(center.lat, center.lng);
  return StaffStop(
    lat: center.lat,
    lng: center.lng,
    from: stop.from,
    to: stop.to,
    nom: stop.nom,
    manzil: stop.manzil,
    rasmUrl: stop.rasmUrl,
  );
}

/// Backend yo'lga moslagan (map matching) marshrut bo'lagi turi.
enum RouteSegmentKind {
  /// Yo'lga moslangan (avto yoki piyoda yo'li bo'ylab).
  road,

  /// Moslab bo'lmagan (bino ichi, hovli, yo'l yo'q joy) — tozalangan real
  /// GPS nuqtalari.
  real,

  /// Ma'lumot yo'q oraliq — yo'l taxmin qilinmaydi (punktir).
  gap,
}

/// `/rahbar/lokatsiya/marshrut/{id}` javobidagi bitta bo'lak.
class RouteSegment {
  final RouteSegmentKind kind;

  /// `avto` / `piyoda` (faqat [RouteSegmentKind.road] uchun).
  final String? mode;
  final DateTime from;
  final DateTime to;
  final List<({double lat, double lng})> points;

  const RouteSegment({
    required this.kind,
    required this.from,
    required this.to,
    required this.points,
    this.mode,
  });

  /// `null` — tushunarsiz yozuv (tashlanadi).
  static RouteSegment? fromJson(Map<String, dynamic> m, {DateTime? day}) {
    final kind = switch (m['tur']?.toString()) {
      'yol' => RouteSegmentKind.road,
      'real' => RouteSegmentKind.real,
      'uzilish' => RouteSegmentKind.gap,
      _ => null,
    };
    final from = _toTime(m['boshlanish'], day);
    final to = _toTime(m['tugash'], day);
    final raw = m['nuqtalar'];
    if (kind == null || from == null || to == null || raw is! List) {
      return null;
    }
    final points = <({double lat, double lng})>[
      for (final p in raw)
        if (p is List && p.length >= 2)
          (lat: _toDouble(p[0]), lng: _toDouble(p[1]))
        else if (p is Map)
          (
            lat: _toDouble(p['lat'] ?? p['latitude']),
            lng: _toDouble(p['lng'] ?? p['longitude']),
          ),
    ]..removeWhere((p) => p.lat == 0.0 || p.lng == 0.0);
    if (points.length < 2) return null;
    return RouteSegment(
      kind: kind,
      mode: m['rejim']?.toString(),
      from: from,
      to: to,
      points: points,
    );
  }
}

/// Backend javobidan bo'laklar (vaqt bo'yicha). `null` — backend bu
/// endpointni hali qo'llamaydi yoki marshrut hali hisoblanmagan.
List<RouteSegment>? parseMatchedRoute(
  Map<String, dynamic> data, {
  DateTime? day,
}) {
  final raw = data['bolaklar'];
  if (raw is! List) return null;
  return [
    for (final e in raw.whereType<Map<dynamic, dynamic>>())
      ?RouteSegment.fromJson(Map<String, dynamic>.from(e), day: day),
  ]..sort((a, b) => a.from.compareTo(b.from));
}

/// `/rahbar/lokatsiya/marshrut/{id}` javobi to'liq.
class MatchedRoute {
  final List<RouteSegment> segments;

  /// Backend hisoblash algoritmi versiyasi (`versiya`). Yangi (OSRM + bino
  /// tekshiruvi) algoritm uni yuboradi.
  final int? versiya;

  /// Bo'laklar qachon hisoblangan (`hisoblangan_vaqt` / `hisoblangan_at`) —
  /// o'zgarmagan bo'lsa
  /// xarita qayta chizilmaydi.
  final String? hisoblanganVaqt;

  const MatchedRoute(this.segments, {this.versiya, this.hisoblanganVaqt});

  /// Marshrutni backend o'zi to'liq hisoblagan: bo'laklar telefonda
  /// o'zgartirilmay chiziladi (Yandex/Overpass orqali yig'ilmaydi) — hamma
  /// telefonda bir xil chiziq. Belgisi: `versiya` keladi yoki kamida bitta
  /// yo'lga moslangan (`yol`) bo'lak bor (OSRM ishlayapti).
  bool get serverAuthoritative =>
      versiya != null || segments.any((s) => s.kind == RouteSegmentKind.road);
}

/// [parseMatchedRoute] + `versiya` / `hisoblangan_vaqt`.
MatchedRoute? parseMatchedRouteFull(
  Map<String, dynamic> data, {
  DateTime? day,
}) {
  final segments = parseMatchedRoute(data, day: day);
  if (segments == null) return null;
  final v = data['versiya'];
  final at = (data['hisoblangan_vaqt'] ?? data['hisoblangan_at'])?.toString();
  return MatchedRoute(
    segments,
    versiya: v is num ? v.toInt() : int.tryParse('${v ?? ''}'),
    hisoblanganVaqt: at == null || at.isEmpty ? null : at,
  );
}

/// Backend yo'lga moslagan marshrutda **chizilmay qolgan** real nuqtalar.
///
/// Backend ba'zi oraliqlarni moslay olmaydi (nuqtalar siyrak, hali
/// hisoblanmagan oxirgi daqiqalar yoki "uzilish" deb belgilangan joy), lekin
/// telefon o'sha vaqtda nuqta yuborgan bo'ladi. Bunday nuqtalar tashlanmaydi:
/// ular ketma-ket bo'laklarga yig'iladi va real chiziq bilan chiziladi.
/// Har bo'lak oldingi/keyingi moslangan bo'lakning uchiga ulanadi, chiziq
/// uzilib qolmasin.
///
/// [emptyGaps] — ichida birorta real nuqta yo'q "uzilish" bo'laklari
/// (indekslari). Faqat shular punktir bilan chiziladi.
({List<List<TimedPoint>> runs, Set<int> emptyGaps}) unmatchedRawRuns(
  List<RouteSegment> matched,
  List<TimedPoint> raw,
) {
  final covered = [
    for (final s in matched)
      if (s.kind != RouteSegmentKind.gap) s,
  ];
  bool isCovered(DateTime t) =>
      covered.any((s) => !t.isBefore(s.from) && !t.isAfter(s.to));

  final groups = <List<TimedPoint>>[];
  List<TimedPoint>? current;
  for (final p in raw) {
    if (isCovered(p.time)) {
      current = null;
      continue;
    }
    if (current == null) {
      current = [];
      groups.add(current);
    }
    current.add(p);
  }

  final runs = <List<TimedPoint>>[];
  for (final g in groups) {
    RouteSegment? before;
    RouteSegment? after;
    for (final s in covered) {
      if (!s.to.isAfter(g.first.time)) before = s;
      if (after == null && !s.from.isBefore(g.last.time)) after = s;
    }
    final run = <TimedPoint>[
      if (before != null)
        (
          lat: before.points.last.lat,
          lng: before.points.last.lng,
          time: before.to,
        ),
      ...g,
      if (after != null)
        (
          lat: after.points.first.lat,
          lng: after.points.first.lng,
          time: after.from,
        ),
    ];
    if (run.length >= 2) runs.add(run);
  }

  final emptyGaps = <int>{
    for (var i = 0; i < matched.length; i++)
      if (matched[i].kind == RouteSegmentKind.gap &&
          !raw.any(
            (p) =>
                p.time.isAfter(matched[i].from) &&
                p.time.isBefore(matched[i].to),
          ))
        i,
  };
  return (runs: runs, emptyGaps: emptyGaps);
}

/// Zona hisobidagi bitta GPS nuqta: vaqti va o'z zonasidan tashqaridami.
typedef ZoneSample = ({DateTime time, bool outside});

/// Xodim [start] ("Keldim") dan [end] gacha (ketgan vaqt yoki hozir)
/// o'z zonasi **ichida** qancha vaqt bo'lgani — sekundomer kabi: zonadan
/// chiqqanda to'xtaydi, qaytib kirganda qolgan joyidan davom etadi.
///
/// Zona ichida telefon GPS yubormaydi, tashqarida esa har soniyada (bir
/// joyda turganda 20 s da bir) yuboradi. Shuning uchun tashqaridagi
/// ketma-ket nuqtalar ([maxGap] dan katta uzilishsiz) bitta "tashqarida"
/// oralig'i hisoblanadi; qolgan vaqt — zona ichida. [outsideNow] — xodim
/// hozir tashqarida (jonli holat): oxirgi oraliq [end] gacha cho'ziladi.
Duration timeInZone({
  required DateTime start,
  required DateTime end,
  required List<ZoneSample> samples,
  bool outsideNow = false,
  Duration maxGap = const Duration(seconds: 90),
}) {
  if (!end.isAfter(start)) return Duration.zero;
  final sorted = [...samples]..sort((a, b) => a.time.compareTo(b.time));
  final intervals = <(DateTime, DateTime)>[];
  DateTime? runStart, runEnd;
  void close() {
    if (runStart != null) intervals.add((runStart!, runEnd!));
    runStart = runEnd = null;
  }

  for (final s in sorted) {
    if (!s.outside) {
      close();
      continue;
    }
    if (runEnd != null && s.time.difference(runEnd!) > maxGap) close();
    runStart ??= s.time;
    runEnd = s.time;
  }
  if (outsideNow) {
    // Oxirgi tashqi nuqta yaqinda bo'lsa — o'sha oraliq hozirgacha davom
    // etyapti; aks holda xodim hozirgina chiqqan (hisob shu paytdan).
    if (runEnd != null && end.difference(runEnd!) <= maxGap) {
      runEnd = end;
    } else {
      close();
    }
  }
  close();

  var outside = Duration.zero;
  for (final (a, b) in intervals) {
    final from = a.isBefore(start) ? start : a;
    final to = b.isAfter(end) ? end : b;
    if (to.isAfter(from)) outside += to.difference(from);
  }
  final total = end.difference(start) - outside;
  return total.isNegative ? Duration.zero : total;
}

/// Ikki ketma-ket nuqta orasini ko'chalar bo'ylab chizish kerakmi: juda
/// yaqin bo'lsa to'g'ri chiziq yetarli (GPS xatosidan kichik), juda uzoq
/// bo'lsa qayerdan yurgani noma'lum.
bool needsStreetSnap(
  ({double lat, double lng}) a,
  ({double lat, double lng}) b,
) {
  final d = distanceMeters(a.lat, a.lng, b.lat, b.lng);
  return d >= 25 && d <= 5000;
}

/// Mashinada edimi (aks holda piyoda): o'rtacha tezlik > 2,5 m/s (~9 km/soat).
bool looksLikeDriving(TimedPoint a, TimedPoint b) {
  final sec = b.time.difference(a.time).inMilliseconds / 1000;
  if (sec <= 0) return false;
  return distanceMeters(a.lat, a.lng, b.lat, b.lng) / sec > 2.5;
}

/// Marshrutlovchi bergan ko'cha yo'li ishonchlimi: to'g'ri chiziqdan
/// haddan tashqari uzun bo'lsa (masalan, bir tomonlama ko'cha sabab katta
/// aylanma) — xodim u yerdan yurmagan, to'g'ri chiziq qoldiriladi.
bool plausibleStreetPath(
  List<({double lat, double lng})> path,
  ({double lat, double lng}) a,
  ({double lat, double lng}) b, {
  Duration? elapsed,
}) {
  if (path.length < 2) return false;
  final straight = distanceMeters(a.lat, a.lng, b.lat, b.lng);
  var length = 0.0;
  for (var i = 1; i < path.length; i++) {
    length += distanceMeters(
      path[i - 1].lat,
      path[i - 1].lng,
      path[i].lat,
      path[i].lng,
    );
  }
  if (length > math.max(straight * 1.8, straight + 120)) return false;
  // Orqaga qaytish / ilmoq (marshrutlovchi ko'chaning narigi tomoniga
  // o'tib, burilib qaytgan): a→b yo'nalishidagi oldinga siljish 25 m dan
  // ko'p kamaymasin.
  if (straight > 0) {
    final kx = math.cos(a.lat * math.pi / 180);
    final ux = (b.lng - a.lng) * kx, uy = b.lat - a.lat;
    final norm = math.sqrt(ux * ux + uy * uy);
    var best = double.negativeInfinity;
    for (final p in path) {
      final px = (p.lng - a.lng) * kx, py = p.lat - a.lat;
      // Proyeksiya metrda (1° kenglik ≈ 111 km).
      final along = (px * ux + py * uy) / norm * 111320;
      if (along < best - 25) return false;
      if (along > best) best = along;
    }
  }
  // Yo'lning uchlari nuqtalardan uzoq bo'lmasin (marshrutlovchi boshqa
  // ko'chaga "yopishtirib" qo'ymasin).
  final s = path.first, e = path.last;
  if (distanceMeters(s.lat, s.lng, a.lat, a.lng) > 60 ||
      distanceMeters(e.lat, e.lng, b.lat, b.lng) > 60) {
    return false;
  }
  final sec = (elapsed?.inMilliseconds ?? 0) / 1000;
  // Shuncha vaqtda bu yo'lni bosib bo'lmaydi (> 40 m/s).
  if (sec > 0 && length / sec > 40) return false;
  return true;
}

/// Zaxira tekshiruv: qat'iy [plausibleStreetPath] hamma variantni rad etsa
/// ham, xom to'g'ri chiziq binolar ustidan o'tadi — undan ko'ra eng yaqin
/// ko'cha yo'li afzal. Faqat uchlari nuqtalarga yaqin (≤ 60 m), aylanma
/// juda katta emas (≤ max(3×, +250 m)) va tezlik real bo'lsa qabul qilinadi.
bool roadFallbackPath(
  List<({double lat, double lng})> path,
  ({double lat, double lng}) a,
  ({double lat, double lng}) b, {
  Duration? elapsed,
}) {
  if (path.length < 2) return false;
  final straight = distanceMeters(a.lat, a.lng, b.lat, b.lng);
  final length = _pathLen(path, 0, path.length - 1);
  if (length > math.max(straight * 3, straight + 250)) return false;
  final s = path.first, e = path.last;
  if (distanceMeters(s.lat, s.lng, a.lat, a.lng) > 60 ||
      distanceMeters(e.lat, e.lng, b.lat, b.lng) > 60) {
    return false;
  }
  final sec = (elapsed?.inMilliseconds ?? 0) / 1000;
  if (sec > 0 && length / sec > 40) return false;
  return true;
}

/// Marshrutlovchi yo'l tarmog'idan tashqaridagi nuqtaga (bino ichi, hovli)
/// oxirgi bo'lakni **to'g'ri chiziq** bilan tortadi — u binolar ustidan
/// o'tadi. Bunday ulovchi (uchi aynan nuqtaga tushgan, [minLen] m dan uzun)
/// tashlanadi: chiziq yo'lakning nuqtaga eng yaqin joyida (eshik oldida)
/// to'xtaydi.
List<({double lat, double lng})> dropEndConnectors(
  List<({double lat, double lng})> path,
  ({double lat, double lng}) a,
  ({double lat, double lng}) b, {
  double minLen = 15,
}) {
  var out = path;
  bool isConnector(
    ({double lat, double lng}) end,
    ({double lat, double lng}) inner,
    ({double lat, double lng}) target,
  ) =>
      distanceMeters(end.lat, end.lng, target.lat, target.lng) < 1.5 &&
      distanceMeters(end.lat, end.lng, inner.lat, inner.lng) > minLen;
  if (out.length >= 3 && isConnector(out.last, out[out.length - 2], b)) {
    out = out.sublist(0, out.length - 1);
  }
  if (out.length >= 3 && isConnector(out.first, out[1], a)) {
    out = out.sublist(1);
  }
  return out;
}

/// Marshrutlovchi yo'lni nuqtadan biroz oldinroq/narida boshlab-tugatadi
/// (masalan, ko'cha o'rtasidan burilib qaytadi) — uchlarda "ilmoq" chiqadi.
/// Yo'l [a] ga eng yaqin joyidan [b] ga eng yaqin joyigacha kesiladi.
List<({double lat, double lng})> trimToEnds(
  List<({double lat, double lng})> path,
  ({double lat, double lng}) a,
  ({double lat, double lng}) b,
) {
  if (path.length < 3) return path;
  int nearest(({double lat, double lng}) q, int from, int to) {
    var best = from;
    var bestD = double.infinity;
    for (var i = from; i < to; i++) {
      final d = distanceMeters(q.lat, q.lng, path[i].lat, path[i].lng);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  final mid = path.length ~/ 2;
  final s = nearest(a, 0, mid + 1);
  final e = nearest(b, math.max(s + 1, mid), path.length);
  return path.sublist(s, e + 1);
}

/// GPS yo'l bo'ylab yurganda u yoq-bu yoqqa "sakraydi" (keng ko'chaning
/// narigi tomoniga o'tib-qaytgandek zigzag). [points] dan shunday chetga
/// chiqishlar olib tashlanadi (Douglas–Peucker kabi): oraliqdagi nuqtalar
/// to'g'ri chiziqdan ko'pi bilan [toleranceM] chetda va to'g'ri chiziq
/// chetlanishdan kamida [minRatio] marta uzun bo'lsa (ya'ni bu burchakdan
/// burilish emas, yo'l bo'ylab cho'zilgan chetlanish) — faqat ikki uchi
/// qoladi. [clean] berilsa (bino tekshiruvi) — to'g'ri chiziq bino ustidan
/// o'tsa olib tashlanmaydi.
List<TimedPoint> simplifyExcursions(
  List<TimedPoint> points, {
  double toleranceM = 60,
  double minRatio = 2.5,
  bool Function(TimedPoint a, TimedPoint b)? clean,
}) {
  if (points.length < 3) return [...points];
  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;
  final kx = math.cos(points.first.lat * math.pi / 180) * 111320;
  const ky = 111320.0;
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (i, j) = stack.removeLast();
    if (j - i < 2) continue;
    final a = points[i], b = points[j];
    final bx = (b.lng - a.lng) * kx, by = (b.lat - a.lat) * ky;
    final len = math.sqrt(bx * bx + by * by);
    var maxDev = -1.0;
    var k = i + 1;
    for (var m = i + 1; m < j; m++) {
      final px = (points[m].lng - a.lng) * kx,
          py = (points[m].lat - a.lat) * ky;
      double dev;
      if (len == 0) {
        dev = math.sqrt(px * px + py * py);
      } else {
        final t = ((px * bx + py * by) / (len * len)).clamp(0.0, 1.0);
        final dx = px - bx * t, dy = py - by * t;
        dev = math.sqrt(dx * dx + dy * dy);
      }
      if (dev > maxDev) {
        maxDev = dev;
        k = m;
      }
    }
    final flat =
        maxDev <= toleranceM &&
        len >= minRatio * maxDev &&
        (clean?.call(a, b) ?? true);
    if (flat) continue;
    keep[k] = true;
    stack
      ..add((i, k))
      ..add((k, j));
  }
  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
}

/// Chiziqdan chetga borib-qaytgan qisqa "dumcha"larni olib tashlaydi
/// (A → B → C, B ga borib deyarli o'sha joyga qaytilgan). Odatda bir joyda
/// turish nuqtasi chiziq yonida qolganda paydo bo'ladi.
List<({double lat, double lng})> removeSpurs(
  List<({double lat, double lng})> line, {
  double minLeg = 3,
  double maxLeg = 80,
}) {
  final out = [...line];
  var changed = true;
  while (changed && out.length >= 3) {
    changed = false;
    for (var i = 1; i < out.length - 1; i++) {
      final a = out[i - 1], b = out[i], c = out[i + 1];
      final ab = distanceMeters(a.lat, a.lng, b.lat, b.lng);
      final bc = distanceMeters(b.lat, b.lng, c.lat, c.lng);
      if (ab < minLeg || bc < minLeg || ab > maxLeg || bc > maxLeg) continue;
      final ac = distanceMeters(a.lat, a.lng, c.lat, c.lng);
      if (ac < 0.35 * math.min(ab, bc)) {
        out.removeAt(i);
        changed = true;
        break;
      }
    }
  }
  return out;
}

double _pathLen(List<({double lat, double lng})> l, int from, int to) {
  var total = 0.0;
  for (var k = from + 1; k <= to; k++) {
    total += distanceMeters(l[k - 1].lat, l[k - 1].lng, l[k].lat, l[k].lng);
  }
  return total;
}

/// Borib-qaytgan qismlarni (bir necha nuqtali "dumcha" yoki kichik ilmoq)
/// olib tashlaydi: chiziq [i] nuqtadan chetga ketib, [maxLen] metr ichida
/// yana [tolerance] metrgacha o'sha joyga qaytsa — oradagi qism tashlanadi.
List<({double lat, double lng})> removeBacktracks(
  List<({double lat, double lng})> line, {
  double tolerance = 20,
  double maxLen = 300,
}) {
  final out = [...line];
  var i = 0;
  while (i < out.length - 2) {
    var cut = -1;
    var len = 0.0;
    for (var j = i + 1; j < out.length; j++) {
      len += distanceMeters(
        out[j - 1].lat,
        out[j - 1].lng,
        out[j].lat,
        out[j].lng,
      );
      if (len > maxLen) break;
      if (j >= i + 2 &&
          len >= 10 &&
          distanceMeters(out[i].lat, out[i].lng, out[j].lat, out[j].lng) <=
              tolerance) {
        cut = j;
      }
    }
    if (cut > 0) {
      out.removeRange(i + 1, cut);
    } else {
      i++;
    }
  }
  return out;
}

/// Boshqa chiziqqa tegib turgan qisqa (< [maxLen] m) alohida chiziqlar —
/// asosiy yo'ldan chiqqan "T" dumchalar, odamni chalg'itadi — tashlanadi.
List<List<({double lat, double lng})>> removeStubLines(
  List<List<({double lat, double lng})>> lines, {
  double maxLen = 120,
  double touch = 15,
}) {
  final keep = [for (final _ in lines) true];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.length < 2 || _pathLen(l, 0, l.length - 1) >= maxLen) continue;
    final others = [
      for (var k = 0; k < lines.length; k++)
        if (k != i && keep[k]) lines[k],
    ];
    if (nearestOnLines(l.first, others, maxDist: touch) != null ||
        nearestOnLines(l.last, others, maxDist: touch) != null) {
      keep[i] = false;
    }
  }
  return [
    for (var i = 0; i < lines.length; i++)
      if (keep[i]) lines[i],
  ];
}

/// Chiziq uchidagi keskin burilgan qisqa "ilgak" (yo'l chetiga yoki
/// binoga qarab ≤ [maxLen] m chiqib qolgan dumcha) kesiladi — boshida ham,
/// oxirida ham.
List<({double lat, double lng})> trimEndHooks(
  List<({double lat, double lng})> line, {
  double maxLen = 30,
  double minTurnDeg = 50,
}) {
  List<({double lat, double lng})> trimTail(
    List<({double lat, double lng})> l,
  ) {
    var out = l;
    var changed = true;
    while (changed && out.length >= 3) {
      changed = false;
      var tail = 0.0;
      for (var k = out.length - 2; k >= 1; k--) {
        tail += distanceMeters(
          out[k].lat,
          out[k].lng,
          out[k + 1].lat,
          out[k + 1].lng,
        );
        if (tail > maxLen) break;
        final kx = math.cos(out[k].lat * math.pi / 180);
        final p = out[k - 1], q = out[k], r = out.last;
        final ux = (q.lng - p.lng) * kx, uy = q.lat - p.lat;
        final vx = (r.lng - q.lng) * kx, vy = r.lat - q.lat;
        final nu = math.sqrt(ux * ux + uy * uy);
        final nv = math.sqrt(vx * vx + vy * vy);
        if (nu == 0 || nv == 0) continue;
        final cos = ((ux * vx + uy * vy) / (nu * nv)).clamp(-1.0, 1.0);
        if (math.acos(cos) * 180 / math.pi > minTurnDeg) {
          out = out.sublist(0, k + 1);
          changed = true;
          break;
        }
      }
    }
    return out;
  }

  final tail = trimTail(line);
  return trimTail(tail.reversed.toList()).reversed.toList();
}

/// Chiziqlarning zona (filial doirasi) ichidagi qismi kesib tashlanadi:
/// xodim zonaga kirgach chizish to'xtaydi, chiqqanda yana boshlanadi.
/// Chiziq doira chegarasida aniq uziladi. [minLen] m dan qisqa qoldiqlar
/// tashlanadi.
List<List<({double lat, double lng})>> clipOutsideCircles(
  List<List<({double lat, double lng})>> lines,
  List<({double lat, double lng, double radius})> circles, {
  double minLen = 5,
}) {
  var current = lines;
  for (final c in circles) {
    if (c.radius <= 0) continue;
    final kx = math.cos(c.lat * math.pi / 180) * 111320;
    const ky = 111320.0;
    ({double x, double y}) toXY(({double lat, double lng}) p) =>
        (x: (p.lng - c.lng) * kx, y: (p.lat - c.lat) * ky);
    ({double lat, double lng}) toLL(double x, double y) =>
        (lat: c.lat + y / ky, lng: c.lng + x / kx);
    final r2 = c.radius * c.radius;
    final next = <List<({double lat, double lng})>>[];
    for (final line in current) {
      var cur = <({double lat, double lng})>[];
      void close() {
        if (cur.length >= 2) next.add(cur);
        cur = <({double lat, double lng})>[];
      }

      if (line.length == 1) {
        final q = toXY(line.first);
        if (q.x * q.x + q.y * q.y > r2) next.add(line);
        continue;
      }
      for (var i = 1; i < line.length; i++) {
        final a = toXY(line[i - 1]), b = toXY(line[i]);
        final dx = b.x - a.x, dy = b.y - a.y;
        final qa = dx * dx + dy * dy;
        final qb = 2 * (a.x * dx + a.y * dy);
        final qc = a.x * a.x + a.y * a.y - r2;
        // Kesmaning doira ichidagi qismi [t1, t2] (bo'lmasa — butunlay tashqarida).
        var t1 = 2.0, t2 = 2.0;
        final disc = qb * qb - 4 * qa * qc;
        if (qa > 0 && disc > 0) {
          final sq = math.sqrt(disc);
          t1 = (-qb - sq) / (2 * qa);
          t2 = (-qb + sq) / (2 * qa);
        } else if (qa == 0 && qc <= 0) {
          t1 = 0;
          t2 = 1;
        }
        final insideFrom = t1.clamp(0.0, 1.0), insideTo = t2.clamp(0.0, 1.0);
        final hits = t1 < 1 && t2 > 0;
        if (!hits) {
          if (cur.isEmpty) cur.add(line[i - 1]);
          cur.add(line[i]);
          continue;
        }
        if (insideFrom > 0) {
          if (cur.isEmpty) cur.add(line[i - 1]);
          cur.add(toLL(a.x + dx * insideFrom, a.y + dy * insideFrom));
        }
        close();
        if (insideTo < 1) {
          cur.add(toLL(a.x + dx * insideTo, a.y + dy * insideTo));
          cur.add(line[i]);
        }
      }
      close();
    }
    current = next;
  }
  return [
    for (final l in current)
      if (l.length >= 2 && _pathLen(l, 0, l.length - 1) >= minLen) l,
  ];
}

/// [p] ga eng yaqin chiziq nuqtasi (kesmalarga proyeksiya) — [maxDist]
/// metrdan uzoq bo'lsa `null` (xodim haqiqatan chiziqdan chetda bo'lgan).
({double lat, double lng})? nearestOnLines(
  ({double lat, double lng}) p,
  List<List<({double lat, double lng})>> lines, {
  double maxDist = 60,
}) {
  final kx = math.cos(p.lat * math.pi / 180);
  ({double lat, double lng})? best;
  var bestD = maxDist;
  for (final line in lines) {
    for (var i = 0; i < line.length; i++) {
      final a = line[i];
      final b = i + 1 < line.length ? line[i + 1] : a;
      // Mahalliy tekis koordinatalar (gradus, uzunlik kenglikka moslangan).
      final ax = (a.lng - p.lng) * kx, ay = a.lat - p.lat;
      final bx = (b.lng - p.lng) * kx, by = b.lat - p.lat;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final q = (
        lat: a.lat + (b.lat - a.lat) * t,
        lng: a.lng + (b.lng - a.lng) * t,
      );
      final d = distanceMeters(p.lat, p.lng, q.lat, q.lng);
      if (d < bestD) {
        bestD = d;
        best = q;
      }
    }
  }
  return best;
}

/// Uchlari tutashgan ketma-ket chiziqlarni bitta chiziqqa birlashtiradi
/// (masalan, turish nuqtasida biri tugab, keyingisi boshlangan) —
/// [removeSpurs] chiziqlar chegarasidagi dumchani ham ko'rsin.
List<List<({double lat, double lng})>> joinTouchingLines(
  List<List<({double lat, double lng})>> lines, {
  double tolerance = 3,
}) {
  final out = <List<({double lat, double lng})>>[];
  for (final l in lines) {
    if (l.isEmpty) continue;
    if (out.isNotEmpty) {
      final prev = out.last;
      final e = prev.last, s = l.first;
      final d = distanceMeters(e.lat, e.lng, s.lat, s.lng);
      if (d <= tolerance) {
        prev.addAll(d <= 3 ? l.skip(1) : l);
        continue;
      }
    }
    out.add([...l]);
  }
  return out;
}
