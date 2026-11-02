import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/errors/exceptions.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/services/network_diagnostics_service.dart';
import 'package:skore_hodimlar/core/utils/dio_retry_helper.dart';
import 'package:skore_hodimlar/features/auth/data/models/staff_model.dart';

/// `POST /bot/staff/login` javobi.
class LoginResult {
  final List<StaffModel> staff;
  final String? token;
  final bool selectRequired;

  const LoginResult({
    required this.staff,
    this.token,
    this.selectRequired = false,
  });
}

class _RequestBodyLostException implements Exception {
  final Response<dynamic> response;
  final String serverMessage;

  const _RequestBodyLostException({
    required this.response,
    required this.serverMessage,
  });
}

abstract class AuthRemoteDataSource {
  Future<LoginResult> loginStaff(
    String phone, {
    int? staffId,
    String? personCode,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient dioClient;

  AuthRemoteDataSourceImpl(this.dioClient);

  static String _formatTime([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final off = now.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)} '
        '(UTC$sign${two(off.inHours.abs())}:${two(off.inMinutes.abs() % 60)})';
  }

  static String _buildDetailedErrorMessage({
    required String apiError,
    required int? statusCode,
    required String endpoint,
    required DateTime timestamp,
    NetworkIncident? incident,
  }) {
    final ip = incident?.probe.publicIp ?? 'aniqlanmoqda...';
    final isp = incident?.probe.isp;
    final timeStr = _formatTime(timestamp);
    return [
      '❌ API xatoligi${statusCode != null ? " (HTTP $statusCode)" : ""}: $apiError',
      '🕒 Vaqt: $timeStr',
      '🌐 Tashqi IP: $ip${isp != null && isp.isNotEmpty ? " ($isp)" : ""}',
      '🔗 So\'rov: POST ${ApiConstants.baseUrl}$endpoint',
      if (incident?.edge != null) '☁️ CDN: ${incident!.edge}',
    ].join('\n');
  }

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
      } on _RequestBodyLostException catch (lostErr) {
        if (attempt == _maxBodyLossRetries) {
          final failTime = DateTime.now();
          final incident = await NetworkDiagnosticsService.instance
              .recordLoginFailureResponse(
                lostErr.response,
                customErrorType: 'HTTP_422_BODY_LOST',
              );
          final detailedMsg = _buildDetailedErrorMessage(
            apiError: '${lostErr.response.data}',
            statusCode: lostErr.response.statusCode,
            endpoint: ApiConstants.staffLogin,
            timestamp: failTime,
            incident: incident,
          );
          debugPrint(
            '❌ [LOGIN YAKUNIY XATO] [${_formatTime(failTime)}]\n$detailedMsg',
          );
          throw ServerException(detailedMsg);
        }
        final delay = Duration(milliseconds: 400 * (attempt + 1));
        debugPrint(
          '🔁 [LOGIN] [${_formatTime()}] 422 javob keldi (${lostErr.serverMessage}), '
          '${delay.inMilliseconds}ms dan keyin boshqa kodlash usulida qayta urinilmoqda '
          '(${attempt + 1}/$_maxBodyLossRetries)...',
        );
        await Future.delayed(delay);
      }
    }

    throw ServerException(AppLocalizations.trStatic('err_server_generic'));
  }

  Future<LoginResult> _attemptLogin({
    required String serverPhone,
    required int? staffId,
    required String? personCode,
    required int attempt,
  }) async {
    final reqTime = DateTime.now();
    try {
      final payload = <String, dynamic>{
        'phone': serverPhone,
        'id': ?staffId,
        'person_code': ?personCode,
      };

      // Har bir urinishda turli encoding qo'llaymiz:
      // 0-urinish: JSON (application/json)
      // 1-urinish: Form URL-encoded (application/x-www-form-urlencoded) — ba'zi proxy/WAF JSON oqimini qirqsa ham form-urlencoded'ni o'tkazadi
      // 2-urinish: Multipart FormData
      final dynamic requestData;
      final String contentType;
      if (attempt == 1) {
        requestData = payload;
        contentType = Headers.formUrlEncodedContentType;
      } else if (attempt == 2) {
        requestData = FormData.fromMap(payload);
        contentType = Headers.multipartFormDataContentType;
      } else {
        requestData = jsonEncode(payload);
        contentType = Headers.jsonContentType;
      }

      debugPrint(
        '🔐 [LOGIN] [${_formatTime(reqTime)}] So\'rov yuborilmoqda (urinish ${attempt + 1}, format: $contentType) -> '
        '${ApiConstants.baseUrl}${ApiConstants.staffLogin} | Tel: $serverPhone | staffId: $staffId '
        '| personCode: $personCode',
      );

      final response = await DioRetryHelper.withRetry(
        () => dioClient.dio.post(
          ApiConstants.staffLogin,
          data: requestData,
          queryParameters: {'phone': serverPhone},
          options: Options(
            contentType: contentType,
            headers: {'Accept': 'application/json'},
            validateStatus: (s) => s != null && s < 500,
            followRedirects: false,
          ),
        ),
      );

      final respTime = DateTime.now();
      debugPrint(
        '🔐 [LOGIN] [${_formatTime(respTime)}] Javob keldi <- Status: ${response.statusCode} | '
        'Javob: ${response.data}',
      );

      final body = (response.data is Map)
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        final token = body['token']?.toString();
        debugPrint(
          '✅ [LOGIN] [${_formatTime(respTime)}] Muvaffaqiyatli -> staff soni: '
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
        debugPrint(
          '❌ [LOGIN] [${_formatTime(respTime)}] 404 — raqam tizimda topilmadi: $serverPhone | Javob: ${response.data}',
        );
        throw NotFoundException(
          AppLocalizations.trStatic('err_phone_not_registered'),
        );
      }

      if (response.statusCode == 409 || body['code'] == 'PHONE_AMBIGUOUS') {
        final serverMsg = body['message']?.toString() ?? '';
        debugPrint(
          '⚠️ [LOGIN] [${_formatTime(respTime)}] PHONE_AMBIGUOUS — bir nechta xodim mos keldi: '
          '$serverPhone | verification_hint: ${body['verification_hint']}',
        );
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
        final serverMsg = body['message']?.toString() ?? '${response.data}';
        debugPrint(
          '⚠️ [LOGIN] [${_formatTime(respTime)}] 422 — validatsiya xatosi: $serverMsg | Raw: ${response.data}',
        );
        if (serverMsg.contains('majburiy') || serverMsg.contains('required')) {
          throw _RequestBodyLostException(
            response: response,
            serverMessage: serverMsg,
          );
        }
        final incident = await NetworkDiagnosticsService.instance
            .recordLoginFailureResponse(response, customErrorType: 'HTTP_422');
        throw ServerException(
          _buildDetailedErrorMessage(
            apiError: serverMsg,
            statusCode: 422,
            endpoint: ApiConstants.staffLogin,
            timestamp: respTime,
            incident: incident,
          ),
        );
      }

      final incident = await NetworkDiagnosticsService.instance
          .recordLoginFailureResponse(response);
      final detailed = _buildDetailedErrorMessage(
        apiError: '${response.data}',
        statusCode: response.statusCode,
        endpoint: ApiConstants.staffLogin,
        timestamp: respTime,
        incident: incident,
      );
      debugPrint(
        '❌ [LOGIN] [${_formatTime(respTime)}] Kutilmagan status: ${response.statusCode}\n$detailed',
      );
      throw ServerException(detailed);
    } on DioException catch (e) {
      final errTime = DateTime.now();
      final incident = await NetworkDiagnosticsService.instance
          .recordLoginDioException(e);
      final apiErr = e.response != null
          ? '${e.response?.data}'
          : '${e.type.name}: ${e.message ?? e.error}';
      final detailed = _buildDetailedErrorMessage(
        apiError: apiErr,
        statusCode: e.response?.statusCode,
        endpoint: ApiConstants.staffLogin,
        timestamp: errTime,
        incident: incident,
      );
      debugPrint(
        '❌ [LOGIN TARMOQ XATOSI] [${_formatTime(errTime)}]\n$detailed',
      );
      throw NetworkException(detailed);
    } catch (e) {
      if (e is ServerException ||
          e is NotFoundException ||
          e is NetworkException ||
          e is PhoneAmbiguousException ||
          e is _RequestBodyLostException) {
        rethrow;
      }
      debugPrint('❌ [LOGIN XATO] [${_formatTime()}] $e');
      throw ServerException('❌ Xatolik: $e\n🕒 Vaqt: ${_formatTime()}');
    }
  }
}
