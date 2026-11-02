import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/errors/exceptions.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/attendance/data/models/attendance_model.dart';

abstract class AttendanceRemoteDataSource {
  Future<TodayAttendanceModel> getTodayAttendance(String phone);
  Future<List<AttendanceReportModel>> getPeriodAttendance(
    String phone,
    String period,
  );
  Future<CheckLocationModel> checkLocation(
    String phone,
    double lat,
    double lng,
    String status, {
    String? verifyToken,
    bool isMock = false,
  });
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final Dio dio;

  AttendanceRemoteDataSourceImpl(this.dio);

  @override
  Future<TodayAttendanceModel> getTodayAttendance(String phone) async {
    final sw = Stopwatch()..start();
    _log('--> GET ${ApiConstants.attendanceDay} phone=$phone');
    try {
      final response = await dio.get(
        ApiConstants.attendanceDay,
        queryParameters: {'phone': phone},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      _logResponse(response, sw);
      _throwIfServerError(response);
      if (response.data is Map) {
        return TodayAttendanceModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(
        AppErrorFormatter.fromStatusCode(response.statusCode),
      );
    } on DioException catch (e) {
      _logError(e, sw);
      throw ServerException(AppErrorFormatter.toUzbek(e));
    }
  }

  /// Davomat so'rovlari logi: `[DAVOMAT API]` bo'yicha filtrlang
  /// (`adb logcat | grep "DAVOMAT API"`). Token yozilmaydi.
  static void _log(String message) {
    final ts = DateTime.now().toIso8601String();
    // debugPrint uzun qatorlarni kesib yubormasligi uchun bo'laklab chiqaramiz.
    const chunk = 800;
    final text = '[DAVOMAT API] $ts $message';
    for (var i = 0; i < text.length; i += chunk) {
      debugPrint(
        text.substring(i, i + chunk > text.length ? text.length : i + chunk),
      );
    }
  }

  static String _json(Object? v) {
    if (v == null) return '-';
    try {
      return jsonEncode(v);
    } catch (_) {
      return v.toString();
    }
  }

  void _logResponse(Response<dynamic> res, Stopwatch sw) {
    final req = res.requestOptions;
    _log(
      '<-- ${res.statusCode} ${req.method} ${req.uri} '
      '(${sw.elapsedMilliseconds} ms) javob=${_json(res.data)}',
    );
  }

  void _logError(DioException e, Stopwatch sw) {
    _log(
      'xx  ${e.requestOptions.method} ${e.requestOptions.uri} '
      '(${sw.elapsedMilliseconds} ms) dio=${e.type.name} '
      'status=${e.response?.statusCode} xabar=${e.message} '
      'javob=${_json(e.response?.data)}',
    );
  }

  /// Xato javobi (`5xx` yoki `status: error`) bo'sh davomat sifatida
  /// o'qilmasin — aks holda kelgan xodim ekranda "kelmagan" bo'lib chiqadi.
  void _throwIfServerError(Response<dynamic> response) {
    final data = response.data;
    final isError =
        (response.statusCode ?? 0) >= 500 ||
        (data is Map && data['status'] == 'error');
    if (!isError) return;
    final message = data is Map ? data['message']?.toString() : null;
    throw ServerException(
      message != null && message.isNotEmpty
          ? message
          : AppErrorFormatter.fromStatusCode(response.statusCode),
    );
  }

  @override
  Future<List<AttendanceReportModel>> getPeriodAttendance(
    String phone,
    String period,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final endpoint = _periodEndpoint(period);
      _log('--> POST $endpoint phone=$phone');

      final response = await dio.post(
        endpoint,
        data: {'phone': phone},
        queryParameters: {'phone': phone},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      _logResponse(response, sw);
      _throwIfServerError(response);
      List<dynamic> reportsList = <dynamic>[];
      if (response.data is Map) {
        final dataMap = response.data as Map;
        if (dataMap.containsKey('reports') && dataMap['reports'] is List) {
          reportsList = dataMap['reports'] as List;
        } else if (dataMap.containsKey('data') && dataMap['data'] is List) {
          reportsList = dataMap['data'] as List;
        }
      } else if (response.data is List) {
        reportsList = response.data as List;
      }

      return reportsList
          .map(
            (e) => AttendanceReportModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } on DioException catch (e) {
      _logError(e, sw);
      throw ServerException(AppErrorFormatter.toUzbek(e));
    } catch (e) {
      if (e is ServerException) rethrow;
      _log('xx  xato=$e (${sw.elapsedMilliseconds} ms)');
      throw ServerException('Internetga ulanmagansiz');
    }
  }

  @override
  Future<CheckLocationModel> checkLocation(
    String phone,
    double lat,
    double lng,
    String status, {
    String? verifyToken,
    bool isMock = false,
  }) async {
    final sw = Stopwatch()..start();
    _log(
      '--> POST ${ApiConstants.checkLocation} phone=$phone status=$status '
      'lat=$lat lng=$lng is_mock=$isMock '
      'verify_token=${verifyToken == null || verifyToken.isEmpty ? 'YOQ' : 'bor'}',
    );
    try {
      final response = await dio.post(
        ApiConstants.checkLocation,
        data: {
          'phone': phone,
          'lat': lat,
          'lng': lng,
          'status': status,
          'is_mock': isMock,
          'verify_token': ?verifyToken,
        },
        queryParameters: {'phone': phone},
        options: Options(validateStatus: (s) => s != null && s < 600),
      );
      _logResponse(response, sw);
      if (response.data is Map) {
        return CheckLocationModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(
        AppErrorFormatter.fromStatusCode(response.statusCode),
      );
    } on DioException catch (e) {
      _logError(e, sw);
      throw ServerException(AppErrorFormatter.toUzbek(e));
    }
  }

  String _periodEndpoint(String period) {
    switch (period) {
      case 'day':
        return ApiConstants.attendanceDay;
      case 'week':
        return ApiConstants.attendanceWeek;
      case 'month':
        return ApiConstants.attendanceMonth;
      case 'year':
        return ApiConstants.attendanceYear;
      default:
        return ApiConstants.attendanceWeek;
    }
  }
}
