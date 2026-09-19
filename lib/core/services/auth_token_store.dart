import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';

/// Xodim tokenini xavfsiz saqlaydi (`Authorization: Bearer <token>` uchun).
///
/// Token `POST /bot/staff/login` javobidan keladi. Backend uni bosqichma-bosqich
/// joriy qilmoqda: hozircha token yuborilmasa ham so'rovlar ishlayveradi
/// (`STAFF_TOKEN_ENFORCE=false`), keyinroq majburiy bo'ladi. Shu sababli ilova
/// token bo'lsa yuboradi, bo'lmasa — eskicha ishlayveradi.
class AuthTokenStore {
  AuthTokenStore._();

  static final AuthTokenStore instance = AuthTokenStore._();

  static const _key = 'staff_api_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Dio interceptor'i sinxron o'qishi uchun xotiradagi nusxa.
  String? _cached;

  String? get token => _cached;

  /// Server 401 bilan chiqarib yuborganda sababi (`reason` maydoni).
  /// Login ekrani buni bir marta ko'rsatib, tozalaydi.
  String? lastLogoutReason;

  String? takeLogoutReason() {
    final r = lastLogoutReason;
    lastLogoutReason = null;
    return r;
  }

  bool get hasToken => _cached != null && _cached!.isNotEmpty;

  /// Ilova ishga tushganda bir marta chaqiriladi.
  Future<void> load() async {
    try {
      _cached = await _storage.read(key: _key);
    } catch (_) {
      // Qurilmada secure storage ishlamasa — tokensiz davom etamiz.
      _cached = null;
    }
  }

  Future<void> save(String token) async {
    _cached = token;
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {}
  }

  Future<void> clear() async {
    _cached = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }

  /// Serverda ham tokenni bekor qiladi, so'ng lokal nusxani o'chiradi.
  ///
  /// Faqat lokal tozalash yetarli emas: server tomonda token muddati
  /// tugagunicha (30 kun) texnik jihatdan ishlayveradi.
  Future<void> revokeAndClear(Dio dio) async {
    final current = _cached;
    if (current != null && current.isNotEmpty) {
      try {
        await dio.post(
          ApiConstants.staffLogout,
          options: Options(
            headers: {'Authorization': 'Bearer $current'},
            validateStatus: (s) => s != null && s < 600,
          ),
        );
      } catch (_) {
        // Tarmoq yo'q bo'lsa ham lokal chiqishni to'xtatmaymiz.
      }
    }
    await clear();
  }
}
