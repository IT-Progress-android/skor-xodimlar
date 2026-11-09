import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/services/auth_token_store.dart';
import 'package:skore_hodimlar/core/services/gps_fix_filter.dart';
import 'package:skore_hodimlar/core/services/gps_offline_queue.dart';
import 'package:skore_hodimlar/core/services/location_heartbeat.dart';
import 'package:skore_hodimlar/features/attendance/data/datasources/geofence_remote_datasource.dart';
import 'package:skore_hodimlar/features/attendance/data/models/geofence_zone_model.dart';

/// Zonadan tashqarida real vaqt: har soniyada nuqta yuboriladi.
const outsidePingInterval = Duration(seconds: 1);

/// Zonadan tashqarida nuqtalar shunda bir marta **paket** bo'lib yuboriladi.
/// GPS baribir har soniyada o'qiladi va har nuqta o'z `recorded_at` vaqti
/// bilan ketadi — marshrut aniqligi o'zgarmaydi, faqat so'rovlar soni
/// ~10 baravar kamayadi (1000 lab xodimda server yuklamasi).
const outsideBatchInterval = Duration(seconds: 10);

/// Bir joyda turganda (titrash tashlanadi, yangi nuqta yo'q) shunda bir
/// marta "shu yerdaman" nuqtasi yuboriladi — server 45 s da "eskirgan"
/// demasin.
const stationaryHeartbeat = Duration(seconds: 20);

/// Uzluksiz 1 Hz GPS oqimi (Zonic bilan bir xil): Android — aniq 1 soniya
/// oralig'i, iOS — fonda to'xtamaydigan navigatsiya rejimi.
LocationSettings gpsStreamSettings() {
  if (Platform.isIOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
      activityType: ActivityType.otherNavigation,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    );
  }
  return AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 2,
    intervalDuration: outsidePingInterval,
  );
}

/// Ofisdan tashqarida GPS nuqtasini yuborish kerakmi: oxirgisidan beri
/// [outsidePingInterval] o'tgan va telefon **yangi** GPS o'lchovi bergan
/// bo'lsa (o'sha eski nuqta qayta yuborilmaydi — faqat real ma'lumot).
@visibleForTesting
bool shouldSendOutsidePing({
  required DateTime? lastTime,
  required Position? lastPos,
  required Position pos,
  DateTime? now,
}) {
  if (lastTime == null || lastPos == null) return true;
  if (pos.timestamp == lastPos.timestamp &&
      pos.latitude == lastPos.latitude &&
      pos.longitude == lastPos.longitude) {
    return false;
  }
  final t = now ?? DateTime.now();
  return t.difference(lastTime) >= outsidePingInterval;
}

/// Keyinroq qayta yuborish kerak bo'lgan javob: server vaqtincha ishlamaydi
/// (5xx, 429, 408) yoki token hali yangilanmagan (401). 401 da nuqtani
/// tashlab yuborish — xodim qayta kirguncha yurgan yo'lining yo'qolishi.
@visibleForTesting
bool isRetryableGpsStatus(int code) =>
    code >= 500 || code == 429 || code == 408 || code == 401;

/// Paketga qo'shishdan oldingi tekshiruv. Backend `/lokatsiya/paket`ni
/// bitta `validate()` bilan tekshiradi: bitta yaroqsiz nuqta (lat/lng
/// oralig'idan tashqari yoki `recorded_at` yo'q/buzuq) butun paketni `422`
/// bilan rad ettiradi — shuning uchun bunday nuqta paketga qo'shilmaydi.
@visibleForTesting
bool isValidGpsPaketPoint(Map<String, dynamic> body) {
  final lat = body['lat'];
  final lng = body['lng'];
  if (lat is! num || lng is! num) return false;
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  final at = body['recorded_at'];
  return at is String && DateTime.tryParse(at) != null;
}

/// Doppler tezligi (m/s) serverga 1 xona aniqlikda: butun songa yaxlitlansa
/// 1,4 m/s (piyoda) 1 bo'lib, piyoda/avto farqi yo'qoladi. Telefon tezlikni
/// bilmasa (manfiy, masalan iOS'da -1) — `null`.
@visibleForTesting
double? gpsSpeedForServer(double speed) {
  if (speed.isNaN || speed < 0) return null;
  return (speed * 10).round() / 10;
}

/// Fon servisi har tick'da yozadigan vaqt belgisi (millisekund).
const gpsServiceHeartbeatKey = 'gps_service_heartbeat';

/// Ochiq ish sessiyasi ("Keldim"dan "Ketdim"gacha) tugaydigan vaqt
/// (millisekund). Yo'q yoki o'tib ketgan bo'lsa — xodim ishda emas va GPS
/// olinmaydi. Ikkala izolyator ham FlutterForegroundTask omboridan o'qiydi.
const workSessionUntilKey = 'work_session_until';

/// Server bergan `auto_ketdi_at` (asosiy smenada — ish vaqti tugashi,
/// qo'shimcha ishda — yarim tun). Kelmasa yoki o'qib bo'lmasa — bugungi
/// yarim tun: xodim "Ketdim"ni unutsa ham GPS ertangi kunga o'tmaydi.
@visibleForTesting
DateTime resolveWorkSessionEnd(String? autoKetdiAt, DateTime now) {
  final parsed = autoKetdiAt == null ? null : DateTime.tryParse(autoKetdiAt);
  if (parsed != null) return parsed.toLocal();
  return DateTime(now.year, now.month, now.day + 1);
}

/// Xodim hozir ishdami ("Keldim"dan "Ketdim"gacha) — lokatsiya nazorati
/// faqat shu vaqtda.
Future<bool> isWorkSessionOpen() => _workSessionOpen();

/// Fon servisining zona holati (ichkarida/qaysi zona). Sessiya yopilganda
/// va yangisi boshlanganda tozalanadi: aks holda ertasi kuni kechagi
/// "ichkarida" holati qolib, ENTER yuborilmasdi yoki kechagi zona ID'si
/// bilan EXIT ketardi.
const fgsInsideZoneKey = 'fgs_inside_zone';
const fgsCurrentZoneKey = 'fgs_current_zone_id';

@visibleForTesting
Future<void> clearFgsZoneState(SharedPreferences prefs) async {
  await prefs.remove(fgsInsideZoneKey);
  await prefs.remove(fgsCurrentZoneKey);
}

