import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';

/// Butun ilova bo'ylab internet aloqasini kuzatuvchi markaziy xizmat.
/// Hech qanday og'ir native paketlarsiz to'g'ridan-to'g'ri dart:io orqali
/// real internet mavjudligini (DNS va Socket orqali) aniqlaydi.
class NetworkConnectivityService with WidgetsBindingObserver {
  NetworkConnectivityService._();

  static final NetworkConnectivityService instance =
      NetworkConnectivityService._();

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isCheckingNotifier = ValueNotifier<bool>(false);

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool get isOnline => isOnlineNotifier.value;
  bool get isOffline => !isOnline;

  Timer? _heartbeatTimer;
  bool _initialized = false;
  bool _isChecking = false;

  /// Xizmatni ishga tushirish (ilova ochilganda bir marta chaqiriladi)
  void init() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Dastlabki tekshiruv
    unawaited(checkConnection());

    _scheduleHeartbeat();
  }

  /// Ilova holati o'zgarganda (masalan telefonda ilovaga qayta kirilganda)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkConnection());
    }
  }

  /// Dio so'rovi tarmoq xatosi bilan yiqilganda darhol offline holatiga o'tkazish
  void notifyOffline() {
    if (isOnlineNotifier.value) {
      isOnlineNotifier.value = false;
      _controller.add(false);
      _scheduleHeartbeat();
    }
  }

  /// Dio so'rovi muvaffaqiyatli o'tganda darhol online holatiga o'tkazish
  void notifyOnline() {
    if (!isOnlineNotifier.value) {
      isOnlineNotifier.value = true;
      _controller.add(true);
      _scheduleHeartbeat();
    }
  }

  /// Davriy tekshiruv:
  /// - Internet yo'q bo'lsa har 4 soniyada qayta tekshiradi (aloqa kelishi bilan darhol sezish uchun).
  /// - Internet bor bo'lsa har 25 soniyada yurak urishi (heartbeat) qiladi.
  void _scheduleHeartbeat() {
    _heartbeatTimer?.cancel();
    final interval = isOnline
        ? const Duration(seconds: 25)
        : const Duration(seconds: 4);

    _heartbeatTimer = Timer(interval, () async {
      await checkConnection();
      _scheduleHeartbeat();
    });
  }

  /// Haqiqiy internet ulanishini tekshirish
  Future<bool> checkConnection() async {
    if (_isChecking) return isOnline;
    _isChecking = true;
    isCheckingNotifier.value = true;

    bool hasConnection = false;

    try {
      // 1-bosqich: Google DNS domenini tekshirish (DNS tekshiruvi)
      final result = await InternetAddress.lookup(
        'dns.google',
      ).timeout(const Duration(milliseconds: 2500), onTimeout: () => []);

      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        hasConnection = true;
      }
    } catch (_) {
      hasConnection = false;
    }

    // Agar DNS ishlamasa, 2-bosqich: to'g'ridan-to'g'ri IP orqali socket ulanish (Cloudflare / Google)
    if (!hasConnection) {
      try {
        final socket = await Socket.connect(
          '1.1.1.1',
          53,
          timeout: const Duration(milliseconds: 2500),
        );
        socket.destroy();
        hasConnection = true;
      } catch (_) {
        try {
          final socket = await Socket.connect(
            '8.8.8.8',
            53,
            timeout: const Duration(milliseconds: 2500),
          );
          socket.destroy();
          hasConnection = true;
        } catch (_) {
          hasConnection = false;
        }
      }
    }

    _isChecking = false;
    isCheckingNotifier.value = false;

    if (isOnlineNotifier.value != hasConnection) {
      isOnlineNotifier.value = hasConnection;
      _controller.add(hasConnection);
      _scheduleHeartbeat();
    }

    return hasConnection;
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _controller.close();
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
  }
}
