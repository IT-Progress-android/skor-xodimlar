import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';

/// Ish vaqtida (ochiq sessiyada) shunda bir marta "tirikman" signali
/// yuboriladi — zona ichida ham. Server shu signal (yoki GPS nuqtasi)
/// kelmay qolganidan xodim lokatsiyani o'chirganini, telefoni o'chganini
/// yoki ilova to'xtatilganini biladi.
const locationHeartbeatInterval = Duration(seconds: 60);

/// GPS / ruxsat holati shunda bir marta tekshiriladi: o'chirilsa server
/// ko'pi bilan shuncha kechikib biladi.
const locationHealthCheckInterval = Duration(seconds: 5);

/// Signal yuborilmasa (internet yo'q) qayta urinish oralig'i.
const _retryAfterFailure = Duration(seconds: 15);

/// Server bu endpoint'ni hali bilmasa (404) — shuncha vaqt so'ralmaydi.
const _unsupportedBackoff = Duration(minutes: 30);

/// Batareya shu foizlarga tushganda (quvvatlanmayotgan bo'lsa) server
/// xodimga "telefonni quvvatlang" deydi — har chegara kuniga bir marta.
const lowBatteryLevels = [15, 10];

/// Bugun qaysi chegaralar uchun xabar yuborilgani (`YYYY-MM-DD:15,10`).
/// Fon servisi va asosiy ilova umumiy omborda saqlaydi: ilova yoki servis
/// qayta ishga tushsa ham xabar takrorlanmaydi.
const lowBatteryReportedKey = 'battery_low_reported';

/// Lokatsiya qachondan beri ishlamayotgani (millisekund, 0 — ishlayapti).
/// Fon servisi va asosiy ilova umumiy omborda saqlaydi: qulf ekranidagi
/// sanoq fonda o'chirilgan paytdan boshlanadi.
const locationBadSinceKey = 'location_bad_since';

/// Telefondagi lokatsiya holati. Serverga [code] ketadi.
enum LocationHealth {
  ok('ok'),

  /// Joylashuv xizmati (GPS) o'chirilgan.
  gpsOff('location_off'),

  /// Ruxsat umuman olib tashlangan.
  permissionDenied('permission_denied'),

  /// «Har doim» o'rniga «Faqat foydalanganda»: fonda GPS ishlamaydi.
  permissionReduced('permission_reduced'),

  /// Aniq joylashuv o'chirilgan (taxminiy, ~3 km).
  precisionReduced('precision_reduced');

  const LocationHealth(this.code);
  final String code;

  bool get isOk => this == ok;
}

/// Hozirgi holatni telefondan o'qiydi. Aniqlab bo'lmasa — [LocationHealth.ok]
/// (yolg'on xabar yuborgandan ko'ra, serverning jimlik nazoratiga qoldirgan
/// ma'qul).
Future<LocationHealth> readLocationHealth() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationHealth.gpsOff;
    }
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return LocationHealth.permissionDenied;
    }
    if (perm == LocationPermission.whileInUse) {
      return LocationHealth.permissionReduced;
    }
    if (await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.reduced) {
      return LocationHealth.precisionReduced;
    }
  } catch (_) {}
  return LocationHealth.ok;
}

/// Lokatsiya qachondan beri ishlamayotgani; ishlayotgan bo'lsa `null`.
Future<DateTime?> readLocationBadSince() async {
  try {
    final ms = await FlutterForegroundTask.getData<int>(
      key: locationBadSinceKey,
    );
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  } catch (_) {
    return null;
  }
}

/// Holat o'zgarganda yuboriladigan hodisa nomi.
@visibleForTesting
String healthEventName(LocationHealth h) => h.isOk ? 'location_on' : h.code;

