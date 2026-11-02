import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/security/app_lock_service.dart';
import 'package:skore_hodimlar/core/security/pin_pad.dart';
import 'package:skore_hodimlar/core/services/auth_token_store.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/widgets/skor_logo_widget.dart';
import 'package:skore_hodimlar/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:skore_hodimlar/router/app_router.dart';

/// Butun ilova ustidagi qulf. Ilova (va sahifalar) ostida ishlashda davom
/// etadi — push bosilganda ochilgan sahifa qulf ochilgach ko'rinadi.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  final _lock = AppLockService.instance;

  @override
  void initState() {
    super.initState();
    // Login'dan keyin sahifa almashganda — PIN o'rnatish kerakmi?
    AppRouter.router.routerDelegate.addListener(_onRoute);
    _onRoute();
  }

  void _onRoute() => _lock.onRoute(
    AppRouter.router.routerDelegate.currentConfiguration.uri.path,
  );

  @override
  void dispose() {
    AppRouter.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _lock,
      builder: (context, _) {
        final status = _lock.status;
        final covered = status != AppLockStatus.none;
        return Stack(
          children: [
            // Qulf ostidagi sahifa ekran o'quvchiga ham ko'rinmasin.
            ExcludeSemantics(excluding: covered, child: widget.child),
            if (status == AppLockStatus.locked)
              const Positioned.fill(child: _Blocker(child: _LockScreen()))
            else if (status == AppLockStatus.setup)
              const Positioned.fill(child: _Blocker(child: _SetupScreen())),
            // "So'nggi ilovalar"da ichidagi ma'lumot ko'rinmasin.
            if (_lock.obscured && status != AppLockStatus.setup)
              const Positioned.fill(child: _Blocker(child: _PrivacyCover())),
          ],
        );
      },
    );
  }
}

/// Barmoq izi yoki Face ID nomi (telefonga qarab).
Future<String> biometricLabel(BuildContext context) async {
  final face = await AppLockService.instance.hasFace();
  if (!context.mounted) return '';
  return context.tr(face ? 'lock_face' : 'lock_fingerprint');
}

/// Qulf ostidagi sahifaga hech qanday bosish/surish (masalan iOS'dagi
/// chetdan "orqaga" surish) o'tmaydi.
class _Blocker extends StatelessWidget {
  final Widget child;
  const _Blocker({required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    onHorizontalDragStart: (_) {},
    onVerticalDragStart: (_) {},
    child: child,
  );
}

class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    // Navigator'dan tashqarida chiziladi — Scaffold yo'q. `Material`siz
    // logodagi matnlar sariq ikki chiziq bilan chiqadi.
    return Material(
      color: context.colors.background,
      child: const Center(
        child: SkorLogoWidget(size: 110, animateParticles: false),
      ),
    );
  }
}

