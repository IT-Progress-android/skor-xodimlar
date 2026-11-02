import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qulf ekranida nima ko'rsatiladi.
enum AppLockStatus {
  /// Qulf yo'q (hisobga kirilmagan yoki ochilgan).
  none,

  /// Hisobga kirilgan, lekin PIN hali o'rnatilmagan — majburiy o'rnatish.
  setup,

  /// PIN (yoki barmoq izi / Face ID) so'raladi.
  locked,
}

/// Fonda shundan ko'p turilsa, qaytganda qulf so'raladi.
const appLockBackgroundTimeout = Duration(seconds: 30);

/// Fonda [away] turgandan keyin qulf so'ralishi kerakmi.
@visibleForTesting
bool shouldLockAfter(Duration away) => away >= appLockBackgroundTimeout;

/// PIN xeshi: tuz (salt) bilan SHA-256 — PIN o'zi hech qayerda saqlanmaydi.
@visibleForTesting
String hashPin(String pin, String salt) =>
    sha256.convert(utf8.encode('$salt:$pin')).toString();

/// Ilova qulfi — hamma uchun majburiy (xodim ham, rahbar ham).
///
/// * Ilova yopilib qayta ochilganda (telefon qayta yoqilganda ham) — qulf.
/// * Fonda [appLockBackgroundTimeout] dan ko'p turilsa — qulf.
/// * PIN telefonning xavfsiz xotirasida faqat xesh ko'rinishida saqlanadi;
///   barmoq izi / Face ID yoqilgan bo'lsa, u bilan ham ochiladi.
/// * PIN hisobga bog'langan ([_sessionOwner]): boshqa hisob bilan kirilsa,
///   yangi PIN o'rnatiladi. Hisobdan chiqilganda qulf yo'qoladi.
/// * Fon GPS servisi qulfga bog'liq emas — u ishlashda davom etadi.
class AppLockService extends ChangeNotifier with WidgetsBindingObserver {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const _kHash = 'app_lock_pin_hash';
  static const _kSalt = 'app_lock_pin_salt';
  static const _kOwner = 'app_lock_owner';
  static const _kBio = 'app_lock_biometric';

  /// iOS'da Keychain ilova o'chirilganda ham saqlanib qoladi. Qayta
  /// o'rnatilgandan keyin eski PIN so'ralmasligi uchun birinchi ishga
  /// tushishda qulf ma'lumotlari tozalanadi.
  static const _kInstalled = 'app_lock_installed';

  /// Login jarayonidagi sahifalar — bu yerda hali to'liq kirilmagan
  /// (masalan tashkilot tanlanmagan), qulf ko'rsatilmaydi.
  static const _loginPaths = {'/login', '/select-org'};
  String _path = '';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final LocalAuthentication _auth = LocalAuthentication();

  SharedPreferences? _prefs;
  String? _hash;
  String? _salt;
  String? _owner;
  bool _biometricEnabled = false;

  /// Shu ishga tushirishda qulf ochilganmi. Ilova qayta ishga tushganda
  /// har doim `false` — ya'ni qulf.
  bool _unlocked = false;

  /// Fonda o'tgan vaqt monoton soat bilan o'lchanadi — telefon vaqtini
  /// orqaga surib qulfni chetlab o'tib bo'lmaydi.
  Stopwatch? _away;
  bool _authInProgress = false;

  /// Ilova fonda (yoki o'tish holatida) — "so'nggi ilovalar" ro'yxatida
  /// ichidagi ma'lumot ko'rinmasligi uchun ustiga parda yopiladi.
  bool _obscured = false;
  bool get obscured => _obscured && !_authInProgress;

  /// Tizimning barmoq izi / Face ID oynasi ochiqmi. Bu oyna ham ilovani
  /// vaqtincha "fonga" chiqaradi — uni haqiqiy chiqishdan ajratish uchun.
  /// Oyna yopilgandan keyin ham qisqa vaqt hisoblanadi: ba'zi telefonlar
  /// hayot sikli signallarini kechikib yuboradi.
  bool get authInProgress =>
      _authInProgress ||
      (_authEnded != null &&
          _authEnded!.elapsed < const Duration(milliseconds: 1500));
  Stopwatch? _authEnded;

