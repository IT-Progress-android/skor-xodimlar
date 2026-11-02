import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/services/location_heartbeat.dart';
import 'package:skore_hodimlar/core/widgets/location_disclosure_dialog.dart';

enum _GateStatus {
  checking,
  ok,
  gpsOff,
  needPermission,
  needPrecise,
  needBackgroundSetup,
}

/// Lokatsiya aniq o'chirilganda (GPS, ruxsat yoki aniqlik) rahbarga xabar
/// shuncha vaqtdan keyin ketadi (server ham shu qoida bilan ishlaydi).
const locationAlertGrace = Duration(minutes: 1);

/// Android: batareya cheklovi va ishlab chiqaruvchi autostart ekranlari
/// (`BackgroundSettingsChannel.kt`).
class _BackgroundSettings {
  static const _channel = MethodChannel('uz.skor.hodimlar/background_settings');

  static Future<bool> _call(String method, {required bool fallback}) async {
    if (!Platform.isAndroid) return fallback;
    try {
      return await _channel.invokeMethod<bool>(method) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() =>
      _call('isIgnoringBatteryOptimizations', fallback: true);
  static Future<bool> openBatterySettings() =>
      _call('openBatterySettings', fallback: false);
  static Future<bool> openAutostartSettings() =>
      _call('openAutostartSettings', fallback: false);

  /// Telefondagi haqiqiy holat: 'on' / 'off' (Xiaomi, Vivo) yoki
  /// 'unknown' — holatni o'qib bo'lmaydigan telefonlarda so'ralmaydi.
  static Future<String> autostartState() async {
    if (!Platform.isAndroid) return 'unknown';
    try {
      return await _channel.invokeMethod<String>('autostartState') ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }
}

/// Xodim sahifalarini joylashuvga «Har doim» ruxsati va yoqilgan GPS
/// bo'lmaguncha to'sib turadi. Android'da undan keyin batareya cheklovi
/// olib tashlangan va (holatini o'qib bo'ladigan Xiaomi/Vivo'da) autostart
/// yoqilgan bo'lishi kerak — aks holda telefon fon servisini o'ldirib,
/// ofisdan tashqaridagi harakat yozilmay qoladi. Hammasi har safar
/// telefonning haqiqiy holatidan o'qiladi: yoqilgan bo'lsa ekran chiqmaydi,
/// keyin o'chirib qo'yilsa yana chiqadi.
///
/// Fon servisi lokatsiyani faqat shu ruxsat bilan yuboradi — ruxsat
/// «faqat foydalanganda» bo'lsa, ilova yopilganda rahbar xaritasida
/// xodimning harakat tarixi bo'sh qolardi. Ruxsat ilova sozlamalardan
/// qaytganda (`resumed`) va GPS holati o'zgarganda qayta tekshiriladi.
class LocationPermissionGate extends StatefulWidget {
  const LocationPermissionGate({required this.child, super.key});

  final Widget child;

  @override
  State<LocationPermissionGate> createState() => _LocationPermissionGateState();
}

class _LocationPermissionGateState extends State<LocationPermissionGate>
    with WidgetsBindingObserver {
  _GateStatus _status = _GateStatus.checking;
  bool _busy = false;
  StreamSubscription<ServiceStatus>? _serviceSub;
  Timer? _poll;
  bool _batteryOk = true;

  /// 'on' / 'off' / 'unknown' — `autostartState` natijasi.
  String _autostart = 'unknown';

  /// Batareya sozlamasi ekrani telefonda umuman topilmasa — faqat shu
  /// sessiya uchun qadam o'tkazib yuboriladi (xodim qulflanib qolmasin).
  bool _batteryScreenMissing = false;

  /// Xodim ishda bo'lsa, bloklangan ekranda rahbarga xabar ketishigacha
  /// sanoq ko'rsatiladi.
  bool _workOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _serviceSub = Geolocator.getServiceStatusStream().listen((_) {
        _check();
        // Android hodisani sozlama haqiqatan o'zgarishidan oldin yuborishi
        // mumkin — o'shanda birinchi tekshiruv eski holatni o'qiydi.
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) _check();
        });
      }, onError: (_) {});
    } catch (_) {}
    // Qo'shimcha kafolat: ilova ochiq turganda holat davriy tekshiriladi
    // (hodisa kelmay qolsa ham GPS o'chirilgani ko'rinadi).
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _check();
      }
    });
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _serviceSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    _GateStatus next;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        next = _GateStatus.gpsOff;
      } else {
        final perm = await Geolocator.checkPermission();
        if (perm != LocationPermission.always) {
          next = _GateStatus.needPermission;
        } else if (await Geolocator.getLocationAccuracy() ==
            LocationAccuracyStatus.reduced) {
          next = _GateStatus.needPrecise;
        } else {
          _batteryOk =
              _batteryScreenMissing ||
              await _BackgroundSettings.isIgnoringBatteryOptimizations();
          _autostart = await _BackgroundSettings.autostartState();
          next = _batteryOk && _autostart != 'off'
              ? _GateStatus.ok
              : _GateStatus.needBackgroundSetup;
        }
      }
    } catch (_) {
      // Ruxsatni aniqlab bo'lmasa xodimni ilovadan butunlay chiqarib
      // qo'ymaymiz.
      next = _GateStatus.ok;
    }
    if (!mounted) return;
    if (next == _status) {
      // Shu ekran ichida bitta qadam bajarilgan bo'lishi mumkin.
      if (next == _GateStatus.needBackgroundSetup) setState(() {});
      return;
    }
    final wasBlocked = _status != _GateStatus.ok;
    _workOpen = await isWorkSessionOpen();
    if (!mounted) return;
    setState(() => _status = next);
    if (next == _GateStatus.ok && wasBlocked) {
      unawaited(GpsLiveTrackerService.instance.startTracking());
    }
  }

  Future<void> _onGrant() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }
      if (perm == LocationPermission.denied) {
        if (!mounted) return;
        if (!await LocationDisclosureDialog.show(context)) return;
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse) {
        if (Platform.isAndroid) {
          if (!mounted) return;
          if (!await LocationDisclosureDialog.showBackgroundDisclosure(
            context,
          )) {
            return;
          }
        }
        // Android 11+ da bu so'rov ilova sozlamalarini ochadi, qaytganda
        // `resumed` orqali qayta tekshiriladi.
        final status = await Permission.locationAlways.request();
        if (status.isPermanentlyDenied ||
            (Platform.isIOS && !status.isGranted)) {
          await Geolocator.openAppSettings();
        }
      } else if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
      await _check();
    }
  }

  Future<void> _onBattery() async {
    final opened = await _BackgroundSettings.openBatterySettings();
    if (!opened) {
      // Telefonda bunday sozlama ekrani topilmadi — xodimni qulflab
      // qo'ymaslik uchun bu sessiyada qadamni o'tkazib yuboramiz.
      _batteryScreenMissing = true;
      await _check();
    }
  }

  Future<void> _onAutostart() async {
    // Sozlamadan qaytganda (`resumed`) holat telefondan qayta o'qiladi.
    final opened = await _BackgroundSettings.openAutostartSettings();
    if (!opened) await _check();
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _GateStatus.ok:
        return widget.child;
      case _GateStatus.checking:
        return Scaffold(
          backgroundColor: context.colors.background,
          body: const Center(child: CircularProgressIndicator()),
        );
      case _GateStatus.gpsOff:
        return _GateView(
          icon: Icons.location_off_rounded,
          title: context.tr('loc_gate_gps_off_title'),
          description: context.tr('loc_gate_gps_off_desc'),
          extra: _workOpen ? const _WorkAlertCard() : null,
          primaryLabel: context.tr('loc_gate_btn_gps'),
          onPrimary: Geolocator.openLocationSettings,
          busy: _busy,
        );
      case _GateStatus.needPrecise:
        return _GateView(
          icon: Icons.my_location_rounded,
          title: context.tr('loc_gate_precise_title'),
          description: context.tr('loc_gate_precise_desc'),
          extra: _workOpen ? const _WorkAlertCard() : null,
          primaryLabel: context.tr('loc_gate_btn_settings'),
          onPrimary: Geolocator.openAppSettings,
          busy: _busy,
        );
      case _GateStatus.needPermission:
        return _GateView(
          icon: Icons.share_location_rounded,
          title: context.tr('loc_gate_title'),
          description: context.tr('loc_gate_desc'),
          steps: [context.tr('loc_gate_step_1'), context.tr('loc_gate_step_2')],
          extra: _workOpen ? const _WorkAlertCard() : null,
          primaryLabel: context.tr('loc_gate_btn_grant'),
          onPrimary: _onGrant,
          secondaryLabel: context.tr('loc_gate_btn_settings'),
          onSecondary: Geolocator.openAppSettings,
          busy: _busy,
        );
      case _GateStatus.needBackgroundSetup:
        return _GateView(
          icon: Icons.battery_charging_full_rounded,
          title: context.tr('loc_gate_bg_title'),
          description: context.tr('loc_gate_bg_desc'),
          extra: Column(
            children: [
              _SetupTile(
                label: context.tr('loc_gate_btn_battery'),
                done: _batteryOk,
                onTap: _onBattery,
              ),
              if (_autostart != 'unknown')
                _SetupTile(
                  label: context.tr('loc_gate_btn_autostart'),
                  done: _autostart == 'on',
                  onTap: _onAutostart,
                ),
            ],
          ),
          primaryLabel: context.tr('loc_gate_btn_check'),
          onPrimary: () async {
            await _check();
            return null;
          },
          busy: _busy,
        );
    }
  }
}

