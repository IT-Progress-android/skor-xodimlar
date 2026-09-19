import 'package:dio/dio.dart';
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
    try {
      final response = await dio.get(
        ApiConstants.attendanceDay,
        queryParameters: {'phone': phone},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      if (response.data is Map) {
        return TodayAttendanceModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(
        AppErrorFormatter.fromStatusCode(response.statusCode),
      );
    } on DioException catch (e) {
      throw ServerException(AppErrorFormatter.toUzbek(e));
    }
  }

  @override
  Future<List<AttendanceReportModel>> getPeriodAttendance(
    String phone,
    String period,
  ) async {
    try {
      final endpoint = _periodEndpoint(period);

      final response = await dio.post(
        endpoint,
        data: {'phone': phone},
        queryParameters: {'phone': phone},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 600,
        ),
      );

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
      throw ServerException(AppErrorFormatter.toUzbek(e));
    } catch (e) {
      if (e is ServerException) rethrow;
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
      if (response.data is Map) {
        return CheckLocationModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(
        AppErrorFormatter.fromStatusCode(response.statusCode),
      );
    } on DioException catch (e) {
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
