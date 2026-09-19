import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/errors/exceptions.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/attendance/data/models/geofence_zone_model.dart';

abstract class GeofenceRemoteDataSource {
  Future<List<GeofenceZoneModel>> getGeofenceZones(String phone);
  Future<Map<String, dynamic>> sendLokatsiyaEvent({
    required String phone,
    required String event,
    required int locationId,
    required double lat,
    required double lng,
    double? accuracy,
    bool isMock = false,
    String? wifiBssid,
    String? timestamp,
  });
  Future<bool> reportSecurityIncident({
    required String phone,
    required String type,
    required String details,
    String? deviceModel,
    String? timestamp,
  });
}

class GeofenceRemoteDataSourceImpl implements GeofenceRemoteDataSource {
  final Dio dio;

  GeofenceRemoteDataSourceImpl(this.dio);

  @override
  Future<List<GeofenceZoneModel>> getGeofenceZones(String phone) async {
    try {
      final response = await dio.get(
        ApiConstants.geofenceZones,
        queryParameters: {'phone': phone},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      if (response.data is Map) {
        final map = response.data as Map;
        final data = map['data'] ?? map['zones'];
        if (data is List) {
          return data
              .map(
                (e) => GeofenceZoneModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } else if (response.data is List) {
        return (response.data as List)
            .map(
              (e) => GeofenceZoneModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Geofence zones fetch error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Geofence zones fetch error: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> sendLokatsiyaEvent({
    required String phone,
    required String event,
    required int locationId,
    required double lat,
    required double lng,
    double? accuracy,
    bool isMock = false,
    String? wifiBssid,
    String? timestamp,
  }) async {
    final body = {
      'phone': phone,
      'event': event,
      'location_id': locationId,
      'lat': lat,
      'lng': lng,
      'accuracy': ?accuracy,
      'is_mock': isMock,
      if (wifiBssid != null && wifiBssid.isNotEmpty) 'wifi_bssid': wifiBssid,
      'timestamp': timestamp ?? DateTime.now().toString().substring(0, 19),
    };

    try {
      final response = await dio.post(
        ApiConstants.staffLokatsiyaEvent,
        data: body,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (s) => s != null && s < 600,
          followRedirects: false,
        ),
      );

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'success': response.statusCode == 200};
    } on DioException catch (e) {
      throw ServerException(AppErrorFormatter.toUzbek(e));
    } catch (e) {
      throw ServerException(AppErrorFormatter.toUzbek(e));
    }
  }

  @override
  Future<bool> reportSecurityIncident({
    required String phone,
    required String type,
    required String details,
    String? deviceModel,
    String? timestamp,
  }) async {
    final body = {
      'phone': phone,
      'type': type,
      'details': details,
      'device_model': ?deviceModel,
      'timestamp': timestamp ?? DateTime.now().toString().substring(0, 19),
    };

    try {
      final response = await dio.post(
        ApiConstants.staffSecurityReport,
        data: body,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (s) => s != null && s < 600,
          followRedirects: false,
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Security report error: $e');
      return false;
    }
  }
}
