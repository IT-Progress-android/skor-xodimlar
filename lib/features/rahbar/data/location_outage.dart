import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart'
    show distanceMeters;

/// Ish vaqtida xodim lokatsiyasining uzilishi (server aniqlaydi, qarang
/// `LOKATSIYA_UZILISHI_NAZORATI.md`).
///
/// Sabab kodlari:
/// - `location_off` — GPS o'chirildi
/// - `permission_denied` / `permission_reduced` — ruxsat olib tashlandi
///   yoki «Faqat foydalanganda» qilindi
/// - `precision_reduced` — aniq joylashuv o'chirildi
/// - `phone_died` — telefon quvvati tugadi (qoidabuzarlik emas)
/// - `no_internet` — internet yo'q edi, yo'l keyin yetib keldi
///   (qoidabuzarlik emas)
/// - `no_signal` — sababi noma'lum (telefon o'chirildi, ilova majburan
///   yopildi va h.k.)
const locationOutageReasons = {
  'location_off',
  'permission_denied',
  'permission_reduced',
  'precision_reduced',
  'phone_died',
  'no_internet',
  'no_signal',
};

String _reason(Object? v) {
  final s = v?.toString().trim() ?? '';
  return locationOutageReasons.contains(s) ? s : 'no_signal';
}

int? _int(Object? v) => v is num ? v.round() : int.tryParse('${v ?? ''}');

/// Rahbar xaritasidagi "Signal yo'q" holati — `/rahbar/lokatsiya/live`
/// elementidagi `signal_holat: "yoq"`, `signal_sabab`, `signal_yoq_min`.
class SignalLoss {
  const SignalLoss({required this.reason, this.minutes});

  final String reason;
  final int? minutes;