// ----------------------------------------------------------------- Qulf

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> with WidgetsBindingObserver {
  final _lock = AppLockService.instance;
  String? _error;
  String _bioLabel = '';
  bool _confirmForgot = false;
  bool _loggingOut = false;

  /// Foydalanuvchi barmoq izi oynasini yopdi (Cancel) — belgini o'zi
  /// bosmaguncha yoki ilovadan haqiqatan chiqib qaytmaguncha qayta
  /// so'ralmaydi, PIN bilan kiradi.
  bool _bioDeclined = false;

  /// Ilova haqiqatan fonga chiqdi (barmoq izi oynasi sababli emas).
  bool _wentAway = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _bioLabel = await biometricLabel(context);
      if (mounted) setState(() {});
      unawaited(_tryBiometric());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ilova haqiqatan fondan qaytganda barmoq izi bir marta o'zi so'raladi.
  // Tizimning barmoq izi oynasi ham ilovani "fonga" chiqarib-qaytaradi
  // (ayniqsa Xiaomi'da) — shuni hisobga olmasak, Cancel bosilgach oyna
  // cheksiz qayta ochilardi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_lock.authInProgress) {
      _wentAway = true;
    } else if (state == AppLifecycleState.resumed && _wentAway) {
      _wentAway = false;
      _bioDeclined = false;
      _tryBiometric();
    }
  }

  /// [manual] — foydalanuvchi barmoq izi belgisini o'zi bosdi.
  Future<void> _tryBiometric({bool manual = false}) async {
    if (!mounted ||
        !_lock.biometricEnabled ||
        _confirmForgot ||
        (_bioDeclined && !manual) ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final ok = await _lock.unlockWithBiometric(context.tr('lock_bio_reason'));
    if (!ok) _bioDeclined = true;
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    final profileBloc = context.read<ProfileBloc>();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('user_role') == 'admin') {
        await FcmService.deleteRahbarTokenFromBackend();
      } else {
        await GpsLiveTrackerService.instance.stopTracking();
        await AuthTokenStore.instance.revokeAndClear(sl<DioClient>().dio);
        await FcmService.deleteTokenFromBackend(
          phone: prefs.getString('phone'),
          staffId: prefs.getInt('staff_id'),
        );
      }
      await FcmService.clearPrefsKeepingDeviceId(prefs);
      await FcmService.syncUserRole();
    } catch (_) {}
    await _lock.clear();
    profileBloc.add(LogoutProfile());
    AppRouter.router.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_confirmForgot) {
      return _Shell(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_reset_rounded, size: 64, color: c.primary),
              const SizedBox(height: 16),
              Text(
                context.tr('lock_forgot_title'),
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('lock_forgot_desc'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 15, color: c.textSecondary),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _loggingOut ? null : _logout,
                  child: _loggingOut
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.tr('lock_forgot_confirm')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loggingOut
                    ? null
                    : () => setState(() => _confirmForgot = false),
                child: Text(context.tr('lock_cancel')),
              ),
            ],
          ),
        ),
      );
    }

    return _Shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SkorLogoWidget(
            size: 72,
            showText: false,
            animateParticles: false,
          ),
          const SizedBox(height: 20),
          PinPad(
            title: context.tr('lock_enter_pin'),
            error: _error,
            onCompleted: (pin) async {
              final ok = _lock.unlockWithPin(pin);
              setState(() => _error = ok ? null : context.tr('lock_wrong_pin'));
              return ok;
            },
            // Tooltip ishlatilmaydi: qulf ilova ustida, `Overlay` dan
            // tashqarida turadi (tooltip uni talab qiladi).
            leading: _lock.biometricEnabled
                ? Semantics(
                    button: true,
                    label: _bioLabel,
                    child: IconButton(
                      iconSize: 32,
                      onPressed: () => _tryBiometric(manual: true),
                      icon: Icon(
                        _bioLabel == context.tr('lock_face')
                            ? Icons.face_retouching_natural_rounded
                            : Icons.fingerprint_rounded,
                        color: c.primary,
                      ),
                    ),
                  )
                : null,
            footer: TextButton(
              onPressed: () => setState(() => _confirmForgot = true),
              child: Text(context.tr('lock_forgot')),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------- Birinchi o'rnatish

class _SetupScreen extends StatefulWidget {
  const _SetupScreen();

  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  final _lock = AppLockService.instance;
  String? _first;
  String? _error;

  /// PIN saqlangach barmoq izi taklif qilinadi (telefonda bo'lsa).
  bool _offerBio = false;
  String _bioLabel = '';

  Future<bool> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return true;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = context.tr('lock_mismatch');
      });
      return false;
    }
    final available = await _lock.biometricAvailable();
    if (available && mounted) {
      _bioLabel = await biometricLabel(context);
      setState(() => _offerBio = true);
      // PIN taklif oynasidan keyin saqlanadi — saqlash bilan qulf yo'qoladi.
      _pendingPin = pin;
      return true;
    }
    await _lock.setPin(pin);
    return true;
  }

  String? _pendingPin;

  Future<void> _finish({required bool enableBio}) async {
    final pin = _pendingPin;
    if (pin == null) return;
    if (enableBio) {
      final ok = await _lock.authenticateBiometric(
        context.tr('lock_bio_reason'),
      );
      if (ok) await _lock.setBiometricEnabled(true);
    }
    await _lock.setPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_offerBio) {
      return _Shell(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _bioLabel == context.tr('lock_face')
                      ? Icons.face_retouching_natural_rounded
                      : Icons.fingerprint_rounded,
                  size: 64,
                  color: c.primary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                context.tr('lock_bio_offer_title', {'method': _bioLabel}),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('lock_bio_offer_desc', {'method': _bioLabel}),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 15, color: c.textSecondary),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _finish(enableBio: true),
                  child: Text(context.tr('lock_bio_enable')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _finish(enableBio: false),
                child: Text(context.tr('lock_bio_later')),
              ),
            ],
          ),
        ),
      );
    }

    return _Shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 56, color: c.primary),
          const SizedBox(height: 16),
          PinPad(
            key: ValueKey(_first == null),
            title: context.tr(
              _first == null ? 'lock_setup_title' : 'lock_confirm_title',
            ),
            subtitle: _first == null ? context.tr('lock_setup_desc') : null,
            error: _error,
            onCompleted: _onPin,
          ),
        ],
      ),
    );
  }
}