Future<bool> _workSessionOpen() async {
  try {
    final until =
        await FlutterForegroundTask.getData<int>(key: workSessionUntilKey) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < until;
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Foreground task callback — must be top-level (runs in separate isolate)
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
void startGpsTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_GpsTaskHandler());
}

class _GpsTaskHandler extends TaskHandler {
  /// Fon servisining zona holati asosiy ilovanikidan ALOHIDA saqlanadi:
  /// `getData` har chaqirilganda SharedPreferences'ni qayta yuklaydi, umumiy
  /// kalit bo'lsa asosiy ilova yozgan "chiqdi" holati fon servisining
  /// o'zini EXIT/ENTER yuborishdan to'xtatib qo'yardi.
  static const _fgsInsideKey = fgsInsideZoneKey;
  static const _fgsZoneKey = fgsCurrentZoneKey;

  /// Uzluksiz GPS oqimidan kelgan eng so'nggi o'lchov (har soniyada).
  StreamSubscription<Position>? _stream;
  Position? _latest;

  /// Har bir o'lchov filtrdan o'tadi; qabul qilinganlari navbat bilan
  /// yuboriladi (fonda bir nechta o'lchov birdan kelsa ham yo'qolmaydi).
  final GpsFixFilter _filter = GpsFixFilter();
  final List<AcceptedFix> _pending = [];
  DateTime? _lastPingAt;

  void _onFix(Position p) {
    _latest = p;
    final f = _filter.accept(p);
    if (f == null) return;
    _pending.add(f);
    if (_pending.length > 120) _pending.removeAt(0);
  }

  /// Ish vaqtidagi lokatsiya nazorati: GPS/ruxsat o'zgarishi darhol,
  /// "tirikman" daqiqada bir marta (zona ichida ham) serverga ketadi.
  late final LocationHeartbeat _heartbeat = LocationHeartbeat(
    onHealthChanged: _showHealthInNotification,
    onServerData: _applyTracking,
  );

  /// Lokatsiya o'chirilsa, doimiy fon bildirishnomasi ogohlantirishga
  /// aylanadi — xodim ilovani ochmasa ham ko'radi.
  static void _showHealthInNotification(LocationHealth h) {
    unawaited(
      FlutterForegroundTask.updateService(
        notificationTitle: AppLocalizations.trStatic(
          h.isOk ? 'gps_notification_title' : 'loc_alert_fgs_title',
        ),
        notificationText: AppLocalizations.trStatic(
          h.isOk ? 'gps_channel_desc' : 'loc_alert_fgs_text',
        ),
      ),
    );
  }

  /// Bitta tick hali tugamagan bo'lsa, keyingisi o'tkazib yuboriladi
  /// (tarmoq sekin bo'lsa ticklar ustma-ust tushmasin).
  bool _ticking = false;

  void _startStream() {
    if (_stream != null) return;
    try {
      _stream = Geolocator.getPositionStream(
        locationSettings: gpsStreamSettings(),
      ).listen(_onFix, onError: (_) {});
    } catch (_) {}
  }

  /// Fon izolyatorida DioClient (va undagi token interceptor'i) mavjud emas,
  /// shuning uchun sarlavhalarni qo'lda yig'amiz.
  static Map<String, String> _headers(String? token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _startStream();
    await _checkAndProcessLocation();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Har soniyada: zona chegarasi va zonadan tashqarida real vaqt nuqtasi.
    if (_ticking) return;
    _ticking = true;
    _checkAndProcessLocation().whenComplete(() => _ticking = false);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _stream?.cancel();
    _stream = null;
  }

  Future<void> _checkAndProcessLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone =
          (await FlutterForegroundTask.getData<String>(key: 'phone')) ??
          prefs.getString('phone') ??
          prefs.getString('staff_phone');
      if (phone == null || phone.isEmpty) {
        debugPrint('⏭️ [GPS FON] tick: telefon raqami yo\'q');
        return;
      }

      final token = await FlutterForegroundTask.getData<String>(
        key: 'api_token',
      );

      // Skip if rahbar/admin
      final role = prefs.getString('user_role') ?? '';
      if (role == 'admin' || role == 'rahbar') {
        debugPrint('⏭️ [GPS FON] tick: rol=$role, kuzatilmaydi');
        return;
      }

      // GPS faqat "Keldim"dan "Ketdim"gacha olinadi. Sessiya yopilgan
      // (ketdi, avto-ketdi vaqti o'tdi yoki server to'xtating dedi) bo'lsa,
      // navbatdagi nuqtalarni yuborib, servisni o'chiramiz.
      if (!await _workSessionOpen()) {
        debugPrint('⏹️ [GPS FON] ish sessiyasi yopiq — servis to\'xtatiladi');
        await clearFgsZoneState(prefs);
        await _queuePending(phone, pos: null);
        await _flushQueue(token);
        await FlutterForegroundTask.stopService();
        return;
      }

      // Internet qaytgan bo'lsa, oldin saqlangan nuqtalarni yuboramiz.
      await _flushQueue(token);

      // Lokatsiya nazorati — joylashuv olinmasa ham (GPS o'chiq bo'lsa
      // ham) ishlaydi, shuning uchun nuqta o'qishdan oldin.
      var healthPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (healthPhone.length == 9) healthPhone = '998$healthPhone';
      unawaited(
        _heartbeat.tick(
          phone: healthPhone,
          token: token,
          insideZone: prefs.getBool(_fgsInsideKey) ?? false,
          lastFixAt: _latest?.timestamp,
          queueSize: await _queue.length(),
        ),
      );