/// "Batareya kam" xabari: batareya [lowBatteryLevels] chegarasidan past
/// va quvvatlanmayotgan bo'lsa, har chegara uchun kuniga bir marta
/// ([report]). Bir vaqtda ikkala chegaradan o'tilsa (masalan, ilova 8% da
/// ochilsa) — bitta xabar. [reported] — saqlanadigan yangi qiymat.
@visibleForTesting
({bool report, String? reported}) lowBatteryStep({
  required int? current,
  required bool charging,
  required String? reported,
  required String today,
}) {
  final parts = (reported ?? '').split(':');
  final done = parts.first == today && parts.length == 2
      ? parts[1].split(',').map(int.tryParse).whereType<int>().toSet()
      : <int>{};
  final due = current == null || charging
      ? const <int>[]
      : lowBatteryLevels.where((l) => current <= l && !done.contains(l));
  if (due.isEmpty) return (report: false, reported: reported);
  final all = [...done, ...due]..sort((a, b) => b.compareTo(a));
  return (report: true, reported: '$today:${all.join(',')}');
}

/// Ish vaqtidagi lokatsiya nazorati: holatni tekshiradi, o'zgarishni darhol,
/// "tirikman"ni [locationHeartbeatInterval] da bir marta
/// `POST /bot/staff/lokatsiya/holat` ga yuboradi.
///
/// Ikkala izolyatorda ham ishlaydi (fon servisida GetIt/DioClient yo'q —
/// shuning uchun o'z Dio'si va qo'lda yig'ilgan sarlavhalar). Android'da
/// fon servisi, iOS'da (yoki servis to'xtab qolganda) asosiy ilova chaqiradi.
class LocationHeartbeat {
  LocationHeartbeat({this.onHealthChanged, this.onServerData, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              validateStatus: (s) => s != null && s < 600,
            ),
          );

  /// Holat o'zgarganda (masalan, fon bildirishnomasi matnini almashtirish).
  final void Function(LocationHealth health)? onHealthChanged;

  /// Server javobi (`tracking`, `auto_ketdi_at`) — sessiya yopilganini
  /// bilish uchun.
  final void Function(Map<dynamic, dynamic> data)? onServerData;

  final Dio _dio;
  final Battery _battery = Battery();

  LocationHealth? _health;
  LocationHealth? get health => _health;

  DateTime? _lastCheckAt;
  DateTime? _lastSentAt;
  DateTime? _retryAt;
  DateTime? _unsupportedUntil;
  String? _lowBatteryReported;
  bool _busy = false;
  static String? _appVersion;

  /// Hali yetkazilmagan holat o'zgarishlari (tartib bilan, o'z vaqti bilan).
  final List<Map<String, dynamic>> _events = [];

  /// Fon servisi har soniyada, asosiy ilova har 5 soniyada chaqiradi;
  /// tekshiruv [locationHealthCheckInterval] da bir marta bajariladi.
  /// [force] — kutmasdan tekshirish (masalan, GPS holati o'zgargan zahoti).
  Future<void> tick({
    required String phone,
    required String? token,
    required bool insideZone,
    DateTime? lastFixAt,
    int queueSize = 0,
    bool force = false,
  }) async {
    if (_busy) return;
    final now = DateTime.now();
    if (!force &&
        _lastCheckAt != null &&
        now.difference(_lastCheckAt!) < locationHealthCheckInterval) {
      return;
    }
    _busy = true;
    _lastCheckAt = now;
    try {
      await _observe(now);
      if (_unsupportedUntil != null && now.isBefore(_unsupportedUntil!)) {
        return;
      }
      if (_retryAt != null && now.isBefore(_retryAt!) && !force) return;

      final heartbeatDue =
          _lastSentAt == null ||
          now.difference(_lastSentAt!) >= locationHeartbeatInterval;
      if (_events.isEmpty && !heartbeatDue) return;

      Future<Map<String, dynamic>> body(String event, String at) async {
        final snapshot = await _snapshot(
          insideZone: insideZone,
          lastFixAt: lastFixAt,
          queueSize: queueSize,
        );
        return {
          'phone': phone,
          'event': event,
          'changed_at': at,
          'sent_at': now.toIso8601String(),
          ...snapshot,
        };
      }

      while (_events.isNotEmpty) {
        final e = _events.first;
        final sent = await _post(
          await body('${e['event']}', '${e['changed_at']}'),
          token,
        );
        if (!sent) return;
        _events.removeAt(0);
        _lastSentAt = now;
      }
      if (heartbeatDue && _lastSentAt != now) {
        if (await _post(
          await body('heartbeat', now.toIso8601String()),
          token,
        )) {
          _lastSentAt = now;
        }
      }
    } catch (e) {
      debugPrint('❌ [LOKATSIYA NAZORATI] $e');
    } finally {
      _busy = false;
    }
  }

