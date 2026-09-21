import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/utils/dio_retry_helper.dart';
import 'package:skore_hodimlar/features/rahbar/data/models/rahbar_model.dart';

abstract class RahbarRemoteDataSource {
  Future<RahbarUserModel> login(String login, String password);
  Future<RahbarDashboardModel> getDashboard({String? date});
  Future<List<RahbarStaffAttendanceModel>> getKundalik({String? date});
  Future<List<RahbarPayrollItemModel>> getPayroll({String? month});
  Future<List<RahbarArizaModel>> getArizalar();
  Future<bool> reviewAriza(int arizaId, String action, {String? comment});

  Future<Map<String, dynamic>> getXodimlarReport({
    String? from,
    String? to,
    int? bolimId,
  });
  Future<Map<String, dynamic>> getFilial({String? sana});
  Future<List<Map<String, dynamic>>> getLocations();
  Future<Map<String, dynamic>> addBranchLocation({
    required String nom,
    required double lat,
    required double lng,
    required int radius,
  });
  Future<Map<String, dynamic>> getKunlik({String? from, String? to});
  Future<Map<String, dynamic>> getQoldiruvchilar({int engKam});
  Future<List<Map<String, dynamic>>> getLiveLocations({
    int? filialId,
    int? bolimId,
    String? holat,
  });
  Future<Map<String, dynamic>> getStaffLocationHistory({
    required int xodimId,
    String? sana,
  });
}

class RahbarRemoteDataSourceImpl implements RahbarRemoteDataSource {
  final DioClient dioClient;
  final SharedPreferences sharedPreferences;

  RahbarRemoteDataSourceImpl({
    required this.dioClient,
    required this.sharedPreferences,
  });