      // Oqimdagi so'nggi o'lchov (3 soniyadan yangi). Oqim hali bermagan
      // bo'lsa — bir martalik so'rov.
      _startStream();
      // GPS o'chiq: yangi joy olinmaydi. getCurrentPosition bu holatda har
      // soniyada Google'ning "lokatsiyani yoqing" oynasini ochib, xodimdagi
      // sanoqli ekranni yopib qo'yardi.
      if (!await Geolocator.isLocationServiceEnabled()) return;
      Position? pos = _latest;
      if (pos == null ||
          DateTime.now().difference(pos.timestamp).inSeconds > 3) {
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 6),
            ),
          );
        } catch (_) {
          pos = await Geolocator.getLastKnownPosition();
        }
      }

      if (pos == null) {
        debugPrint('⏭️ [GPS FON] tick: joylashuv olinmadi');
        return;
      }
      debugPrint(
        '🛰️ [GPS FON] tick ${DateTime.now().toIso8601String().substring(11, 19)} '
        'lat=${pos.latitude.toStringAsFixed(5)} lng=${pos.longitude.toStringAsFixed(5)} '
        'acc=${pos.accuracy.round()}m',
      );
      // Asosiy ilova fon servisi haqiqatan ishlayotganini shu belgidan biladi.
      await FlutterForegroundTask.saveData(
        key: gpsServiceHeartbeatKey,
        value: DateTime.now().millisecondsSinceEpoch,
      );

      var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 9) cleanPhone = '998$cleanPhone';

      final bool isMock = pos.isMocked;

      // Anti-Cheat: Report Fake GPS if detected
      if (isMock) {
        unawaited(
          _reportSecurityIncident(
            cleanPhone,
            'FAKE_GPS_DETECTED',
            'Mock location provider aniqlandi',
            token,
          ),
        );
      }

      // Load cached geofence zones
      final zonesJsonStr = prefs.getString('cached_geofence_zones_json');
      List<Map<String, dynamic>> rawZones = [];
      if (zonesJsonStr != null && zonesJsonStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(zonesJsonStr);
          if (decoded is List) {
            rawZones = List<Map<String, dynamic>>.from(decoded);
          }
        } catch (_) {}
      }

      bool isCurrentlyInside = false;
      int matchedZoneId = 0;
      String matchedZoneName = '';

      for (final z in rawZones) {
        final double zLat = (z['lat'] as num?)?.toDouble() ?? 0.0;
        final double zLng = (z['lng'] as num?)?.toDouble() ?? 0.0;
        final int zRadius = (z['radius_meter'] as num?)?.toInt() ?? 200;
        final int zId = (z['id'] as num?)?.toInt() ?? 0;
        final String zName = z['name']?.toString() ?? '';

        if (zLat != 0.0 && zLng != 0.0) {
          final dist = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            zLat,
            zLng,
          );
          if (dist <= zRadius) {
            isCurrentlyInside = true;
            matchedZoneId = zId;
            matchedZoneName = zName;
            break;
          }
        }
      }

      final bool wasInside = prefs.getBool(_fgsInsideKey) ?? false;
      final int lastZoneId = prefs.getInt(_fgsZoneKey) ?? 0;

      // Event: ENTER
      if (isCurrentlyInside && !wasInside) {
        // Zonaga kirishdan oldingi (hali yuborilmagan) tashqi nuqtalar —
        // hodisadan oldin, tartib bilan.
        await _queuePending(cleanPhone, pos: pos);
        await _sendGeofenceEvent(
          phone: cleanPhone,
          event: 'enter',
          locationId: matchedZoneId,
          lat: pos.latitude,
          lng: pos.longitude,
          accuracy: pos.accuracy,
          isMock: isMock,
          token: token,
        );
        await prefs.setBool(_fgsInsideKey, true);
        await prefs.setInt(_fgsZoneKey, matchedZoneId);
        // Zonadan keyingi chiqishda iz yangidan boshlanadi.
        _filter.reset();
        _pending.clear();
        debugPrint(
          '🚪 [GEOFENCE ISOLATE] ENTER event yuborildi: $matchedZoneName',
        );
        return;
      }

      // Event: EXIT
      if (!isCurrentlyInside && wasInside) {
        await _sendGeofenceEvent(
          phone: cleanPhone,
          event: 'exit',
          locationId: lastZoneId > 0 ? lastZoneId : matchedZoneId,
          lat: pos.latitude,
          lng: pos.longitude,
          accuracy: pos.accuracy,
          isMock: isMock,
          token: token,
        );
        await prefs.setBool(_fgsInsideKey, false);
        await prefs.remove(_fgsZoneKey);
        debugPrint(
          '🚪 [GEOFENCE ISOLATE] EXIT event yuborildi. Tashqarida GPS yoqildi.',
        );
      }

      // If inside zone, DO NOT SEND standard GPS pings! Server already knows staff is in office.
      if (isCurrentlyInside) {
        return;
      }

      // Tashqarida: filtrdan o'tgan nuqtalar (aniqligi past, titrash, sakrash
      // tashlangan) [outsideBatchInterval] da bir marta — hammasi bitta
      // paketda (`/lokatsiya/paket`), navbat orqali: internet bo'lmasa
      // telefonda qoladi, tartib buziladi emas.
      final hadPending = _pending.isNotEmpty;
      if (hadPending &&
          (_lastPingAt == null ||
              DateTime.now().difference(_lastPingAt!) >=
                  outsideBatchInterval)) {
        await _queuePending(cleanPhone, pos: pos);
        await _flushQueue(token);
        _lastPingAt = DateTime.now();
      }
      // Turgan joy — shu paytdagi hamma o'lchovlarning aniq o'rtachasi.
      final standing = _filter.standing;
      if (!hadPending &&
          standing != null &&
          (_lastPingAt == null ||
              DateTime.now().difference(_lastPingAt!) >= stationaryHeartbeat)) {
        // Bir joyda turibdi — o'sha joy, hozirgi vaqt bilan.
        await _sendOutsideGpsPing(
          cleanPhone,
          (
            lat: standing.lat,
            lng: standing.lng,
            time: DateTime.now(),
            accuracy: standing.accuracy,
            speed: 0,
          ),
          isMock,
          token,
        );
        _lastPingAt = DateTime.now();
      }
    } catch (e, st) {
      debugPrint('❌ [HODIM GPS ISOLATE XATOSI]: $e\n$st');
    }
  }

  Future<void> _sendGeofenceEvent({
    required String phone,
    required String event,
    required int locationId,
    required double lat,
    required double lng,
    required double accuracy,
    required bool isMock,
    String? token,
  }) async {
    await _sendOrQueue(
      kind: 'event',
      path: '/bot/staff/lokatsiya/event',
      body: {
        'phone': phone,
        'event': event,
        'location_id': locationId,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy.round(),
        'is_mock': isMock,
        'timestamp': DateTime.now().toString().substring(0, 19),
      },
      token: token,
    );
  }

  Map<String, dynamic> _pingBody(
    String cleanPhone,
    AcceptedFix fix,
    bool isMock,
  ) => {
    'phone': cleanPhone,
    'latitude': fix.lat,
    'longitude': fix.lng,
    'lat': fix.lat,
    'lng': fix.lng,
    'accuracy': fix.accuracy.round(),
    'speed': gpsSpeedForServer(fix.speed),
    'is_mock': isMock,
    // GPS o'lchangan haqiqiy vaqt (yuborilgan payt emas).
    'recorded_at': fix.time.toIso8601String(),
  };

  Future<void> _sendOutsideGpsPing(
    String cleanPhone,
    AcceptedFix fix,
    bool isMock,
    String? token,
  ) async {
    await _sendOrQueue(
      kind: 'ping',
      path: '/bot/staff/lokatsiya',
      body: _pingBody(cleanPhone, fix, isMock),
      token: token,
    );
  }

  /// Yig'ilgan tashqi nuqtalarni navbat oxiriga yozadi (keyin
  /// [_flushQueue] ularni 200 tagacha paket bilan yuboradi).
  Future<void> _queuePending(String phone, {required Position? pos}) async {
    if (_pending.isEmpty) return;
    var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 9) cleanPhone = '998$cleanPhone';
    final isMock = pos?.isMocked ?? false;
    final batch = List<AcceptedFix>.of(_pending);
    _pending.clear();
    for (final f in batch) {
      await _enqueue(
        'ping',
        '/bot/staff/lokatsiya',
        _pingBody(cleanPhone, f, isMock),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Offline navbat: internet bo'lmasa (signal yo'q, mobil internet o'chiq,
  // Wi-Fi'dan uzoqlashilgan) nuqtalar yo'qolmasin — telefonda saqlanadi va
  // internet qaytgach, o'z vaqti (`recorded_at` / `timestamp`) bilan
  // ketma-ket yuboriladi.
  // ---------------------------------------------------------------------

  final GpsOfflineQueue _queue = GpsOfflineQueue();

  /// Internet yo'q paytda navbatni har soniyada o'qib-yubormaslik uchun:
  /// muvaffaqiyatsiz urinishdan keyin shuncha kutiladi.
  static const _flushRetryEvery = Duration(seconds: 15);
  DateTime? _nextFlushAt;

  /// Bir paketda nechta nuqta (backend `PAKET_LIMIT = 200`).
  static const _paketSize = 200;

  /// Backend paket endpoint'ini bilmasa (404/405) yoki javob formati boshqa
  /// bo'lsa — shu ishga tushirishda qaytib urinilmaydi, nuqtalar bittadan
  /// yuboriladi.
  bool _paketSupported = true;

  /// Yuborishga urinadi; tarmoq xatosi yoki server vaqtincha ishlamasa
  /// (5xx/429) navbatga qo'yadi. Navbatda eskilari bo'lsa, tartib buzilmasin
  /// deb yangisi ham navbat oxiriga qo'shiladi.
  ///
  /// Navbatga filtrdan o'tgan nuqtalarning **hammasi** yoziladi (siyrak-
  /// lashtirilmaydi) — internet qaytgach backend oflayn yurilgan yo'lni
  /// ham aniq va silliq chizishi uchun. Turgan joyda filtr nuqta
  /// o'tkazmaydi, ya'ni navbatga faqat harakat va 20 s lik heartbeat tushadi.
  Future<void> _sendOrQueue({
    required String kind,
    required String path,
    required Map<String, dynamic> body,
    String? token,
  }) async {
    if (!await _queue.isEmpty) {
      await _enqueue(kind, path, body);
      await _flushQueue(token);
      return;
    }
    if (!await _post(kind, path, body, token)) {
      await _enqueue(kind, path, body);
      _nextFlushAt = DateTime.now().add(_flushRetryEvery);
    }
  }

  Future<void> _enqueue(
    String kind,
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      await _queue.add({'kind': kind, 'path': path, 'body': body});
      final n = await _queue.length();
      if (kind != 'ping' || n % 60 == 1) {
        debugPrint('📥 [GPS FON] $kind navbatga qo\'yildi (navbatda: $n)');
      }
    } catch (e) {
      debugPrint('❌ [GPS FON] navbatga yozilmadi: $e');
    }
  }

  /// Navbatni eskisidan boshlab yuboradi: ketma-ket nuqtalar paket bo'lib
  /// (200 tadan), hodisalar bittadan — tartib saqlanadi. Birinchi
  /// muvaffaqiyatsizlikda to'xtaydi (internet hali yo'q).
  Future<void> _flushQueue(String? token) async {
    final wait = _nextFlushAt;
    if (wait != null && DateTime.now().isBefore(wait)) return;
    try {
      if (await _queue.isEmpty) return;
      var total = 0;
      // Bir tick'da ko'pi bilan ~1000 nuqta — tick uzoq bloklanmasin.
      for (var round = 0; round < 5; round++) {
        final items = await _queue.peek(_paketSize);
        if (items.isEmpty) break;
        final sent = await _sendQueued(items, token);
        if (sent > 0) {
          await _queue.drop(sent);
          total += sent;
        }
        if (sent < items.length) {
          _nextFlushAt = DateTime.now().add(_flushRetryEvery);
          break;
        }
      }
      if (total > 0) {
        debugPrint(
          '📤 [GPS FON] navbatdan $total ta yuborildi, '
          'qoldi: ${await _queue.length()}',
        );
      }
    } catch (e) {
      debugPrint('❌ [GPS FON] navbat yuborilmadi: $e');
      _nextFlushAt = DateTime.now().add(_flushRetryEvery);
    }
  }

  /// [items] boshidan nechtasi yuborildi (yoki tashlab yuborildi).
  Future<int> _sendQueued(
    List<Map<String, dynamic>> items,
    String? token,
  ) async {
    var sent = 0;
    while (sent < items.length) {
      final item = items[sent];
      final kind = item['kind']?.toString() ?? 'ping';
      final body = item['body'];
      if (kind == 'broken' || body is! Map) {
        sent++; // buzilgan yozuv
        continue;
      }
      // Ketma-ket nuqtalar — bitta paket.
      if (kind == 'ping' && _paketSupported) {
        var taken = 0;
        final run = <Map<String, dynamic>>[];
        while (sent + taken < items.length) {
          final it = items[sent + taken];
          if (it['kind'] != 'ping' || it['body'] is! Map) break;
          taken++;
          final b = Map<String, dynamic>.from(it['body'] as Map);
          // Yaroqsiz nuqta qayta yuborilsa ham 422 oladi — tashlanadi.
          if (isValidGpsPaketPoint(b)) run.add(b);
        }
        if (taken > 1) {
          if (run.length < taken) {
            debugPrint(
              '⚠️ [GPS FON] ${taken - run.length} ta yaroqsiz nuqta '
              'tashlandi (lat/lng yoki recorded_at)',
            );
          }
          final r = run.isEmpty
              ? _PaketResult.ok
              : await _postPaket(run, token);
          if (r == _PaketResult.ok) {
            sent += taken;
            continue;
          }
          if (r == _PaketResult.retryLater) return sent;
          if (r == _PaketResult.rejected) {
            // Paket 422 — nuqtalar bittadan: yaxshilari saqlanadi,
            // yomoni o'zi 422 olib tashlanadi. Paket keyingi safar yana
            // ishlatiladi.
            for (var k = 0; k < taken; k++) {
              final it = items[sent];
              final ok = await _post(
                'ping',
                it['path']?.toString() ?? '/bot/staff/lokatsiya',
                Map<String, dynamic>.from(it['body'] as Map),
                token,
              );
              if (!ok) return sent;
              sent++;
            }
            continue;
          }
          // unsupported — pastda bittadan yuboriladi.
        }
      }
      final ok = await _post(
        kind,
        item['path']?.toString() ?? '/bot/staff/lokatsiya',
        Map<String, dynamic>.from(body),
        token,
      );
      if (!ok) return sent;
      sent++;
    }
    return sent;
  }

  /// `POST /bot/staff/lokatsiya/paket` — `{phone, nuqtalar: [...]}`, har
  /// element oddiy `/bot/staff/lokatsiya` body'si (tartibi ahamiyatsiz —
  /// backend `recorded_at` bo'yicha o'zi saralaydi).
  ///
  /// Javob: `yuborilgan` — paketdagi jami nuqta (doim massiv uzunligi),
  /// `saqlangan` — bazaga yozilgani, `tashlangan` — takror/sessiyadan
  /// tashqari/filtrdan o'tmagani. Tashlanganlarni qayta yuborishdan foyda
  /// yo'q, shuning uchun 2xx + `yuborilgan` bo'lsa paket to'liq qabul
  /// qilingan hisoblanadi.
  ///
  /// `422` — paket ichida yaroqsiz nuqta bor ([_PaketResult.rejected]).
  /// Boshqa 4xx yoki format mos kelmasa — paket o'chiriladi va nuqtalar
  /// bittadan yuboriladi, hech narsa yo'qolmaydi.
  Future<_PaketResult> _postPaket(
    List<Map<String, dynamic>> points,
    String? token,
  ) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          headers: _headers(token),
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      final response = await dio.post(
        '${ApiConstants.baseUrl}/bot/staff/lokatsiya/paket',
        data: {'phone': points.first['phone'], 'nuqtalar': points},
      );
      _logResponse('paket(${points.length})', response, token);
      final code = response.statusCode ?? 0;
      if (isRetryableGpsStatus(code)) return _PaketResult.retryLater;
      if (code == 422) {
        debugPrint('⚠️ [GPS FON] paket rad etildi (422) — bittadan yuboriladi');
        return _PaketResult.rejected;
      }
      final data = response.data;
      final count = data is Map ? data['yuborilgan'] : null;
      if (code >= 200 && code < 300 && count is num) {
        final saved = data['saqlangan'];
        final dropped = data['tashlangan'];
        if (dropped is num && dropped > 0) {
          debugPrint(
            '📦 [GPS FON] paket: $count ta keldi, $saved saqlandi, '
            '$dropped tashlandi',
          );
        }
        await _applyTracking(data as Map);
        return _PaketResult.ok;
      }
      debugPrint(
        '⚠️ [GPS FON] paket formati mos emas ($code) — nuqtalar bittadan '
        'yuboriladi',
      );
      _paketSupported = false;
      return _PaketResult.unsupported;
    } catch (e) {
      debugPrint('❌ [GPS FON] paket yuborilmadi: $e');
      return _PaketResult.retryLater;
    }
  }

  /// `true` — server qabul qildi yoki qayta yuborishdan foyda yo'q (4xx:
  /// noto'g'ri ma'lumot). `false` — tarmoq xatosi yoki server vaqtincha
  /// ishlamayapti, keyinroq qayta urinish kerak.
  Future<bool> _post(
    String kind,
    String path,
    Map<String, dynamic> body,
    String? token,
  ) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: _headers(token),
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      final response = await dio.post(
        '${ApiConstants.baseUrl}$path',
        data: body,
      );
      _logResponse(kind, response, token);
      // Server sessiya yopilganini aytsa (avto-ketdi bo'ldi), keyingi
      // tick'da servis to'xtaydi.
      final data = response.data;
      if (data is Map) await _applyTracking(data);
      final code = response.statusCode ?? 0;
      return !isRetryableGpsStatus(code);
    } catch (e) {
      debugPrint('❌ [GPS FON] $kind yuborilmadi: $e');
      return false;
    }
  }

  /// Server sessiya yopilganini aytsa (avto-ketdi bo'ldi), keyingi tick'da
  /// servis to'xtaydi; aniq avto-yopilish vaqtini bersa — shunga moslanadi.
  static Future<void> _applyTracking(Map<dynamic, dynamic> data) async {
    if (data['tracking'] == false) {
      await FlutterForegroundTask.saveData(key: workSessionUntilKey, value: 0);
    } else if (data['tracking'] == true) {
      final until = DateTime.tryParse('${data['auto_ketdi_at'] ?? ''}');
      if (until != null) {
        await FlutterForegroundTask.saveData(
          key: workSessionUntilKey,
          value: until.millisecondsSinceEpoch,
        );
      }
    }
  }

  /// Fon servisi javoblarini logga yozadi — ilgari xatolar jim yutilardi va
  /// fondagi nuqtalar serverga yetmagani hech qayerda ko'rinmasdi.
  static void _logResponse(String what, Response<dynamic> r, String? token) {
    final ok = r.statusCode == 200 || r.statusCode == 201;
    final body = r.data.toString();
    debugPrint(
      '${ok ? '✅' : '❌'} [GPS FON] $what -> ${r.statusCode} '
      'token=${(token ?? '').isEmpty ? 'YOQ' : 'bor'} '
      'javob=${body.length > 300 ? body.substring(0, 300) : body}',
    );
  }

  Future<void> _reportSecurityIncident(
    String phone,
    String type,
    String details,
    String? token,
  ) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          headers: _headers(token),
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      await dio.post(
        '${ApiConstants.baseUrl}/bot/staff/security/report',
        data: {
          'phone': phone,
          'type': type,
          'details': details,
          'timestamp': DateTime.now().toString().substring(0, 19),
        },
      );
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Public service — called from main isolate
// ---------------------------------------------------------------------------
class GpsLiveTrackerService {
  static final GpsLiveTrackerService instance =
      GpsLiveTrackerService._internal();
  GpsLiveTrackerService._internal();