  /// Holat va batareyani o'qib, o'zgarishlarni navbatga qo'yadi.
  Future<void> _observe(DateTime now) async {
    final h = await readLocationHealth();
    final prev = _health;
    if (h != prev) {
      _health = h;
      // Birinchi tekshiruvda hammasi joyida bo'lsa — hodisa emas.
      if (prev != null || !h.isOk) {
        _events.add({
          'event': healthEventName(h),
          'changed_at': now.toIso8601String(),
        });
        if (_events.length > 20) _events.removeAt(0);
      }
      // Sanoq faqat "ishlayapti" <-> "ishlamayapti" o'tishida o'zgaradi:
      // GPS o'chiq paytda ruxsat ham olinsa, vaqt boshidan boshlanmaydi.
      if (prev == null || prev.isOk != h.isOk) {
        try {
          await FlutterForegroundTask.saveData(
            key: locationBadSinceKey,
            value: h.isOk ? 0 : now.millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
      debugPrint('📍 [LOKATSIYA NAZORATI] holat: ${prev?.code} -> ${h.code}');
      onHealthChanged?.call(h);
    }
  }

  Future<Map<String, dynamic>> _snapshot({
    required bool insideZone,
    DateTime? lastFixAt,
    required int queueSize,
  }) async {
    int? battery;
    bool? charging;
    bool? powerSave;
    try {
      battery = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      charging = state == BatteryState.charging || state == BatteryState.full;
      powerSave = await _battery.isInBatterySaveMode;
    } catch (_) {}
    await _checkLowBattery(battery, charging ?? false);

    final h = _health ?? LocationHealth.ok;
    return {
      'gps_enabled': h != LocationHealth.gpsOff,
      'permission': switch (h) {
        LocationHealth.permissionDenied => 'denied',
        LocationHealth.permissionReduced => 'while_in_use',
        _ => 'always',
      },
      'precise': h != LocationHealth.precisionReduced,
      'health': h.code,
      'battery': battery,
      'charging': charging,
      'power_save': powerSave,
      'inside_zone': insideZone,
      'last_fix_at': lastFixAt?.toIso8601String(),
      'queue_size': queueSize,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'app_version': _appVersion ??= await _readAppVersion(),
    };
  }

  Future<void> _checkLowBattery(int? battery, bool charging) async {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    var saved = _lowBatteryReported;
    try {
      saved =
          await FlutterForegroundTask.getData<String>(
            key: lowBatteryReportedKey,
          ) ??
          saved;
    } catch (_) {}
    final step = lowBatteryStep(
      current: battery,
      charging: charging,
      reported: saved,
      today: today,
    );
    _lowBatteryReported = step.reported;
    if (!step.report) return;
    _events.add({'event': 'battery_low', 'changed_at': now.toIso8601String()});
    try {
      await FlutterForegroundTask.saveData(
        key: lowBatteryReportedKey,
        value: step.reported!,
      );
    } catch (_) {}
  }

  static Future<String?> _readAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }

  /// `true` — yetkazildi (yoki qayta yuborishning ma'nosi yo'q).
  Future<bool> _post(Map<String, dynamic> body, String? token) async {
    try {
      final r = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.staffLokatsiyaHolat}',
        data: body,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );
      final code = r.statusCode ?? 0;
      debugPrint(
        '${code < 300 ? '💓' : '❌'} [LOKATSIYA NAZORATI] ${body['event']} -> $code',
      );
      if (code == 404) {
        _unsupportedUntil = DateTime.now().add(_unsupportedBackoff);
        _events.clear();
        return false;
      }
      if (code >= 500 || code == 429 || code == 408 || code == 401) {
        _retryAt = DateTime.now().add(_retryAfterFailure);
        return false;
      }
      _retryAt = null;
      final data = r.data;
      if (data is Map) onServerData?.call(data);
      return true;
    } catch (_) {
      // Internet yo'q: hodisalar navbatda qoladi va o'z `changed_at`i bilan
      // keyin yetkaziladi.
      _retryAt = DateTime.now().add(_retryAfterFailure);
      return false;
    }
  }
}