  bool get biometricEnabled => _biometricEnabled;

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    try {
      if (prefs.getBool(_kInstalled) != true) {
        await _wipeStorage();
        await prefs.setBool(_kInstalled, true);
      }
      final all = await _storage.readAll();
      _hash = all[_kHash];
      _salt = all[_kSalt];
      _owner = all[_kOwner];
      _biometricEnabled = all[_kBio] == 'true';
    } catch (e) {
      debugPrint('⚠️ [QULF] xavfsiz xotira o\'qilmadi: $e');
    }
    WidgetsBinding.instance.addObserver(this);
  }

  /// Joriy hisob: xodim — `staff_id` (telefon raqami o'zgarsa ham PIN
  /// saqlanadi), rahbar — token. `null` — kirilmagan yoki login jarayonida.
  String? get _sessionOwner {
    final p = _prefs;
    if (p == null || _loginPaths.contains(_path)) return null;
    final role = p.getString('user_role');
    final rahbarToken = p.getString('rahbar_token');
    if (role == 'admin' && rahbarToken != null && rahbarToken.isNotEmpty) {
      return 'rahbar:${sha256.convert(utf8.encode(rahbarToken))}';
    }
    final phone = p.getString('phone');
    if (phone == null || phone.isEmpty) return null;
    final id = p.getInt('staff_id');
    return id != null && id > 0 ? 'xodim:$id' : 'xodim:$phone';
  }

  bool get _hasPin =>
      _hash != null &&
      _salt != null &&
      _owner != null &&
      _owner == _sessionOwner;

  AppLockStatus get status {
    if (_sessionOwner == null) return AppLockStatus.none;
    if (!_hasPin) return AppLockStatus.setup;
    return _unlocked ? AppLockStatus.none : AppLockStatus.locked;
  }

  /// Sahifa almashganda (masalan login'dan keyin) holat qayta baholanadi.
  ///
  /// go_router bu xabarni widget qurilayotgan paytda ham beradi (masalan
  /// ilovaning birinchi kadrida) — o'sha payt qayta qurish so'rash xato,
  /// shuning uchun xabar joriy kadr tugagach yuboriladi.
  void onRoute(String path) {
    if (path == _path) return;
    _path = path;
    _notifySafely();
  }

  bool _notifyScheduled = false;

  void _notifySafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks &&
        phase != SchedulerPhase.midFrameMicrotasks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------- PIN

  Future<void> setPin(String pin) async {
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final owner = _sessionOwner;
    // Boshqa hisob uchun o'rnatilsa — oldingi foydalanuvchining barmoq izi
    // sozlamasi o'tib ketmasin.
    if (_owner != null && _owner != owner && _biometricEnabled) {
      await setBiometricEnabled(false);
    }
    _salt = salt;
    _hash = hashPin(pin, salt);
    _owner = owner;
    _unlocked = true;
    // Hisobdan chiqishda `prefs.clear()` bu belgini ham o'chiradi — PIN
    // keyingi ishga tushishda "yangi o'rnatish" deb o'chirilmasin.
    await _prefs?.setBool(_kInstalled, true);
    try {
      await _storage.write(key: _kSalt, value: salt);
      await _storage.write(key: _kHash, value: _hash);
      await _storage.write(key: _kOwner, value: owner);
    } catch (e) {
      debugPrint('⚠️ [QULF] PIN saqlanmadi: $e');
    }
    notifyListeners();
  }

  bool verifyPin(String pin) =>
      _salt != null && _hash != null && hashPin(pin, _salt!) == _hash;

  /// PIN to'g'ri bo'lsa ochadi.
  bool unlockWithPin(String pin) {
    if (!verifyPin(pin)) return false;
    _unlocked = true;
    notifyListeners();
    return true;
  }

  /// Hisobdan chiqishda (PIN unutilganda ham) — qulf ma'lumotlari o'chadi.
  Future<void> clear() async {
    _hash = _salt = _owner = null;
    _biometricEnabled = false;
    _unlocked = false;
    await _wipeStorage();
    notifyListeners();
  }

  Future<void> _wipeStorage() async {
    try {
      for (final k in [_kHash, _kSalt, _kOwner, _kBio]) {
        await _storage.delete(key: k);
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------- Biometrik

  /// Telefonda barmoq izi yoki Face ID sozlanganmi.
  Future<bool> biometricAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Telefonda Face ID bormi (yozuvlar uchun: "Face ID" yoki "Barmoq izi").
  Future<bool> hasFace() async {
    try {
      return (await _auth.getAvailableBiometrics()).contains(
        BiometricType.face,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric(String reason) async {
    if (_authInProgress) return false;
    _authInProgress = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('⚠️ [QULF] biometrik: $e');
      return false;
    } finally {
      _authInProgress = false;
      _authEnded = Stopwatch()..start();
      // Dialog yopilganda ilova "fondan qaytdi" deb hisoblanmasin.
      _away = null;
    }
  }

  Future<bool> unlockWithBiometric(String reason) async {
    if (!_biometricEnabled) return false;
    final ok = await authenticateBiometric(reason);
    if (ok) {
      _unlocked = true;
      notifyListeners();
    }
    return ok;
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    try {
      await _storage.write(key: _kBio, value: '$value');
    } catch (_) {}
    notifyListeners();
  }

  // ---------------------------------------------------- Ilova hayot sikli

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final away = _away?.elapsed;
        _away = null;
        if (away != null && _unlocked && shouldLockAfter(away)) {
          _unlocked = false;
          // Ostidagi sahifada ochiq qolgan klaviatura qulf ustiga chiqmasin.
          FocusManager.instance.primaryFocus?.unfocus();
        }
        _obscured = false;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _obscured = true;
      case AppLifecycleState.paused:
        _obscured = true;
        if (!_authInProgress) _away ??= Stopwatch()..start();
      case AppLifecycleState.detached:
        break;
    }
    notifyListeners();
  }

  /// Qulf ochiq bo'lmaganda "Orqaga" tugmasi ilova ichiga o'tkazilmaydi.
  @override
  Future<bool> didPopRoute() async => status != AppLockStatus.none;

  /// Android 14+ "predictive back" imo-ishorasi ham ilova ichiga o'tmasin.
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) =>
      status != AppLockStatus.none;
}
