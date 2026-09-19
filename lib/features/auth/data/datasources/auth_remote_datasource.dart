import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/errors/exceptions.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/utils/dio_retry_helper.dart';
import 'package:skore_hodimlar/features/auth/data/models/staff_model.dart';

/// `POST /bot/staff/login` javobi.
///
/// Backend tokenni bosqichma-bosqich joriy qilmoqda, shuning uchun [token]
/// null bo'lishi mumkin — u holda ilova eskicha (tokensiz) ishlayveradi.
class LoginResult {
  final List<StaffModel> staff;
  final String? token;

  /// Bir raqamga bir nechta xodim yozuvi mos kelsa, server `select_required:
  /// true` va `token: null` qaytaradi — tashkilot tanlangach, `id` bilan
  /// qayta so'rov yuborilishi kerak.
  final bool selectRequired;

  const LoginResult({
    required this.staff,
    this.token,
    this.selectRequired = false,
  });
}

/// Ba'zi mobil operator/CDN yo'llarida so'rov tanasi yo'lda yo'qolib,
/// server "phone maydoni majburiy" deb javob beradi (foydalanuvchining
/// raqamidagi xato emas). [loginStaff] bunday holatda avtomatik qayta
/// urinadi; faqat barcha urinishlar tugagach shu holat tashqariga chiqadi.
class _RequestBodyLostException implements Exception {}

abstract class AuthRemoteDataSource {
  /// [personCode] — tizim (badge) raqami. Bitta telefonga bir nechta xodim
  /// mos kelganda (PHONE_AMBIGUOUS) aynan kimligini aniqlash uchun.
  Future<LoginResult> loginStaff(
    String phone, {
    int? staffId,
    String? personCode,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient dioClient;

  AuthRemoteDataSourceImpl(this.dioClient);

  /// Kiritilgan matndan aynan 9 xonali abonent raqamini ajratib,
  /// serverga yuboriladigan `998XXXXXXXXX` ko'rinishiga keltiradi.
  static String _toServerPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    while (digits.startsWith('998') && digits.length > 9) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0') && digits.length > 9) {
      digits = digits.substring(1);
    }
    if (digits.length > 9) {
      digits = digits.substring(digits.length - 9);
    }
    return digits.length == 9 ? '998$digits' : raw;
  }