  bool _isTracking = false;
  String? _phone;
  Timer? _checkTimer;
  StreamSubscription<Position>? _positionSubscription;

  List<GeofenceZoneModel> _zones = [];
  bool _insideZone = false;
  int? _currentZoneId;
  DateTime? _lastOutsideSendTime;
  Position? _lastOutsideSentPos;

  /// iOS'da (fon servisi yo'q) va Android'da servis to'xtab qolganda
  /// lokatsiya nazoratini asosiy ilova olib boradi.
  final LocationHeartbeat _heartbeat = LocationHeartbeat();
  Timer? _healthTimer;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  DateTime? _lastFixAt;

  bool get isTracking => _isTracking;
  bool get isInsideZone => _insideZone;
  List<GeofenceZoneModel> get zones => List.unmodifiable(_zones);

  /// GPS fon servisi bildirishnomasi belgisi — bir rangli (rangli ilova
  /// ikonkasi status barda oq kvadrat bo'lib chiqadi). Manifestdagi
  /// meta-data orqali.
  static const gpsNotificationIcon = NotificationIcon(
    metaDataName: 'uz.skor.hodimlar.NOTIFICATION_ICON',
  );

  /// Call once at app startup (before runApp) to configure the foreground task
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'skor_gps_channel',
        channelName: AppLocalizations.trStatic('gps_channel_name'),
        channelDescription: AppLocalizations.trStatic('gps_channel_desc'),
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Har soniyada: zonadan tashqarida rahbar real vaqtda ko'radi.
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        // Ilova "so'nggi ilovalar" ro'yxatidan surib yopilganda ham GPS
        // kuzatuvi to'xtamasin; tizim o'ldirsa — qayta ishga tushsin.
        stopWithTask: false,
        allowAutoRestart: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Davomat holatini GPS kuzatuviga uzatadi: xodim ishda (`active`) bo'lsa
  /// sessiya tugash vaqti saqlanadi va kuzatuv boshlanadi, aks holda
  /// to'xtatiladi.
  Future<void> syncWorkSession({
    required bool active,
    String? autoEndAt,
  }) async {
    final now = DateTime.now();
    final end = active ? resolveWorkSessionEnd(autoEndAt, now) : now;
    try {
      await FlutterForegroundTask.saveData(
        key: workSessionUntilKey,
        value: active ? end.millisecondsSinceEpoch : 0,
      );
    } catch (_) {}

    if (active && end.isAfter(now)) {
      // Yangi sessiya (fon servisi ishlamayapti) — zona holati noldan.
      // Servis ishlab tursa tegilmaydi: kun o'rtasida takroriy ENTER ketmasin.
      try {
        if (!await FlutterForegroundTask.isRunningService) {
          await clearFgsZoneState(sl<SharedPreferences>());
        }
      } catch (_) {}
      await startTracking();
      return;
    }
    bool running = false;
    try {
      running = await FlutterForegroundTask.isRunningService;
    } catch (_) {}
    if (_isTracking || running) await stopTracking();
  }

