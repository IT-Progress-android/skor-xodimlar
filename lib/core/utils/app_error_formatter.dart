import 'package:dio/dio.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';

/// Barcha xatoliklarni foydalanuvchi uchun tushunarli, joriy ilova tiliga
/// o'girilgan matnga aylantiruvchi yagona yordamchi sinf. Bu sinf blok /
/// repository / data source qatlamlarida ishlatiladi — ularda BuildContext
/// yo'q, shuning uchun [AppLocalizations.trStatic] orqali tarjima qilinadi.
class AppErrorFormatter {
  /// Har qanday xatolik (Exception, DioException, String, Error)ni joriy
  /// ilova tiliga aylantiradi.
  static String toUzbek(dynamic error) {
    if (error == null) {
      return AppLocalizations.trStatic('err_unknown');
    }

    if (error is DioException) {
      return _formatDioException(error);
    }

    String raw = error.toString().trim();
    // Exception nomlarini tozalash
    raw = raw.replaceFirst(
      RegExp(
        r'^(Exception|ServerException|NetworkException|ClientException|StateError|ArgumentError):\s*',
      ),
      '',
    );

    return sanitizeMessage(raw);
  }

  /// DioException xatoliklarini tahlil qilish
  static String _formatDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return AppLocalizations.trStatic('err_connection_timeout');
      case DioExceptionType.receiveTimeout:
        return AppLocalizations.trStatic('err_receive_timeout');
      case DioExceptionType.connectionError:
        return AppLocalizations.trStatic('err_connection_error');
      case DioExceptionType.cancel:
        return AppLocalizations.trStatic('err_cancelled');
      case DioExceptionType.badCertificate:
        return AppLocalizations.trStatic('err_bad_certificate');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final resData = e.response?.data;
        if (resData is Map && resData['message'] != null) {
          final serverMsg = resData['message'].toString();
          return sanitizeMessage(serverMsg, statusCode: statusCode);
        }
        return fromStatusCode(statusCode);
      case DioExceptionType.unknown:
      default:
        final msg = e.message ?? e.error?.toString() ?? '';
        return sanitizeMessage(msg);
    }
  }

  /// HTTP Status kodlari bo'yicha tushunarli xabarlar
  static String fromStatusCode(int? code) {
    switch (code) {
      case 400:
        return AppLocalizations.trStatic('err_status_400');
      case 401:
        return AppLocalizations.trStatic('err_status_401');
      case 403:
        return AppLocalizations.trStatic('err_status_403');
      case 404:
        return AppLocalizations.trStatic('err_status_404');
      case 405:
        return AppLocalizations.trStatic('err_status_405');
      case 413:
        return AppLocalizations.trStatic('err_status_413');
      case 419:
        return AppLocalizations.trStatic('err_status_419');
      case 422:
        return AppLocalizations.trStatic('err_status_422');
      case 429:
        return AppLocalizations.trStatic('err_status_429');
      case 500:
        return AppLocalizations.trStatic('err_status_500');
      case 502:
      case 503:
      case 504:
        return AppLocalizations.trStatic('err_status_5xx');
      default:
        return AppLocalizations.trStatic('err_status_unknown', {
          'code':
              code?.toString() ?? AppLocalizations.trStatic('err_unknown_code'),
        });
    }
  }

  /// Har qanday server xabari yoki matnni filtrdan o'tkazib tozalash
  static String sanitizeMessage(String raw, {int? statusCode}) {
    final lower = raw.toLowerCase().trim();

    if (lower.isEmpty) {
      return fromStatusCode(statusCode);
    }

    // 1. Laravel routing va method xatolari (eng mashhuri: MethodNotAllowed)
    if (lower.contains('get method is not supported') ||
        lower.contains('post method is not supported') ||
        lower.contains('methodnotallowed') ||
        lower.contains('supported methods:') ||
        lower.contains('the route') ||
        lower.contains('could not be found')) {
      return AppLocalizations.trStatic('err_status_405');
    }

    // 2. Autentifikatsiya va Sessiya
    if (lower.contains('unauthenticated') ||
        lower.contains('token expired') ||
        lower.contains('jwt') ||
        lower.contains('unauthorized')) {
      return AppLocalizations.trStatic('login_session_expired');
    }

    // 3. Fayl / Rasm hajmi xatolari
    if (lower.contains('failed to upload') ||
        lower.contains('upload failed') ||
        lower.contains('payload too large') ||
        lower.contains('file too large') ||
        statusCode == 413) {
      return AppLocalizations.trStatic('err_image_too_large');
    }

    // 4. Tarmoq va Socket xatolari
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('broken pipe') ||
        lower.contains('os error') ||
        lower.contains('handshake') ||
        lower.contains('clientexception')) {
      return AppLocalizations.trStatic('err_network_socket');
    }

    // 5. Vaqt tugashi (Timeout)
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return AppLocalizations.trStatic('err_timeout_generic');
    }

    // 6. Server xatolari (500, crash)
    if (lower.contains('internal server error') ||
        lower.contains('server error') ||
        lower.contains('sqlstate') ||
        statusCode == 500) {
      return AppLocalizations.trStatic('err_server_crash');
    }

    // 7. Foydalanuvchi topilmaganligi
    if (lower.contains('user not found') ||
        lower.contains('staff not found') ||
        lower.contains('not found in system')) {
      return AppLocalizations.trStatic('err_user_not_found');
    }

    // 8. So'rovlar ko'pligi (429)
    if (lower.contains('too many requests') || statusCode == 429) {
      return AppLocalizations.trStatic('err_too_many_requests');
    }

    // 9. Validatsiya
    if (lower.contains('the given data was invalid') ||
        lower.contains('validation error') ||
        statusCode == 422) {
      return AppLocalizations.trStatic('err_validation');
    }

    // 10. Yuz aniqlanmadi (FaceID)
    if (lower.contains('no face') || lower.contains('no_face')) {
      return AppLocalizations.trStatic('err_no_face');
    }

    // 11. Format va JSON xatolari
    if (lower.contains('formatexception') ||
        lower.contains('syntaxerror') ||
        lower.contains('unexpected character') ||
        lower.contains('is not a subtype of')) {
      return AppLocalizations.trStatic('err_format');
    }

    // 12. Dasturiy null / type xatolari
    if (lower.contains('null check operator') ||
        lower.contains('nosuchmethoderror') ||
        lower.contains('typeerror')) {
      return AppLocalizations.trStatic('err_unexpected');
    }

    // 13. HTML sahifa qaytib qolsa (Nginx 404/502 sahifasi)
    if (lower.contains('<!doctype html') ||
        lower.contains('<html') ||
        lower.contains('<head>')) {
      return AppLocalizations.trStatic('err_html_page');
    }

    // 14. Agar matn allaqachon tushunarli o'zbekcha bo'lsa (backend har doim
    // o'zbek tilida javob beradi), o'zini qaytaramiz — bu ilova tiliga
    // bog'liq emas, chunki bu backend'ning xom matni.
    final uzbekMarkers = [
      'xato',
      'yuz',
      'kirish',
      'davomat',
      'topilmadi',
      'ishlamayapti',
      'urinib',
      'masofa',
      'joylashuv',
      'muvaffaqiyatli',
      'belgilandi',
      'qayd',
      'ruxsat',
      'yetarli',
      'bog\'lan',
      'aloqa',
      'tekshiring',
      'tizim',
      'raqam',
      'parol',
      'baza',
      'admin',
      'xodim',
    ];
    final isUzbek = uzbekMarkers.any(lower.contains);
    if (isUzbek) {
      return raw;
    }

    // 15. Agar inglizcha texnik so'zlar bo'lsa, uni yopib umumiy xabar beramiz
    final englishTechnicalWords = [
      'error',
      'exception',
      'failed',
      'cannot',
      'could not',
      'request',
      'status',
      'response',
      'invalid',
      'undefined',
      'null',
      'unknown',
      'abort',
      'denied',
    ];
    final isEnglishTechnical = englishTechnicalWords.any(lower.contains);
    if (isEnglishTechnical) {
      if (statusCode != null) {
        return fromStatusCode(statusCode);
      }
      return AppLocalizations.trStatic('err_generic');
    }

    return raw.isNotEmpty ? raw : AppLocalizations.trStatic('err_generic');
  }
}