  /// Signal bor yoki backend maydonni hali bermasa — `null`.
  static SignalLoss? fromLive(Map<dynamic, dynamic>? item) {
    if (item == null) return null;
    if (item['signal_holat']?.toString() != 'yoq') return null;
    return SignalLoss(
      reason: _reason(item['signal_sabab']),
      minutes: _int(item['signal_yoq_min']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SignalLoss && other.reason == reason && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(reason, minutes);
}

/// Xodim kartasidagi bitta uzilish.
class LocationOutage {
  const LocationOutage({
    required this.from,
    this.to,
    required this.reason,
    required this.minutes,
    required this.violation,
  });

  final DateTime from;

  /// Hali davom etayotgan bo'lsa — `null`.
  final DateTime? to;
  final String reason;
  final int minutes;

  /// Qoidabuzarlik sanaladimi (`phone_died` va `no_internet` — yo'q).
  final bool violation;

  bool get ongoing => to == null;

  static LocationOutage? fromJson(Map<String, dynamic> j) {
    final from = DateTime.tryParse('${j['boshlandi'] ?? j['from'] ?? ''}');
    if (from == null) return null;
    final to = DateTime.tryParse('${j['tugadi'] ?? j['to'] ?? ''}');
    final reason = _reason(j['sabab'] ?? j['reason']);
    final minutes =
        _int(j['davomiylik_min'] ?? j['minutes']) ??
        (to ?? DateTime.now()).difference(from).inMinutes;
    return LocationOutage(
      from: from.toLocal(),
      to: to?.toLocal(),
      reason: reason,
      minutes: minutes,
      violation:
          j['qoidabuzarlik'] as bool? ??
          (reason != 'phone_died' && reason != 'no_internet'),
    );
  }
}

/// `GET /rahbar/lokatsiya/uzilishlar/{id}` javobi. `null` — endpoint hali
/// yo'q yoki javob boshqa ko'rinishda (karta bo'limi ko'rsatilmaydi).
List<LocationOutage>? parseLocationOutages(Map<String, dynamic> data) {
  final raw = data['uzilishlar'];
  if (raw is! List) return null;
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => LocationOutage.fromJson(Map<String, dynamic>.from(e)))
      .whereType<LocationOutage>()
      .toList()
    ..sort((a, b) => b.from.compareTo(a.from));
}

/// Uzilish belgisi qo'yiladigan GPS nuqtasi uzilish vaqtidan shuncha uzoq
/// bo'lmasligi kerak — aks holda xodim o'sha paytda qayerdaligi aniq emas
/// va belgi yolg'on bo'ladi. Haqiqiy ma'lumotda (10 xodim, 44 uzilish)
/// nuqtalar uzilish vaqtiga bir necha soniya–daqiqa yaqin, ba'zan undan
/// keyin keladi (server signal yo'qligini kechikib aniqlaydi): ±5 daqiqa
/// 44 tadan 36 tasida kamida bitta aniq belgi beradi.
const outageAnchorMaxAge = Duration(minutes: 5);

({double lat, double lng})? _nearestInTime(
  DateTime at,
  List<({double lat, double lng, DateTime time})> route,
  Duration maxAge,
) {
  ({double lat, double lng, DateTime time})? best;
  var bestD = maxAge;
  for (final p in route) {
    final d = p.time.difference(at).abs();
    if (d <= bestD) {
      bestD = d;
      best = p;
    }
  }
  return best == null ? null : (lat: best.lat, lng: best.lng);
}

/// Nuqta xodimning ish hududi ichidami. Hudud ichida ilova GPS nuqtasini
/// siyrak yuboradi (xodim joyida turibdi) — u yerda oxirgi nuqta soatlab
/// oldin bo'lsa ham, xodim hududdan chiqmagan ekan, joy aniq.
typedef InZone = bool Function(double lat, double lng);

/// Uzilgan joy:
/// 1. uzilish boshlangan paytga eng yaqin GPS nuqtasi ([maxAge] ichida);
/// 2. bo'lmasa — undan oldingi so'nggi nuqta, agar u hudud ichida va
///    keyingi nuqta ham hudud ichida (yoki yo'q) bo'lsa: xodim hududdan
///    chiqmagan, uzilish shu yerda.
/// Aks holda `null` — o'sha paytdagi joy noma'lum, belgi qo'yilmaydi
/// (uzilish ro'yxatda qoladi). [route] vaqt bo'yicha tartiblangan.
({double lat, double lng})? outageAnchor(
  LocationOutage o,
  List<({double lat, double lng, DateTime time})> route, {
  Duration maxAge = outageAnchorMaxAge,
  InZone? inZone,
}) {
  final near = _nearestInTime(o.from, route, maxAge);
  if (near != null || inZone == null) return near;
  final i = route.lastIndexWhere((p) => !p.time.isAfter(o.from));
  if (i < 0) return null;
  final p = route[i];
  final next = i + 1 < route.length ? route[i + 1] : null;
  if (!inZone(p.lat, p.lng)) return null;
  if (next != null && !inZone(next.lat, next.lng)) return null;
  return (lat: p.lat, lng: p.lng);
}

/// Qayta ulangan joy: uzilish tugagan paytga eng yaqin GPS nuqtasi
/// ([maxAge] ichida); bo'lmasa — keyingi birinchi nuqta, agar u va undan
/// oldingi nuqta hudud ichida (yoki oldingi yo'q) bo'lsa. Uzilish davom
/// etsa yoki joy noma'lum bo'lsa — `null`.
({double lat, double lng})? outageEndAnchor(
  LocationOutage o,
  List<({double lat, double lng, DateTime time})> route, {
  Duration maxAge = outageAnchorMaxAge,
  InZone? inZone,
}) {
  final to = o.to;
  if (to == null) return null;
  final near = _nearestInTime(to, route, maxAge);
  if (near != null || inZone == null) return near;
  final i = route.indexWhere((p) => !p.time.isBefore(to));
  if (i < 0) return null;
  final p = route[i];
  final prev = i > 0 ? route[i - 1] : null;
  if (!inZone(p.lat, p.lng)) return null;
  if (prev != null && !inZone(prev.lat, prev.lng)) return null;
  return (lat: p.lat, lng: p.lng);
}

/// Server bitta uzilishni bir necha yozuvga bo'lib beradi (sabab
/// almashganda: signal yo'q → internet yo'q, yoki 10–40 soniyalik
/// "ulanish" bilan). Xaritada o'rtada ortiqcha belgilar chalg'itadi, shuning
/// uchun uzilishlar orasidagi tanaffus [maxGap] dan qisqa (yoki ustma-ust)
/// bo'lsa — bitta uzilish: boshi va sababi birinchisidan, oxiri
/// oxirgisidan; bittasi qoidabuzarlik bo'lsa — butuni qoidabuzarlik.
/// Haqiqiy qayta ulanish (uzunroq tanaffus) bo'lsa — alohida qoladi.
/// 1 daqiqadan qisqa, tugagan uzilishlar (shovqin) tashlanadi.
const outageMergeGap = Duration(minutes: 2);

List<LocationOutage> mergeOutages(
  List<LocationOutage> items, {
  Duration maxGap = outageMergeGap,
}) {
  final sorted = [...items]..sort((a, b) => a.from.compareTo(b.from));
  final out = <LocationOutage>[];
  for (final o in sorted) {
    if (out.isNotEmpty) {
      final prev = out.last;
      final prevTo = prev.to;
      if (prevTo == null || o.from.difference(prevTo) <= maxGap) {
        final to = prevTo == null || o.to == null
            ? null
            : (o.to!.isAfter(prevTo) ? o.to : prevTo);
        out[out.length - 1] = LocationOutage(
          from: prev.from,
          to: to,
          reason: prev.reason,
          minutes: (to ?? DateTime.now()).difference(prev.from).inMinutes,
          violation: prev.violation || o.violation,
        );
        continue;
      }
    }
    out.add(o);
  }
  return [
    for (final o in out)
      if (o.ongoing || o.to!.difference(o.from) >= const Duration(minutes: 1))
        o,
  ];
}

/// Shundan qisqa nuqtasiz bo'shliq uzilish sanalmaydi: telefon bir joyda
/// turganda nuqtalarni 3–9 daqiqa oralig'ida yuborishi mumkin.
const outageMinGap = Duration(minutes: 10);

/// Signal shundan qisqa qaytgan bo'lsa (telefon "uxlab", vaqti-vaqti bilan
/// bittadan nuqta yuborsa) — ikki tomondagi uzilish bitta sanaladi.
const outageMaxBlip = Duration(minutes: 5);

/// Server uzilish oynasi ichida GPS nuqtalari kelib turgan bo'lishi
/// mumkin (server uzilishni nuqta kelganda yopmaydi). Shuning uchun
/// uzilish faqat GPS nuqtalari rostdan kelmagan [minGap] dan uzun
/// bo'shliqlarga kesiladi. Avval ketma-ket server yozuvlari birlashtiriladi
/// ([mergeOutages]), so'ng har bo'lakka eng ko'p ustma-ust tushgan server
/// yozuvining sababi va qoidabuzarligi beriladi. Signal [maxBlip] dan
/// qisqa qaytgan bo'laklar bitta uzilishga qo'shiladi. [points] — tarixdagi
/// barcha nuqtalar vaqti (aniqligidan qat'i nazar: nuqta keldi — signal bor).
List<LocationOutage> outagesFromPoints(
  List<LocationOutage> raw,
  List<DateTime> points, {
  Duration minGap = outageMinGap,
  Duration maxBlip = outageMaxBlip,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final times = [...points]..sort();
  final out = <LocationOutage>[];
  for (final w in mergeOutages(raw)) {
    final end = w.to ?? at;
    final inside = [
      for (final t in times)
        if (t.isAfter(w.from) && t.isBefore(end)) t,
    ];
    if (inside.isEmpty) {
      out.add(w);
      continue;
    }
    final edges = [w.from, ...inside, end];
    for (var i = 0; i + 1 < edges.length; i++) {
      final a = edges[i], b = edges[i + 1];
      if (b.difference(a) < minGap) continue;
      final src = _mostOverlapping(raw, a, b) ?? w;
      final ongoing = w.ongoing && i + 2 == edges.length;
      final prev = out.lastOrNull;
      if (prev != null && a.difference(prev.to ?? a) <= maxBlip) {
        out[out.length - 1] = LocationOutage(
          from: prev.from,
          to: ongoing ? null : b,
          reason: prev.reason,
          minutes: b.difference(prev.from).inMinutes,
          violation: prev.violation || src.violation,
        );
        continue;
      }
      out.add(
        LocationOutage(
          from: a,
          to: ongoing ? null : b,
          reason: src.reason,
          minutes: b.difference(a).inMinutes,
          violation: src.violation,
        ),
      );
    }
  }
  return out;
}

LocationOutage? _mostOverlapping(
  List<LocationOutage> items,
  DateTime a,
  DateTime b,
) {
  LocationOutage? best;
  var bestOverlap = Duration.zero;
  for (final o in items) {
    final from = o.from.isAfter(a) ? o.from : a;
    final to = o.to == null || o.to!.isAfter(b) ? b : o.to!;
    final overlap = to.difference(from);
    if (overlap > bestOverlap) {
      best = o;
      bestOverlap = overlap;
    }
  }
  return best;
}

/// Belgi chiziqning aynan uchida turishi uchun: GPS nuqtasiga eng yaqin
/// chiziq uchi ([maxDist] ichida). Chiziq chizilganda oxirgi qisqa "dum"
/// kesilishi mumkin — belgi chiziq tugagan joyda bo'lsin, chetda emas.
/// Yaqin uch bo'lmasa — `null` (chaqiruvchi chiziqning o'ziga suradi).
({double lat, double lng})? nearestLineEnd(
  ({double lat, double lng}) p,
  List<List<({double lat, double lng})>> lines, {
  double maxDist = 80,
}) {
  ({double lat, double lng})? best;
  var bestD = maxDist;
  for (final l in lines) {
    if (l.isEmpty) continue;
    for (final e in [l.first, l.last]) {
      final d = distanceMeters(p.lat, p.lng, e.lat, e.lng);
      if (d <= bestD) {
        bestD = d;
        best = e;
      }
    }
  }
  return best;
}

/// Xaritadagi bitta uzilish belgisi. Bir joyda (bir necha o'n metr ichida)
/// bo'lgan uzilishlar bitta belgiga yig'iladi — vaqtlar ustma-ust tushib
/// o'qib bo'lmay qolmasin; belgida birinchisining vaqti va "+N".
typedef OutageMark = ({
  ({double lat, double lng}) at,
  bool start,
  DateTime time,
  List<LocationOutage> outages,
});

/// Uzilishlar belgilari: uzilgan joy ([outageAnchor]) va qayta ulangan joy
/// ([outageEndAnchor]). Qayta ulangan joy biror uzilgan joyga
/// [endNearStart] dan yaqin bo'lsa (xodim bir joyda turibdi) — alohida
/// halqa chizilmaydi, uzilish o'sha belgiga qo'shiladi (yo'qolmaydi).
/// [groupDist] ichidagi belgilar bittaga yig'iladi.
List<OutageMark> outageMarks(
  List<LocationOutage> outages,
  List<({double lat, double lng, DateTime time})> route, {
  double groupDist = 40,
  double endNearStart = 120,
  InZone? inZone,
}) {
  final starts = [
    for (final o in outages)
      if (outageAnchor(o, route, inZone: inZone) case final at?) (o, at),
  ];
  final cands = <(LocationOutage, ({double lat, double lng}), bool, DateTime)>[
    for (final (o, at) in starts) (o, at, true, o.from),
  ];
  final joinStart = <(LocationOutage, ({double lat, double lng}))>[];
  for (final o in outages) {
    final at = outageEndAnchor(o, route, inZone: inZone);
    if (at == null) continue;
    final near = starts.where(
      (s) => distanceMeters(at.lat, at.lng, s.$2.lat, s.$2.lng) < endNearStart,
    );
    if (near.isEmpty) {
      cands.add((o, at, false, o.to!));
    } else {
      joinStart.add((o, near.first.$2));
    }
  }
  cands.sort((a, b) => a.$4.compareTo(b.$4));
  final marks = <OutageMark>[];
  void put(
    LocationOutage o,
    ({double lat, double lng}) at,
    bool start,
    DateTime time,
  ) {
    final i = marks.indexWhere(
      (m) => distanceMeters(at.lat, at.lng, m.at.lat, m.at.lng) < groupDist,
    );
    if (i < 0) {
      marks.add((at: at, start: start, time: time, outages: [o]));
    } else if (!marks[i].outages.contains(o)) {
      final m = marks[i];
      marks[i] = (
        at: m.at,
        start: m.start,
        time: m.time,
        outages: [...m.outages, o]..sort((a, b) => a.from.compareTo(b.from)),
      );
    }
  }

  for (final (o, at, start, time) in cands) {
    put(o, at, start, time);
  }
  for (final (o, at) in joinStart) {
    put(o, at, true, o.from);
  }
  return marks;
}
