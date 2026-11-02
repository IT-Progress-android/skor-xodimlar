import 'package:skore_hodimlar/features/rahbar/data/speed_track.dart';
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';

/// Rahbar xaritasida xodim markerini **silliq** siljitish.
///
/// Telefon nuqtalarni 10 soniyalik paket bilan yuboradi, xarita ham 10
/// soniyada bir so'raydi — marker sakrab yurardi. Professional ilovalardagi
/// kabi bu yerda kelgan haqiqiy nuqtalar real tezlikda, ozgina kechikish
/// ([buffer]) bilan "qayta o'ynatiladi": marker xodim yurgan yo'l bo'ylab
/// uzluksiz harakatlanadi.
///
/// Har xodimning o'z soati bor (`offset`): telefon va rahbar soatlari farq
/// qilsa ham ishlaydi — faqat bitta manbadagi vaqtlar o'zaro solishtiriladi.
class LivePlayback {
  LivePlayback({
    this.buffer = const Duration(seconds: 12),
    this.keep = const Duration(minutes: 3),
    this.maxLag = const Duration(seconds: 40),
  });

  /// Qayta o'ynatish oxirgi nuqtadan shuncha orqada boshlanadi: keyingi
  /// paket kelguncha marker to'xtab qolmasin.
  final Duration buffer;

  /// Shundan eski (o'ynab bo'lingan) nuqtalar o'chiriladi.
  final Duration keep;

  /// Ma'lumot shundan ko'p kechiksa — marker eng yangi joyga "sakraydi"
  /// (rahbar eskirgan harakatni tomosha qilib o'tirmasin).
  final Duration maxLag;

  final Map<int, _Track> _tracks = {};

  /// Yangi nuqtalar. [source] o'zgarsa (masalan, `live` → `tail`), iz
  /// boshidan boshlanadi — turli soatdagi vaqtlar aralashmasin.
  void push(
    int id,
    List<TimedPoint> points, {
    required String source,
    required DateTime now,
  }) {
    if (points.isEmpty) return;
    var t = _tracks[id];
    if (t == null || t.source != source) {
      t = _tracks[id] = _Track(source);
    }
    final lastBefore = t.points.isEmpty ? null : t.points.last;
    for (final p in points) {
      if (t.points.isEmpty || p.time.isAfter(t.points.last.time)) {
        t.points.add(p);
      }
    }
    final newest = t.points.last;
    if (identical(newest, lastBefore)) return;

    if (t.offset == null) {
      t.offset = now.difference(newest.time.subtract(buffer));
    } else {
      final play = now.subtract(t.offset!);
      if (newest.time.difference(play) > maxLag) {
        // Juda orqada qoldik — yangi joydan davom etamiz.
        t.offset = now.difference(newest.time.subtract(buffer));
      } else if (lastBefore != null && play.isAfter(lastBefore.time)) {
        // Marker oxirgi nuqtada kutib turgan edi — o'sha joydan silliq
        // davom etadi (sakramaydi).
        t.offset = now.difference(lastBefore.time);
      }
    }
    _trim(t, now);
  }

  void _trim(_Track t, DateTime now) {
    final play = now.subtract(t.offset!);
    final cutoff = play.subtract(keep);
    // Interpolyatsiya uchun o'ynatish nuqtasidan oldingi bittasi qoladi.
    while (t.points.length > 2 && t.points[1].time.isBefore(cutoff)) {
      t.points.removeAt(0);
    }
  }

  /// Xodim izining manbasi (`live`, `tail`); izi yo'q bo'lsa `null`.
  String? sourceOf(int id) => _tracks[id]?.source;

  /// Marker hozir ko'rsatayotgan vaqt — o'sha manbaning soatida. Tarix
  /// chizig'i shu vaqtdan oldinga chizilmaydi (marker ortda qolmasin).
  DateTime? playTime(int id, DateTime now) {
    final offset = _tracks[id]?.offset;
    return offset == null ? null : now.subtract(offset);
  }

  /// Markerning hozirgi (silliq) joyi; ma'lumot yo'q bo'lsa `null`.
  LatLng? position(int id, DateTime now) {
    final t = _tracks[id];
    if (t == null || t.points.isEmpty || t.offset == null) return null;
    return _at(t.points, now.subtract(t.offset!));
  }

  /// Marker hali harakatlanyaptimi (o'ynaladigan nuqtalar bor va joy
  /// o'zgaryapti) — animatsiya taymerini shunga qarab ishlatish mumkin.
  bool isMoving(int id, DateTime now) {
    final t = _tracks[id];
    if (t == null || t.points.length < 2 || t.offset == null) return false;
    final play = now.subtract(t.offset!);
    if (!play.isBefore(t.points.last.time)) return false;
    final first = t.points.first, last = t.points.last;
    return distanceMeters(first.lat, first.lng, last.lat, last.lng) > 2;
  }

  bool anyMoving(DateTime now) => _tracks.keys.any((id) => isMoving(id, now));

  /// Ro'yxatda yo'q xodimlarning izlari o'chiriladi.
  void retain(Set<int> ids) =>
      _tracks.removeWhere((id, _) => !ids.contains(id));

  void clear(int id) => _tracks.remove(id);

  static LatLng _at(List<TimedPoint> pts, DateTime play) {
    if (!play.isAfter(pts.first.time)) {
      return (lat: pts.first.lat, lng: pts.first.lng);
    }
    for (var i = 1; i < pts.length; i++) {
      final b = pts[i];
      if (play.isAfter(b.time)) continue;
      final a = pts[i - 1];
      final span = b.time.difference(a.time).inMilliseconds;
      final k = span <= 0 ? 1.0 : play.difference(a.time).inMilliseconds / span;
      return (
        lat: a.lat + (b.lat - a.lat) * k,
        lng: a.lng + (b.lng - a.lng) * k,
      );
    }
    return (lat: pts.last.lat, lng: pts.last.lng);
  }
}

class _Track {
  _Track(this.source);

  final String source;
  final List<TimedPoint> points = [];
  Duration? offset;
}