  Map<String, String> get _authHeaders {
    final token = sharedPreferences.getString('rahbar_token') ?? '';
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  @override
  Future<RahbarUserModel> login(String login, String password) async {
    return DioRetryHelper.withRetry(() async {
      final res = await dioClient.dio.post(
        ApiConstants.rahbarLogin,
        data: {'login': login, 'password': password},
      );
      final data = res.data as Map<String, dynamic>;
      final token = (data['token'] ?? data['access_token'] ?? '').toString();
      await sharedPreferences.setString('rahbar_token', token);
      await sharedPreferences.setString('user_role', 'admin');
      return RahbarUserModel.fromJson(data, token);
    });
  }

  /// PDF §1.1 — Calling /rahbar/bosh (single endpoint for profil + hisob + arizalar)
  @override
  Future<RahbarDashboardModel> getDashboard({String? date}) async {
    return DioRetryHelper.withRetry(() async {
      final qParams = <String, dynamic>{};
      if (date != null && date.isNotEmpty) {
        qParams['sana'] = date;
        qParams['date'] = date;
      }
      try {
        final res = await dioClient.dio.get(
          ApiConstants.rahbarBosh,
          queryParameters: qParams.isNotEmpty ? qParams : null,
          options: Options(headers: _authHeaders),
        );
        if (res.data is Map) {
          final mapData = Map<String, dynamic>.from(res.data as Map);
          if (mapData.isNotEmpty &&
              (mapData['hisob'] != null || mapData['status'] == 'ok')) {
            return RahbarDashboardModel.fromJson(mapData);
          }
        }
      } catch (_) {
        // Fallback to legacy dashboard endpoint if /rahbar/bosh is not available
      }

      final res = await dioClient.dio.get(
        ApiConstants.rahbarDashboard,
        queryParameters: qParams.isNotEmpty ? qParams : null,
        options: Options(headers: _authHeaders),
      );
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      return RahbarDashboardModel.fromJson(data);
    });
  }

  @override
  Future<List<RahbarStaffAttendanceModel>> getKundalik({String? date}) async {
    return DioRetryHelper.withRetry(() async {
      final qParams = <String, dynamic>{};
      if (date != null && date.isNotEmpty) {
        qParams['sana'] = date;
        qParams['date'] = date;
        qParams['kun'] = date;
        qParams['day'] = date;
        qParams['from'] = date;
        qParams['to'] = date;
      }
      final res = await dioClient.dio.get(
        ApiConstants.rahbarHisobotKundalik,
        queryParameters: qParams.isNotEmpty ? qParams : null,
        options: Options(headers: _authHeaders),
      );
      final data = res.data;
      List<dynamic> rawList = <dynamic>[];
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList =
            (data['xodimlar'] ??
                    data['reports'] ??
                    data['data'] ??
                    data['attendance'] ??
                    data['items'] ??
                    data['davomat'] ??
                    const <dynamic>[])
                as List<dynamic>;
      }
      return rawList
          .map(
            (e) => RahbarStaffAttendanceModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    });
  }

  @override
  Future<List<RahbarPayrollItemModel>> getPayroll({String? month}) async {
    return DioRetryHelper.withRetry(() async {
      final res = await dioClient.dio.get(
        ApiConstants.rahbarBugalteriyaOylik,
        queryParameters: month != null ? {'oy': month} : null,
        options: Options(headers: _authHeaders),
      );
      final data = res.data;
      List<dynamic> rawList = <dynamic>[];
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList =
            (data['xodimlar'] ??
                    data['payroll'] ??
                    data['data'] ??
                    const <dynamic>[])
                as List<dynamic>;
      }
      return rawList
          .map(
            (e) => RahbarPayrollItemModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    });
  }

  @override
  Future<List<RahbarArizaModel>> getArizalar() async {
    return DioRetryHelper.withRetry(() async {
      final res = await dioClient.dio.get(
        ApiConstants.rahbarArizalar,
        options: Options(headers: _authHeaders),
      );
      final data = res.data;
      List<dynamic> rawList = <dynamic>[];
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList =
            (data['arizalar'] ?? data['data'] ?? const <dynamic>[])
                as List<dynamic>;
      }
      return rawList
          .map(
            (e) =>
                RahbarArizaModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });
  }

  @override
  Future<bool> reviewAriza(
    int arizaId,
    String action, {
    String? comment,
  }) async {
    return DioRetryHelper.withRetry(() async {
      final endpoint = action == 'approve'
          ? '${ApiConstants.rahbarArizalar}/$arizaId/tasdiqla'
          : '${ApiConstants.rahbarArizalar}/$arizaId/rad';
      final res = await dioClient.dio.post(
        endpoint,
        data: comment != null ? {'izoh': comment} : null,
        options: Options(headers: _authHeaders),
      );
      return res.data['status'] == 'ok' || res.statusCode == 200;
    });
  }

  Future<Map<String, dynamic>> _getMap(
    String endpoint,
    Map<String, dynamic>? query,
  ) async {
    return DioRetryHelper.withRetry(() async {
      final res = await dioClient.dio.get(
        endpoint,
        queryParameters: (query != null && query.isNotEmpty) ? query : null,
        options: Options(
          headers: _authHeaders,
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      if (res.statusCode == 401) {
        throw Exception('Sessiya tugadi. Qaytadan kiring.');
      }
      if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
      return <String, dynamic>{};
    });
  }

  @override
  Future<Map<String, dynamic>> getXodimlarReport({
    String? from,
    String? to,
    int? bolimId,
  }) {
    return _getMap(ApiConstants.rahbarHisobotXodimlar, {
      'from': ?from,
      'to': ?to,
      'bolim_id': ?bolimId,
    });
  }

  @override
  Future<Map<String, dynamic>> getFilial({String? sana}) {
    return _getMap(ApiConstants.rahbarHisobotFilial, {
      if (sana != null) ...{'sana': sana, 'date': sana},
    });
  }

  @override
  Future<Map<String, dynamic>> getStaffLocationHistory({
    required int xodimId,
    String? sana,
  }) {
    return _getMap('${ApiConstants.rahbarLokatsiyaTarix}/$xodimId', {
      'sana': ?sana,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getLocations() async {
    return DioRetryHelper.withRetry(() async {
      try {
        final res = await dioClient.dio.get(
          '/rahbar/locations',
          options: Options(headers: _authHeaders),
        );
        final data = res.data;
        if (data is Map && data['data'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['data'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      } catch (_) {}

      try {
        final res = await dioClient.dio.get(
          ApiConstants.rahbarHisobotFilial,
          options: Options(headers: _authHeaders),
        );
        final data = res.data;
        if (data is Map && data['filiallar'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['filiallar'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
        }
      } catch (_) {}

      return [];
    });
  }

  @override
  Future<Map<String, dynamic>> addBranchLocation({
    required String nom,
    required double lat,
    required double lng,
    required int radius,
  }) async {
    return DioRetryHelper.withRetry(() async {
      final res = await dioClient.dio.post(
        ApiConstants.rahbarFilialCrud,
        data: {'nom': nom, 'lat': lat, 'lng': lng, 'radius': radius},
        options: Options(headers: _authHeaders),
      );
      if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
      return {'status': 'ok'};
    });
  }

  @override
  Future<Map<String, dynamic>> getKunlik({String? from, String? to}) {
    return _getMap(ApiConstants.rahbarHisobotKunlik, {
      'from': ?from,
      'to': ?to,
    });
  }

  @override
  Future<Map<String, dynamic>> getQoldiruvchilar({int engKam = 1}) {
    return _getMap(ApiConstants.rahbarHisobotQoldiruvchilar, {
      'eng_kam': engKam,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getLiveLocations({
    int? filialId,
    int? bolimId,
    String? holat,
  }) async {
    return DioRetryHelper.withRetry(() async {
      final query = {
        'filial_id': ?filialId,
        'bolim_id': ?bolimId,
        'holat': ?holat,
      };

      // 1. Try primary endpoint: /api/rahbar/lokatsiya/live
      try {
        final res = await dioClient.dio.get(
          ApiConstants.rahbarLokatsiyaLive,
          queryParameters: query,
          options: Options(
            headers: _authHeaders,
            validateStatus: (s) => s != null && s < 600,
          ),
        );

        if (res.statusCode == 200) {
          final data = res.data;
          List<dynamic>? rawList;
          if (data is Map && data['items'] is List) {
            rawList = data['items'] as List;
          } else if (data is Map && data['data'] is List) {
            rawList = data['data'] as List;
          } else if (data is List) {
            rawList = data;
          }
          if (rawList != null) {
            final parsed = List<Map<String, dynamic>>.from(
              rawList.map((e) => Map<String, dynamic>.from(e as Map)),
            );
            _logRahbarLiveLocations(parsed);
            return parsed;
          }
        }
      } catch (_) {}

      // 2. Fallback endpoint per BACKEND_TZ.md: /api/rahbar/staff/live-locations
      try {
        const fallbackUrl = '/rahbar/staff/live-locations';
        final res = await dioClient.dio.get(
          fallbackUrl,
          queryParameters: query,
          options: Options(
            headers: _authHeaders,
            validateStatus: (s) => s != null && s < 600,
          ),
        );

        if (res.statusCode == 200) {
          final data = res.data;
          List<dynamic>? rawList;
          if (data is Map && data['data'] is List) {
            rawList = data['data'] as List;
          } else if (data is Map && data['items'] is List) {
            rawList = data['items'] as List;
          } else if (data is List) {
            rawList = data;
          }
          if (rawList != null) {
            final parsed = List<Map<String, dynamic>>.from(
              rawList.map((e) => Map<String, dynamic>.from(e as Map)),
            );
            _logRahbarLiveLocations(parsed);
            return parsed;
          }
        }
      } catch (_) {}

      return [];
    });
  }

  void _logRahbarLiveLocations(List<Map<String, dynamic>> items) {
    final nowStr = DateTime.now().toString().substring(11, 19);
    final withCoords = items.where((item) {
      final lat =
          item['lat'] ??
          (item['location'] is Map ? item['location']['latitude'] : null);
      final lng =
          item['lng'] ??
          (item['location'] is Map ? item['location']['longitude'] : null);
      return lat != null && lng != null && lat != 0 && lng != 0;
    }).toList();

    debugPrint(
      '📍 [RAHBAR REALTIME] Xodimlar lokatsiyasi yangilandi ($nowStr) — Jami: ${items.length}, Joylashuvi aniq: ${withCoords.length}:',
    );
    for (final item in withCoords) {
      final name = item['name'] ?? item['full_name'] ?? 'Xodim';
      final lat =
          item['lat'] ??
          (item['location'] is Map ? item['location']['latitude'] : null);
      final lng =
          item['lng'] ??
          (item['location'] is Map ? item['location']['longitude'] : null);
      final isLive = item['is_live'] == true;
      final holat = item['holat_nomi'] ?? item['holat'] ?? '';
      final time = item['time'] ?? item['vaqt'] ?? '';
      final dist = item['distance_m'] != null ? '${item['distance_m']}m' : '';
      debugPrint(
        '   📍 $name: lat=$lat, lng=$lng | $holat | ${isLive ? "🟢 Jonli" : "⚪ Eskirgan"}${dist.isNotEmpty ? " ($dist)" : ""}${time.toString().isNotEmpty ? " | $time" : ""}',
      );
    }
  }
}
