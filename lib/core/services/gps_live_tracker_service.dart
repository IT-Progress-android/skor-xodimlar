import 'dart:async';
import 'dart:convert';

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
import 'package:skore_hodimlar/features/attendance/data/datasources/geofence_remote_datasource.dart';
import 'package:skore_hodimlar/features/attendance/data/models/geofence_zone_model.dart';

// ---------------------------------------------------------------------------
// Foreground task callback — must be top-level (runs in separate isolate)
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
void startGpsTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_GpsTaskHandler());
}

class _GpsTaskHandler extends TaskHandler {
  DateTime? _lastOutsideSendTime;

  /// Fon izolyatorida DioClient (va undagi token interceptor'i) mavjud emas,
  /// shuning uchun sarlavhalarni qo'lda yig'amiz.
  static Map<String, String> _headers(String? token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _checkAndProcessLocation();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Called periodically (e.g. every 30s) to check zone boundaries and outside pings
    _checkAndProcessLocation();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _checkAndProcessLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone =
          (await FlutterForegroundTask.getData<String>(key: 'phone')) ??
          prefs.getString('phone') ??
          prefs.getString('staff_phone');
      if (phone == null || phone.isEmpty) return;

      final token = await FlutterForegroundTask.getData<String>(
        key: 'api_token',
      );

      // Skip if rahbar/admin
      final role = prefs.getString('user_role') ?? '';
      if (role == 'admin' || role == 'rahbar') return;

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (_) {
          pos = await Geolocator.getLastKnownPosition();
        }
      }

      if (pos == null) return;

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

      final bool wasInside = prefs.getBool('inside_zone') ?? false;
      final int lastZoneId = prefs.getInt('current_zone_id') ?? 0;

      // Event: ENTER
      if (isCurrentlyInside && !wasInside) {
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
        await prefs.setBool('inside_zone', true);
        await prefs.setInt('current_zone_id', matchedZoneId);
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
        await prefs.setBool('inside_zone', false);
        await prefs.remove('current_zone_id');
        debugPrint(
          '🚪 [GEOFENCE ISOLATE] EXIT event yuborildi. Tashqarida GPS yoqildi.',
        );
      }

      // If inside zone, DO NOT SEND standard GPS pings! Server already knows staff is in office.
      if (isCurrentlyInside) {
        return;
      }

      // If outside: send periodic GPS updates every 60 seconds
      final now = DateTime.now();
      if (_lastOutsideSendTime == null ||
          now.difference(_lastOutsideSendTime!).inSeconds >= 55) {
        _lastOutsideSendTime = now;
        await _sendOutsideGpsPing(cleanPhone, pos, isMock, token);
      }
    } catch (e) {
      debugPrint('❌ [HODIM GPS ISOLATE XATOSI]: $e');
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
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: _headers(token),
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      await dio.post(
        '${ApiConstants.baseUrl}/bot/staff/lokatsiya/event',
        data: {
          'phone': phone,
          'event': event,
          'location_id': locationId,
          'lat': lat,
          'lng': lng,
          'accuracy': accuracy.round(),
          'is_mock': isMock,
          'timestamp': DateTime.now().toString().substring(0, 19),
        },
      );
    } catch (_) {}
  }

  Future<void> _sendOutsideGpsPing(
    String cleanPhone,
    Position pos,
    bool isMock,
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
        '${ApiConstants.baseUrl}/bot/staff/lokatsiya',
        data: {
          'phone': cleanPhone,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'accuracy': pos.accuracy.round(),
          'speed': pos.speed.round(),
          'is_mock': isMock,
          'recorded_at': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(
          '📡 [HODIM GPS TASHQARIDA (1 min)] Qabul qilindi ✅ -> Lat: ${pos.latitude}, Lng: ${pos.longitude}',
        );
      }
    } catch (_) {}
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

  bool get isTracking => _isTracking;
  bool get isInsideZone => _insideZone;
  List<GeofenceZoneModel> get zones => List.unmodifiable(_zones);

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
        // Check every 30 seconds (conserves battery and server requests)
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Starts live location tracking with Geofencing for the logged-in staff member
  Future<void> startTracking({String? phone}) async {
    final prefs = sl<SharedPreferences>();
    final userRole = prefs.getString('user_role');
    if (userRole == 'admin' || userRole == 'rahbar') return;

    _phone =
        phone ?? prefs.getString('phone') ?? prefs.getString('staff_phone');
    if (_phone == null || _phone!.isEmpty) return;
    if (_isTracking) return;

    // Check location permission
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    _isTracking = true;

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

    // 5. GPS Stream — harakat bo'lganda tezkor tekshirish
    try {
      unawaited(_positionSubscription?.cancel());
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter:
              25, // faqat 25 metr siljiganda yangilash (batareyani asraydi)
          intervalDuration: const Duration(seconds: 20),
        ),
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

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 1001,
          notificationTitle: AppLocalizations.trStatic(
            'gps_notification_title',
          ),
          notificationText: AppLocalizations.trStatic('gps_channel_desc'),
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

  Future<void> _checkCurrentPosition() async {
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

  Future<void> _processPosition(Position pos) async {
    if (_phone == null) return;
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

    // 1. Hududga KIRISH (ENTER hodisasi)
    if (insideZone != null && !_insideZone) {
      _insideZone = true;
      _currentZoneId = insideZone.id;
      await prefs.setBool('inside_zone', true);
      await prefs.setInt('current_zone_id', insideZone.id);

      debugPrint(
        '🚪 [GEOFENCE] ENTER -> ${insideZone.name} (r=${insideZone.radiusMeter}m)',
      );
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

    // 3. Agar xodim ofis ichida bo'lsa — doimiy GPS PING YUBORILMAYDI (Yuklama 0 ga tushadi!)
    if (_insideZone) {
      return;
    }

    // 4. Agar xodim tashqarida bo'lsa — har 60 soniyada 1 marta GPS yuboriladi
    final now = DateTime.now();
    if (_lastOutsideSendTime == null ||
        now.difference(_lastOutsideSendTime!).inSeconds >= 55) {
      _lastOutsideSendTime = now;
      await _sendOutsidePing(pos, isMock);
    }
  }

  Future<void> _sendOutsidePing(Position pos, bool isMock) async {
    try {
      final dioClient = sl<DioClient>();
      final response = await dioClient.dio.post(
        ApiConstants.staffLokatsiya,
        data: {
          'phone': _phone,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'accuracy': pos.accuracy.round(),
          'speed': pos.speed.round(),
          'is_mock': isMock,
          'recorded_at': DateTime.now().toIso8601String(),
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
          '📡 [HODIM GPS TASHQARIDA] Yuborildi ✅ -> Lat: ${pos.latitude}, Lng: ${pos.longitude} | Mock: $isMock',
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
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    _insideZone = false;
    _currentZoneId = null;

    try {
      await FlutterForegroundTask.stopService();
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