  /// Starts live location tracking with Geofencing for the logged-in staff
  /// member. Ochiq ish sessiyasi bo'lmasa hech narsa qilmaydi.
  Future<void> startTracking({String? phone}) async {
    final prefs = sl<SharedPreferences>();
    final userRole = prefs.getString('user_role');
    if (userRole == 'admin' || userRole == 'rahbar') return;

    _phone =
        phone ?? prefs.getString('phone') ?? prefs.getString('staff_phone');
    if (_phone == null || _phone!.isEmpty) return;
    if (_isTracking) return;
    // Bayroq birinchi `await` dan oldin qo'yiladi: splash va home bir vaqtda
    // chaqirganda ikkinchisi ham o'tib ketib, foreground service'ni
    // qayta ishga tushirmasligi (restartService) uchun.
    _isTracking = true;

    if (!await _workSessionOpen()) {
      _isTracking = false;
      return;
    }

    // Check location permission
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _isTracking = false;
      return;
    }

    var cleanPhone = _phone!.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 9) cleanPhone = '998$cleanPhone';
    _phone = cleanPhone;

    // 1. Geofence zonalarni backenddan yuklab olish va keshga saqlash
    await _loadGeofenceZones(cleanPhone);

    // 2. Notify backend that live tracking session started
    try {
      debugPrint(
        '📡 [HODIM GPS] Geofence kuzatuv boshlanmoqda -> Tel: $cleanPhone',
      );
      final dioClient = sl<DioClient>();
      await dioClient.dio.post(
        ApiConstants.staffLokatsiyaBoshla,
        data: {'phone': cleanPhone},
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (s) => s != null && s < 600,
        ),
      );
    } catch (e) {
      debugPrint('❌ [HODIM GPS BOSHLA XATOSI]: $e');
    }

    // 3. Darhol birinchi lokatsiyani tekshirish
    await _checkCurrentPosition();

    // 4. Har 30 soniyada masofani tekshirish (hududga kirish/chiqishni aniqlash)
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkCurrentPosition();
    });

    // 4b. Lokatsiya nazorati: har 5 soniyada holat, GPS o'chirilsa — darhol.
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      locationHealthCheckInterval,
      (_) => _healthTick(),
    );
    try {
      unawaited(_serviceStatusSub?.cancel());
      _serviceStatusSub = Geolocator.getServiceStatusStream().listen(
        (_) => _healthTick(force: true),
        onError: (_) {},
      );
    } catch (_) {}
    unawaited(_healthTick(force: true));

    // 5. GPS Stream — harakat bo'lganda tezkor tekshirish
    try {
      unawaited(_positionSubscription?.cancel());
      // Fon servisi bilan bir xil 1 Hz oqim. Android'da odatda yuborishni
      // fon servisi qiladi, lekin u ishlamay qolsa (`_foregroundServiceRunning`
      // false) ochiq ilova o'zi yuboradi — o'shanda ham nuqtalar siyrak
      // bo'lmasin (oldin 20 s / 25 m edi: piyoda yo'l daqiqada bitta
      // nuqta bo'lib, chiziq chizilmay qolardi).
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: gpsStreamSettings(),
      ).listen(_processPosition, onError: (_) {});
    } catch (_) {}

    // 6. Foreground service ni fonda (app yopilganda) ishlash uchun yoqish
    try {
      await FlutterForegroundTask.saveData(key: 'phone', value: cleanPhone);
      // Fon izolyatorining o'z Dio nusxasi bor va u DioClient'dan
      // foydalanmaydi (boshqa izolyatorda GetIt yo'q), shuning uchun
      // tokenni ham alohida uzatamiz.
      await FlutterForegroundTask.saveData(
        key: 'api_token',
        value: AuthTokenStore.instance.token ?? '',
      );
      await FlutterForegroundTask.requestNotificationPermission();

      // Servis allaqachon ishlayotgan bo'lsa (masalan, Android uni o'zi
      // qayta tiklagan bo'lsa) qayta ishga tushirmaymiz: restartService fon
      // engine'ini o'chirib qayta yaratadi. Handler telefon va tokenni har
      // tekshiruvda getData orqali o'qiydi, saveData yetarli.
      if (await FlutterForegroundTask.isRunningService) {
        // Servis "ishlayapti", lekin Dart qismi tick bermayapti (masalan,
        // ilova qayta o'rnatilganda Android servisni eski callback bilan
        // tiklagan) — qayta ishga tushiramiz.
        await _restartServiceIfStale();
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 1001,
          notificationTitle: AppLocalizations.trStatic(
            'gps_notification_title',
          ),
          notificationText: AppLocalizations.trStatic('gps_channel_desc'),
          notificationIcon: gpsNotificationIcon,
          callback: startGpsTaskCallback,
        );
      }
    } catch (_) {}
  }

  Future<void> _loadGeofenceZones(String cleanPhone) async {
    try {
      final geofenceDs = sl<GeofenceRemoteDataSource>();
      _zones = await geofenceDs.getGeofenceZones(cleanPhone);
      debugPrint('📍 [GEOFENCE] Yuklangan zonalar soni: ${_zones.length}');

      final prefs = sl<SharedPreferences>();
      final jsonList = _zones.map((z) => z.toJson()).toList();
      await prefs.setString('cached_geofence_zones_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('❌ [GEOFENCE ZONALAR XATOSI]: $e');
    }
  }

  DateTime? _lastServiceRestart;

  /// Fon servisi ishlab turibdi, lekin oxirgi 90 soniyada tick bermagan
  /// bo'lsa — qayta ishga tushiradi (2 daqiqada ko'pi bilan bir marta).
  /// Aks holda GPS'ni faqat ochiq ilova yuboradi va ilova fonga o'tganda
  /// nuqtalar umuman kelmaydi.
  Future<void> _restartServiceIfStale() async {
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      if (await _foregroundServiceRunning()) return;
      final last = _lastServiceRestart;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(minutes: 2)) {
        return;
      }
      _lastServiceRestart = DateTime.now();
      debugPrint(
        '🔁 [HODIM GPS] fon servisi javob bermayapti — qayta ishga tushirilmoqda',
      );
      // restartService eski callback'ni qayta ishlatadi — u buzilgan bo'lishi
      // mumkin, shuning uchun to'xtatib, yangidan boshlaymiz.
      await FlutterForegroundTask.stopService();
      await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: AppLocalizations.trStatic('gps_notification_title'),
        notificationText: AppLocalizations.trStatic('gps_channel_desc'),
        notificationIcon: gpsNotificationIcon,
        callback: startGpsTaskCallback,
      );
    } catch (e) {
      debugPrint(
        '❌ [HODIM GPS] fon servisini qayta ishga tushirib bo\'lmadi: $e',
      );
    }
  }

  Future<void> _checkCurrentPosition() async {
    if (!await _workSessionOpen()) {
      debugPrint('⏹️ [HODIM GPS] ish sessiyasi tugadi — kuzatuv to\'xtatildi');
      await stopTracking();
      return;
    }
    if (Platform.isAndroid) unawaited(_restartServiceIfStale());
    // GPS o'chiq — so'rov Google oynasini ochadi, yangi joy baribir yo'q.
    if (!await Geolocator.isLocationServiceEnabled()) return;
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos != null) {
        await _processPosition(pos);
      }
    } catch (_) {}
  }

  /// Fon servisi ishlab tursa, nazoratni u qiladi (ikki marta yuborilmasin).
  Future<void> _healthTick({bool force = false}) async {
    final phone = _phone;
    if (!_isTracking || phone == null) return;
    if (await _foregroundServiceRunning()) return;
    await _heartbeat.tick(
      phone: phone,
      token: AuthTokenStore.instance.token,
      insideZone: _insideZone,
      lastFixAt: _lastFixAt,
      force: force,
    );
  }

  Future<void> _processPosition(Position pos) async {
    if (_phone == null) return;
    _lastFixAt = pos.timestamp;
    final prefs = sl<SharedPreferences>();

    await prefs.setDouble('last_lat', pos.latitude);
    await prefs.setDouble('last_lng', pos.longitude);
    await prefs.setString(
      'last_location_time',
      DateTime.now().toIso8601String(),
    );

    final bool isMock = pos.isMocked;

    // Anti-Cheat: Mock location aniqlansa backendga xabar berish
    if (isMock) {
      debugPrint('⚠️ [ANTI-CHEAT] Soxta lokatsiya (Mock GPS) aniqlandi!');
      unawaited(
        sl<GeofenceRemoteDataSource>().reportSecurityIncident(
          phone: _phone!,
          type: 'FAKE_GPS_DETECTED',
          details: 'Mock location provider aniqlandi',
        ),
      );
    }

    // Geofence zonalar bilan taqqoslash
    GeofenceZoneModel? insideZone;
    for (final zone in _zones) {
      if (zone.lat != 0.0 && zone.lng != 0.0) {
        final dist = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          zone.lat,
          zone.lng,
        );
        if (dist <= zone.radiusMeter) {
          insideZone = zone;
          break;
        }
      }
    }

    final geofenceDs = sl<GeofenceRemoteDataSource>();

    // Fon servisi ishlab tursa, kirish/chiqish hodisalari va GPS nuqtalarini
    // u o'zi yuboradi (`_GpsTaskHandler`). Bu yerda ham yuborilsa, ilova
    // ochiq paytda har bir nuqta serverga ikki marta tushardi. Bu holda
    // asosiy isolate faqat ekran uchun holatni yangilaydi.
    final bool serviceSends = await _foregroundServiceRunning();

    // 1. Hududga KIRISH (ENTER hodisasi)
    if (insideZone != null && !_insideZone) {
      _insideZone = true;
      _currentZoneId = insideZone.id;
      await prefs.setBool('inside_zone', true);
      await prefs.setInt('current_zone_id', insideZone.id);

      debugPrint(
        '🚪 [GEOFENCE] ENTER -> ${insideZone.name} (r=${insideZone.radiusMeter}m)',
      );
      if (serviceSends) return;
      await geofenceDs.sendLokatsiyaEvent(
        phone: _phone!,
        event: 'enter',
        locationId: insideZone.id,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        isMock: isMock,
        wifiBssid: insideZone.wifiBssid,
      );
      // Kirgandan keyin doimiy GPS yuborish to'xtatiladi!
      return;
    }

    // 2. Hududdan CHIQISH (EXIT hodisasi)
    if (insideZone == null && _insideZone) {
      final lastId =
          _currentZoneId ?? (_zones.isNotEmpty ? _zones.first.id : 0);
      _insideZone = false;
      _currentZoneId = null;
      await prefs.setBool('inside_zone', false);
      await prefs.remove('current_zone_id');

      debugPrint(
        '🚪 [GEOFENCE] EXIT -> Zonadan chiqildi. 60-soniyalik GPS yoqildi.',
      );
      if (!serviceSends) {
        await geofenceDs.sendLokatsiyaEvent(
          phone: _phone!,
          event: 'exit',
          locationId: lastId,
          lat: pos.latitude,
          lng: pos.longitude,
          accuracy: pos.accuracy,
          isMock: isMock,
        );
      }
    }

    // 3. Agar xodim ofis ichida bo'lsa — doimiy GPS PING YUBORILMAYDI (Yuklama 0 ga tushadi!)
    if (_insideZone || serviceSends) {
      return;
    }

    // 4. Tashqarida: fon servisidagi bilan bir xil filtr (Zonic).
    final fix = _mainFilter.accept(pos);
    if (fix != null &&
        shouldSendOutsidePing(
          lastTime: _lastOutsideSendTime,
          lastPos: _lastOutsideSentPos,
          pos: pos,
        )) {
      _lastOutsideSendTime = DateTime.now();
      _lastOutsideSentPos = pos;
      await _sendOutsidePing(fix, isMock);
    }
  }

  /// Fon servisi ishlayapti VA oxirgi 90 soniyada GPS tekshirgan bo'lsa
  /// `true`. Servis "tirik", lekin Dart qismi to'xtab qolgan bo'lsa (masalan
  /// debugger pauzasi yoki isolate xatosi), asosiy ilova o'zi yuboradi —
  /// aks holda ma'lumot hech kim tomonidan yuborilmay qolardi.
  Future<bool> _foregroundServiceRunning() async {
    try {
      if (!await FlutterForegroundTask.isRunningService) return false;
      final last = await FlutterForegroundTask.getData<int>(
        key: gpsServiceHeartbeatKey,
      );
      if (last == null) return false;
      final age = DateTime.now().millisecondsSinceEpoch - last;
      return age >= 0 && age < 90 * 1000;
    } catch (_) {
      return false;
    }
  }

  final GpsFixFilter _mainFilter = GpsFixFilter();

  Future<void> _sendOutsidePing(AcceptedFix pos, bool isMock) async {
    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.dio.post(
        ApiConstants.staffLokatsiya,
        data: {
          'phone': _phone,
          'latitude': pos.lat,
          'longitude': pos.lng,
          'lat': pos.lat,
          'lng': pos.lng,
          'accuracy': pos.accuracy.round(),
          'speed': gpsSpeedForServer(pos.speed),
          'is_mock': isMock,
          'recorded_at': pos.time.toIso8601String(),
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(
          '📡 [HODIM GPS TASHQARIDA] Yuborildi ✅ -> Lat: ${pos.lat}, Lng: ${pos.lng} | Mock: $isMock',
        );
      }
    } catch (e) {
      debugPrint('❌ [HODIM GPS TASHQARIDA XATOSI]: $e');
    }
  }

  /// Stops tracking (e.g. on logout)
  Future<void> stopTracking() async {
    _isTracking = false;
    _checkTimer?.cancel();
    _checkTimer = null;
    _healthTimer?.cancel();
    _healthTimer = null;
    unawaited(_serviceStatusSub?.cancel());
    _serviceStatusSub = null;
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    _insideZone = false;
    _currentZoneId = null;

    try {
      await FlutterForegroundTask.saveData(key: workSessionUntilKey, value: 0);
      await FlutterForegroundTask.stopService();
    } catch (_) {}
    try {
      await clearFgsZoneState(sl<SharedPreferences>());
    } catch (_) {}

    if (_phone != null) {
      try {
        var cleanPhone = _phone!.replaceAll(RegExp(r'\D'), '');
        if (cleanPhone.length == 9) cleanPhone = '998$cleanPhone';
        final dioClient = sl<DioClient>();
        unawaited(
          dioClient.dio
              .post(
                ApiConstants.staffLokatsiyaToxtat,
                data: {'phone': cleanPhone},
                options: Options(validateStatus: (s) => s != null && s < 600),
              )
              .then<void>((_) {})
              .catchError((_) {}),
        );
      } catch (_) {}
    }
  }
}

enum _PaketResult { ok, unsupported, retryLater, rejected }
