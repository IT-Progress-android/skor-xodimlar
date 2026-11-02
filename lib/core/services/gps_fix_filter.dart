import 'package:geolocator/geolocator.dart';

/// Filtrdan o'tgan GPS nuqtasi (yuborishga tayyor).
typedef AcceptedFix = ({
  double lat,
  double lng,
  DateTime time,
  double accuracy,
  double speed,
});

/// Xodim telefonidagi GPS o'lchovlarini serverga yuborishdan oldin
/// tozalaydi. Zonic ilovasidagi (yugurish izi aniq chiziladigan) filtrlar
/// asosida:
///
/// 1. **Aniqlik** — [maxAccuracy] (50 m) dan yomon o'lchov tashlanadi.
/// 2. **Turish** — telefon bir joyda turganda GPS "titraydi". Nuqta oxirgi
///    qabul qilinganidan "drift doirasi" (aniqlik × 1,5, 10–30 m) ichida va
///    harakat tasdig'i yo'q bo'lsa — tashlanadi. Harakat qabul qilinadi:
///    Doppler tezligi ≥ 0,7 m/s ketma-ket 2 marta, yoki doiradan tashqarida
///    ketma-ket 3 marta (Doppler bermaydigan telefonlar uchun).
/// 3. **Juda yaqin** — moslashuvchan minimal masofa: aniqlik ≤ 20 m bo'lsa
///    3 m, aks holda aniqlik × 0,3 (3–15 m).
/// 4. **Sakrash** — oldingi nuqtadan hisoblangan tezlik [maxSpeed] dan katta
///    bo'lsa (GPS xatosi) — tashlanadi.
/// 5. **Bino yonida** (aniqlik > 20 m) — o'lchov oldingi harakat yo'nalishi
///    bo'yicha kutilgan joy bilan aralashtiriladi (silliqlash).
///
/// Vaqt sifatida GPS o'lchangan vaqt (`timestamp`) ishlatiladi.
class GpsFixFilter {
  GpsFixFilter({this.maxSpeed = 45});

  static const double maxAccuracy = 50;
  static const double goodAccuracy = 20;
  static const double minDistance = 3;

  /// Xodim mashinada ham yuradi — Zonic'dagi yugurish chegarasi (12 m/s)
  /// o'rniga ~160 km/soat.
  final double maxSpeed;

  final List<AcceptedFix> _recent = [];
  int _movingStreak = 0;
  int _escapeStreak = 0;

  AcceptedFix? get last => _recent.isEmpty ? null : _recent.last;

  // Bir joyda turgan paytdagi o'lchovlar yig'indisi (vazn = 1 / aniqlik²).
  double _stayW = 0, _stayLat = 0, _stayLng = 0, _stayBestAcc = 0;
  int _stayN = 0;

  /// Bir joyda turgan joyning aniq bahosi: oxirgi qabul qilingan nuqtadan
  /// beri kelgan **hamma** o'lchovlarning aniqlik bo'yicha og'irlikli
  /// o'rtachasi. Birinchi kelgan o'lchov ko'pincha bino yonida 20–40 m
  /// chetda bo'ladi; vaqt o'tishi bilan baho haqiqiy joyga yaqinlashadi.
  /// O'lchovlar kam bo'lsa (< 3) — [last].
  AcceptedFix? get standing {
    final l = last;
    if (l == null || _stayN < 3 || _stayW == 0) return l;
    return (
      lat: _stayLat / _stayW,
      lng: _stayLng / _stayW,
      time: l.time,
      accuracy: _stayBestAcc,
      speed: 0,
    );
  }

  void _addStay(double lat, double lng, double acc) {
    final a = acc < 3 ? 3.0 : acc;
    final w = 1 / (a * a);
    _stayW += w;
    _stayLat += lat * w;
    _stayLng += lng * w;
    _stayN++;
    if (_stayBestAcc == 0 || acc < _stayBestAcc) _stayBestAcc = acc;
  }

  void _resetStay() {
    _stayW = _stayLat = _stayLng = _stayBestAcc = 0;
    _stayN = 0;
  }

  /// Qabul qilinsa — yuboriladigan nuqta, aks holda `null`.
  AcceptedFix? accept(Position pos) {
    final acc = pos.accuracy;
    final speed = pos.speed >= 0 ? pos.speed : 0.0;
    final time = pos.timestamp.toLocal();
    if (acc > maxAccuracy) return null;

    final prev = last;
    if (prev == null) {
      return _keep(pos.latitude, pos.longitude, time, acc, speed);
    }
    if (!time.isAfter(prev.time)) return null;

    final dist = Geolocator.distanceBetween(
      prev.lat,
      prev.lng,
      pos.latitude,
      pos.longitude,
    );

    // 2. Turish: drift doirasi ichida harakat tasdig'isiz — titrash.
    final driftRadius = (acc * 1.5).clamp(10.0, 30.0);
    final dopplerMoving = pos.speed >= 0.7;
    _movingStreak = dopplerMoving ? _movingStreak + 1 : 0;
    final escaped = dist >= driftRadius;
    if (!escaped && _movingStreak < 2) {
      _escapeStreak = 0;
      _addStay(pos.latitude, pos.longitude, acc);
      return null;
    }
    if (escaped && !dopplerMoving && _movingStreak == 0) {
      _escapeStreak++;
      if (_escapeStreak < 3) return null;
    }
    _escapeStreak = 0;

    // 3. Juda yaqin.
    final minDist = acc <= goodAccuracy
        ? minDistance
        : (acc * 0.3).clamp(minDistance, 15.0);
    if (dist < minDist) return null;

    // 4. Sakrash (hisoblangan tezlik).
    final dt = time.difference(prev.time).inMilliseconds / 1000;
    if (dt > 0 && dist / dt > maxSpeed) return null;

    // 5. Bino yonida silliqlash.
    var lat = pos.latitude;
    var lng = pos.longitude;
    if (acc > goodAccuracy && _recent.length >= 2) {
      final p0 = _recent[_recent.length - 2];
      final dt1 = prev.time.difference(p0.time).inMilliseconds / 1000;
      if (dt1 > 0 && dt > 0) {
        final predLat = prev.lat + (prev.lat - p0.lat) / dt1 * dt;
        final predLng = prev.lng + (prev.lng - p0.lng) / dt1 * dt;
        final alpha = (goodAccuracy / acc).clamp(0.4, 0.8);
        lat = alpha * lat + (1 - alpha) * predLat;
        lng = alpha * lng + (1 - alpha) * predLng;
      }
    }
    return _keep(lat, lng, time, acc, speed);
  }

  AcceptedFix _keep(
    double lat,
    double lng,
    DateTime time,
    double acc,
    double speed,
  ) {
    final f = (lat: lat, lng: lng, time: time, accuracy: acc, speed: speed);
    _resetStay();
    _addStay(lat, lng, acc);
    _recent.add(f);
    if (_recent.length > 3) _recent.removeAt(0);
    return f;
  }

  /// Zonaga kirganda yoki sessiya qayta boshlanganda — iz yangidan.
  void reset() {
    _recent.clear();
    _resetStay();
    _movingStreak = 0;
    _escapeStreak = 0;
  }
}
