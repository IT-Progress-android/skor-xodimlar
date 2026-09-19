import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/services/auth_token_store.dart';
import 'package:skore_hodimlar/core/services/network_connectivity_service.dart';
import 'package:skore_hodimlar/router/app_router.dart';

class DioClient {
  final Dio dio;

  DioClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          // Aloqa o'rnatish — server band bo'lsa navbat kutiladi (30s)
          connectTimeout: const Duration(seconds: 30),
          // Javobni kutish — og'ir hisobotlar uchun (60s)
          receiveTimeout: const Duration(seconds: 60),
          // Ma'lumot yuborish (30s)
          sendTimeout: const Duration(seconds: 30),
          contentType: Headers.jsonContentType,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'SkorXodimlar/1.0 (Flutter; Mobile)',
          },
          // 4xx javoblarni ham o'zimiz ishlaymiz
          validateStatus: (kod) => kod != null && kod < 500,
        ),
      ) {
    // 1. So'rov URL va sarlavhalarini tekshirish va to'g'rilash
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Xodim tokeni bo'lsa — har bir so'rovga qo'shamiz.
          final token = AuthTokenStore.instance.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // MUHIM: Server (Apache/Engintron) yo'l oxiridagi `/`ni yoqtirmaydi —
          // aksincha, slash bilan yuborilsa 301 bilan `/public/api/...`ga
          // (slashsiz) qayta yo'naltiradi. Shu redirectni Dio avtomatik POST
          // -> GET qilib bosib o'tadi va body (masalan `phone`) yo'qoladi —
          // aynan "phone kelmadi" xatosining sababi shu edi. Shuning uchun
          // yo'lda ORTIQCHA `/` bo'lsa olib tashlaymiz, HECH QACHON qo'shmaymiz.
          final p = options.path;
          if (p.length > 1 && p.endsWith('/') && !p.contains('?')) {
            options.path = p.substring(0, p.length - 1);
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          // 301/302/307/308 redirect bo'lsa — POST metod va body'ni saqlab qolgan holda qayta yuborish.
          // `_redirectRetried` bayrog'i bilan faqat BIR marta qayta urinamiz —
          // aks holda onRequest/onResponse bir-birini cheksiz aylantirib
          // yuborishi mumkin (masalan server yana redirect qaytarsa).
          final statusCode = response.statusCode;
          final location = response.headers.value('location');
          final alreadyRetried =
              response.requestOptions.extra['_redirectRetried'] == true;
          if ((statusCode == 301 ||
                  statusCode == 302 ||
                  statusCode == 307 ||
                  statusCode == 308) &&
              location != null &&
              location.isNotEmpty &&
              !alreadyRetried) {
            final reqOptions = response.requestOptions;
            try {
              final newResponse = await dio.request(
                location,
                data: reqOptions.data,
                queryParameters: reqOptions.queryParameters,
                options: Options(
                  method: reqOptions.method,
                  headers: Map<String, dynamic>.from(reqOptions.headers),
                  contentType: reqOptions.contentType,
                  followRedirects: false,
                  extra: {
                    ...Map<String, dynamic>.from(reqOptions.extra),
                    '_redirectRetried': true,
                  },
                ),
              );
              return handler.resolve(newResponse);
            } catch (e) {
              return handler.next(response);
            }
          }

          // 401 — token yo'q yoki eskirgan (backend majburiy rejimga
          // o'tkazilganda eski sessiyalarda shunday bo'ladi). Tokenni
          // tozalab, foydalanuvchini qayta login'ga yo'naltiramiz.
          if (response.statusCode == 401) {
            final code = (response.data is Map)
                ? (response.data as Map)['code']?.toString()
                : null;
            if (code == 'TOKEN_REQUIRED' || code == 'TOKEN_INVALID') {
              AuthTokenStore.instance.lastLogoutReason =
                  (response.data as Map)['reason']?.toString();
              unawaited(_forceRelogin());
            }
          }

          // Muvaffaqiyatli tarmoq javobi kelsa — aloqani faol (online) deb belgilaymiz
          if (response.statusCode != null && response.statusCode! < 500) {
            NetworkConnectivityService.instance.notifyOnline();
          }

          handler.next(response);
        },
        onError: (e, handler) {
          // Tarmoq uzilishi, timeout yoki socket xatosi bo'lsa darhol offline ga o'tkazish
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.error is SocketException) {
            NetworkConnectivityService.instance.notifyOffline();
          }
          handler.next(e);
        },
      ),
    );
  }

  /// Token yaroqsiz bo'lganda sessiyani tozalab, login ekraniga qaytaramiz.
  /// Bir nechta so'rov bir vaqtda 401 qaytarsa ham faqat bir marta ishlaydi.
  static bool _reloginInProgress = false;

  static Future<void> _forceRelogin() async {
    if (_reloginInProgress) return;
    _reloginInProgress = true;
    try {
      await AuthTokenStore.instance.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('phone');
      await prefs.remove('staff_phone');
      await prefs.remove('staff_id');
      await prefs.remove('person_code');
      if (AppRouter.router.state.uri.path != '/login') {
        AppRouter.router.go('/login');
      }
    } catch (_) {
    } finally {
      _reloginInProgress = false;
    }
  }
}