  static List<StaffModel> _parseStaff(Response<dynamic> response) {
    List<dynamic>? raw;
    if (response.data is Map) {
      final body = Map<String, dynamic>.from(response.data as Map);
      raw = (body['staff'] ?? body['data']) as List<dynamic>?;
    } else if (response.data is List) {
      raw = response.data as List<dynamic>;
    }
    if (raw == null) return const [];
    return raw
        .map((e) => StaffModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// So'rov tanasi yo'qolib "phone majburiy" 422 qaytishi — kuzatuvda real
  /// hodisa (bir xil so'rov qayta yuborilganda muvaffaqiyatli o'tadi).
  /// Shuning uchun bu holatda foydalanuvchiga xato ko'rsatishdan oldin
  /// avtomatik ravishda bir necha marta qayta urinamiz.
  static const int _maxBodyLossRetries = 2;

  @override
  Future<LoginResult> loginStaff(
    String phone, {
    int? staffId,
    String? personCode,
  }) async {
    final serverPhone = _toServerPhone(phone);

    for (var attempt = 0; attempt <= _maxBodyLossRetries; attempt++) {
      try {
        return await _attemptLogin(
          serverPhone: serverPhone,
          staffId: staffId,
          personCode: personCode,
          attempt: attempt,
        );
      } on _RequestBodyLostException {
        if (attempt == _maxBodyLossRetries) {
          throw NetworkException(
            AppLocalizations.trStatic('err_request_truncated'),
          );
        }
        final delay = Duration(milliseconds: 400 * (attempt + 1));
        debugPrint(
          '🔁 [LOGIN] So\'rov tanasi yo\'qolgan, ${delay.inMilliseconds}ms '
          'dan keyin qayta urinilmoqda (${attempt + 1}/$_maxBodyLossRetries)...',
        );
        await Future.delayed(delay);
      }
    }

    // Yuqoridagi loop har doim return yoki throw bilan tugaydi; bu qator
    // faqat Dart'ning "har bir yo'l qiymat qaytarishi kerak" tahlili uchun.
    throw ServerException(AppLocalizations.trStatic('err_server_generic'));
  }

  Future<LoginResult> _attemptLogin({
    required String serverPhone,
    required int? staffId,
    required String? personCode,
    required int attempt,
  }) async {
    try {
      // Raqamni ataylab IKKI joyda yuboramiz — body'da ham, query'da ham.
      // Ba'zi mobil operator/CDN yo'llarida so'rov tanasi yo'qolib, server
      // "phone maydoni majburiy" deb javob berardi; query qo'shimcha zaxira.
      final payload = <String, dynamic>{
        'phone': serverPhone,
        'id': ?staffId,
        'person_code': ?personCode,
      };

      debugPrint(
        '🔐 [LOGIN] So\'rov yuborilmoqda (urinish ${attempt + 1}) -> '
        '${ApiConstants.staffLogin} | Tel: $serverPhone | staffId: $staffId '
        '| personCode: $personCode',
      );

      final response = await DioRetryHelper.withRetry(
        () => dioClient.dio.post(
          ApiConstants.staffLogin,
          data: jsonEncode(payload),
          queryParameters: {'phone': serverPhone},
          options: Options(
            contentType: Headers.jsonContentType,
            headers: {'Accept': 'application/json'},
            validateStatus: (s) => s != null && s < 500,
            // Redirect'da POST GET'ga aylanib, tana yo'qolmasligi uchun.
            followRedirects: false,
          ),
        ),
      );

      debugPrint(
        '🔐 [LOGIN] Javob keldi <- Status: ${response.statusCode} | '
        'Javob: ${response.data}',
      );

      final body = (response.data is Map)
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        final token = body['token']?.toString();
        debugPrint(
          '✅ [LOGIN] Muvaffaqiyatli -> staff soni: '
          '${_parseStaff(response).length} | token: '
          '${token != null && token.isNotEmpty ? "bor" : "yo'q"} | '
          'select_required: ${body['select_required']}',
        );
        return LoginResult(
          staff: _parseStaff(response),
          token: (token != null && token.isNotEmpty) ? token : null,
          selectRequired: body['select_required'] == true,
        );
      }

      if (response.statusCode == 404) {
        debugPrint('❌ [LOGIN] 404 — raqam tizimda topilmadi: $serverPhone');
        throw NotFoundException(
          AppLocalizations.trStatic('err_phone_not_registered'),
        );
      }

      // 409 PHONE_AMBIGUOUS — bitta raqamga juda ko'p xodim yozuvi mos keladi,
      // server xavfsizlik uchun kirishni to'xtatgan. Bu foydalanuvchining
      // xatosi emas, shuning uchun aniq va harakatga undaydigan xabar beramiz.
      if (response.statusCode == 409 || body['code'] == 'PHONE_AMBIGUOUS') {
        final serverMsg = body['message']?.toString() ?? '';
        debugPrint(
          '⚠️ [LOGIN] PHONE_AMBIGUOUS — bir nechta xodim mos keldi: '
          '$serverPhone | verification_hint: ${body['verification_hint']}',
        );
        // Server `verification_hint: "person_code"` bersa — xodim o'z tizim
        // (badge) raqamini kiritib kira oladi. UI shu maxsus xatoni ushlab,
        // raqam so'raydigan oyna ko'rsatadi.
        if (body['verification_hint'] == 'person_code') {
          throw PhoneAmbiguousException(
            serverMsg.isNotEmpty
                ? serverMsg
                : AppLocalizations.trStatic('err_phone_ambiguous_badge'),
          );
        }
        throw ServerException(
          serverMsg.isNotEmpty
              ? serverMsg
              : AppLocalizations.trStatic('err_phone_ambiguous_blocked'),
        );
      }

      if (response.statusCode == 422) {
        final serverMsg = body['message']?.toString() ?? '';
        debugPrint('⚠️ [LOGIN] 422 — validatsiya xatosi: $serverMsg');
        // Biz raqamni aniq yuborganmiz. Agar server baribir "maydon majburiy"
        // desa — demak so'rov yo'lda buzilgan (operator/CDN muammosi), bu
        // foydalanuvchining raqamidagi xato emas. Chaqiruvchi (loginStaff)
        // bunday holatda avtomatik qayta uradi.
        if (serverMsg.contains('majburiy') || serverMsg.contains('required')) {
          debugPrint(
            '❌ [LOGIN] So\'rov tanasi yo\'lda yo\'qolgan bo\'lishi mumkin '
            '(phone maydoni serverga yetib bormadi)',
          );
          throw _RequestBodyLostException();
        }
        throw ServerException(
          serverMsg.isNotEmpty
              ? serverMsg
              : AppLocalizations.trStatic('err_invalid_phone_format'),
        );
      }

      debugPrint(
        '❌ [LOGIN] Kutilmagan status: ${response.statusCode} | '
        '${response.data}',
      );
      throw ServerException(AppLocalizations.trStatic('err_server_generic'));
    } on DioException catch (e) {
      debugPrint(
        '❌ [LOGIN TARMOQ XATOSI] type: ${e.type} | message: ${e.message} | '
        'error: ${e.error}',
      );
      throw NetworkException(AppLocalizations.trStatic('err_no_internet'));
    } catch (e) {
      if (e is NotFoundException ||
          e is ServerException ||
          e is NetworkException ||
          e is PhoneAmbiguousException ||
          e is _RequestBodyLostException) {
        rethrow;
      }
      debugPrint('❌ [LOGIN NOMA\'LUM XATOLIK]: $e');
      throw ServerException(AppLocalizations.trStatic('err_no_internet'));
    }
  }
}