/// Ish vaqtida lokatsiya o'chirilganda: rahbarga xabar ketishigacha sanoq,
/// keyin "xabar yuborildi". Sanoq lokatsiya haqiqatan o'chirilgan paytdan
/// (fonda bo'lsa ham) boshlanadi.
class _WorkAlertCard extends StatefulWidget {
  const _WorkAlertCard();

  @override
  State<_WorkAlertCard> createState() => _WorkAlertCardState();
}

class _WorkAlertCardState extends State<_WorkAlertCard> {
  DateTime _since = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    readLocationBadSince().then((since) {
      if (since != null && since.isBefore(_since) && mounted) {
        setState(() => _since = since);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = locationAlertGrace - DateTime.now().difference(_since);
    final sent = left <= Duration.zero;
    final color = sent ? context.colors.error : const Color(0xFFEA580C);
    final secs = left.inSeconds.clamp(0, 3600);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            sent ? Icons.mark_email_read_rounded : Icons.timer_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sent
                  ? context.tr('loc_alert_sent')
                  : context.tr('loc_alert_countdown', {
                      'time':
                          '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                    }),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.label,
    required this.done,
    required this.onTap,
  });

  final String label;
  final bool done;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: done
            ? context.colors.primary.withValues(alpha: 0.08)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: done ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: done
                      ? context.colors.primary
                      : context.colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                if (!done)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GateView extends StatelessWidget {
  const _GateView({
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimary,
    required this.busy,
    this.steps = const [],
    this.extra,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> steps;
  final Widget? extra;
  final String primaryLabel;
  final Future<Object?> Function() onPrimary;
  final String? secondaryLabel;
  final Future<Object?> Function()? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: context.colors.primary,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    for (var i = 0; i < steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: context.colors.primary,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.onPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                steps[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (extra != null) ...[const SizedBox(height: 20), extra!],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: busy ? null : onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: context.colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            primaryLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  if (secondaryLabel != null && onSecondary != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy ? null : onSecondary,
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.textSecondary,
                      ),
                      child: Text(secondaryLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
