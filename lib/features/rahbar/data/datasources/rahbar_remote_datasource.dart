import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/utils/dio_retry_helper.dart';
import 'package:skore_hodimlar/features/rahbar/data/location_outage.dart';
import 'package:skore_hodimlar/features/rahbar/data/models/rahbar_model.dart';
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';

abstract class RahbarRemoteDataSource {
  Future<RahbarUserModel> login(String login, String password);
  Future<RahbarDashboardModel> getDashboard({String? date});
  Future<List<RahbarStaffAttendanceModel>> getKundalik({String? date});

  /// [davr]: `hafta` | `oy` | `yil`; [sana] — shu davr ichidagi kun.
  Future<RahbarPayrollReport> getPayroll({String davr = 'oy', String? sana});
  Future<PayrollSettings> getPayrollSettings();

  /// Javobdagi `amal_qilish_sanasi` (YYYY-MM-DD) yoki `null`.
  Future<String?> savePayrollSettings(PayrollSettings settings);

  /// Bitta xodim ([xodimIds] bitta element) yoki bir nechtasi/hammasi
  /// ([hammasi]) uchun to'lov turi, stavka va jarima kalitini saqlaydi.
  /// Javobdagi sanalar: `amal` — stavka/to'lov turi qachondan (keyingi oy),
  /// `jarima` — jarima sozlamasi qachondan (odatda darhol). Ommaviy
  /// saqlashda bo'lmasligi mumkin.
  Future<({String? amal, String? jarima})> saveStaffPayRule({
    List<int> xodimIds,
    bool hammasi,
    String? tolovTuri,
    double? stavka,
    bool? jarimaYoqilgan,
    double? jarimaSummaShaxsiy,
    bool? qoshimchaTolanadi,
    double? qoshimchaStavka,
    String? birinchiQoidaBoshlanishi,
  });

  /// Xodim davr ichida qaysi kunlari qancha qo'shimcha ishlagani.
  Future<List<OvertimeDay>> getOvertimeDays({
    required int xodimId,
    required String davr,
    String? sana,
  });
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

  /// [from] (ISO-8601, offset bilan) — faqat shu vaqtdan keyingi nuqtalar
  /// (xarita ochiq paytida yangi nuqtalarni olish uchun).
  Future<Map<String, dynamic>> getStaffLocationHistory({
    required int xodimId,
    String? sana,
    String? from,
  });

  /// Ish vaqtidagi to'xtash joylari. `null` — backend bu endpointni hali
  /// qo'llamaydi (ilova GPS tarixidan o'zi hisoblaydi).
  Future<List<StaffStop>?> getStaffStops({required int xodimId, String? sana});

  /// Backend yo'lga moslagan (map matching) marshrut. `null` — backend
  /// bu endpointni hali qo'llamaydi (ilova real nuqtalarni chizadi).
  Future<MatchedRoute?> getStaffMatchedRoute({
    required int xodimId,
    String? sana,
  });

  /// Ish vaqtidagi lokatsiya uzilishlari. `null` — backend bu endpointni
  /// hali qo'llamaydi.
  Future<List<LocationOutage>?> getLocationOutages({
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
  Future<RahbarPayrollReport> getPayroll({
    String davr = 'oy',
    String? sana,
  }) async {
    final day = sana ?? DateTime.now().toIso8601String().substring(0, 10);
    return DioRetryHelper.withRetry(() async {
      final res = await dioClient.dio.get(
        ApiConstants.rahbarBugalteriya,
        queryParameters: {'davr': davr, 'sana': day},
        options: Options(
          headers: _authHeaders,
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      // Yangi endpoint hali yo'q bo'lsa — eski oylik hisobot.
      if (res.statusCode == 404 || res.statusCode == 405) {
        return RahbarPayrollReport(
          davr: 'oy',
          items: await _withFilials(
            await _getLegacyPayroll(day.substring(0, 7)),
          ),
        );
      }
      if (res.statusCode == 401) {
        throw Exception('Sessiya tugadi. Qaytadan kiring.');
      }
      if ((res.statusCode ?? 500) >= 400) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
        );
      }
      final data = res.data;
      return RahbarPayrollReport(
        davr: (data is Map ? data['davr'] : null)?.toString() ?? davr,
        from: data is Map ? data['from']?.toString() : null,
        to: data is Map ? data['to']?.toString() : null,
        items: await _withFilials(_parsePayrollList(data)),
      );
    });
  }

  /// Backend bugalteriya javobida filial bermasa — filial hisobotidan
  /// (`filiallar[].xodimlar[]`, xaritadagi kabi) ID yoki ism bo'yicha
  /// to'ldiriladi. `is_unassigned` filialdagilar — filialsiz.
  Future<List<RahbarPayrollItemModel>> _withFilials(
    List<RahbarPayrollItemModel> items,
  ) async {
    if (items.isEmpty || items.any((e) => e.filialKey != null)) return items;
    try {
      final report = await getFilial();
      final byId = <int, (int?, String?)>{};
      final byName = <String, (int?, String?)>{};
      for (final f in (report['filiallar'] as List?) ?? const []) {
        if (f is! Map) continue;
        final unassigned = f['is_unassigned'] == true;
        final id = int.tryParse('${f['id'] ?? f['filial_id'] ?? ''}');
        final nom = (f['nom'] ?? f['name'])?.toString().trim();
        final ref = unassigned ? (null, null) : (id, nom);
        for (final x in (f['xodimlar'] as List?) ?? const []) {
          if (x is! Map) continue;
          final xId = int.tryParse('${x['id'] ?? ''}');
          if (xId != null && xId > 0) byId[xId] = ref;
          final xName = (x['name'] ?? x['xodim'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (xName.isNotEmpty) byName[xName] = ref;
        }
      }
      return [
        for (final e in items)
          if (byId[e.id] ?? byName[e.name.trim().toLowerCase()] case (
            final id,
            final nom,
          ))
            e.withFilial(id, nom)
          else
            e,
      ];
    } catch (_) {
      return items;
    }
  }

  Future<List<RahbarPayrollItemModel>> _getLegacyPayroll(String month) async {
    final res = await dioClient.dio.get(
      ApiConstants.rahbarBugalteriyaOylik,
      queryParameters: {'oy': month},
      options: Options(headers: _authHeaders),
    );
    return _parsePayrollList(res.data);
  }

  List<RahbarPayrollItemModel> _parsePayrollList(dynamic data) {
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
  }

  @override
  Future<List<OvertimeDay>> getOvertimeDays({
    required int xodimId,
    required String davr,
    String? sana,
  }) async {
    final data = await _getMap(
      '${ApiConstants.rahbarBugalteriyaXodim}/$xodimId/qoshimcha',
      {'davr': davr, 'sana': ?sana},
    );
    final raw = data['kunlar'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => OvertimeDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<PayrollSettings> getPayrollSettings() async {
    final data = await _getMap(ApiConstants.rahbarBugalteriyaSozlamalar, null);
    final inner = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    return PayrollSettings.fromJson(inner);
  }

  @override
  Future<String?> savePayrollSettings(PayrollSettings settings) async {
    final res = await DioRetryHelper.withRetry(
      () => dioClient.dio.put(
        ApiConstants.rahbarBugalteriyaSozlamalar,
        data: settings.toJson(),
        options: Options(headers: _authHeaders),
      ),
    );
    return _effectiveDate(res.data);
  }

  String? _effectiveDate(dynamic data, {String key = 'amal_qilish_sanasi'}) {
    final v = data is Map ? data[key]?.toString() : null;
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<({String? amal, String? jarima})> saveStaffPayRule({
    List<int> xodimIds = const [],
    bool hammasi = false,
    String? tolovTuri,
    double? stavka,
    bool? jarimaYoqilgan,
    double? jarimaSummaShaxsiy,
    bool? qoshimchaTolanadi,
    double? qoshimchaStavka,
    String? birinchiQoidaBoshlanishi,
  }) async {
    final body = <String, dynamic>{
      'tolov_turi': ?tolovTuri,
      'stavka': ?stavka,
      'jarima_yoqilgan': ?jarimaYoqilgan,
      // 0 — umumiy summaga qaytarish.
      'jarima_summa_shaxsiy': ?jarimaSummaShaxsiy,
      'qoshimcha_tolanadi': ?qoshimchaTolanadi,
      'qoshimcha_stavka': ?qoshimchaStavka,
      'birinchi_qoida_boshlanishi': ?birinchiQoidaBoshlanishi,
    };
    final res = await DioRetryHelper.withRetry(() {
      if (!hammasi && xodimIds.length == 1) {
        return dioClient.dio.put(
          '${ApiConstants.rahbarBugalteriyaXodim}/${xodimIds.first}',
          data: body,
          options: Options(headers: _authHeaders),
        );
      }
      return dioClient.dio.post(
        ApiConstants.rahbarBugalteriyaOmmaviy,
        data: {
          ...body,
          if (hammasi) 'hammasi': true else 'xodim_ids': xodimIds,
        },
        options: Options(headers: _authHeaders),
      );
    });
    return (
      amal: _effectiveDate(res.data),
      jarima: _effectiveDate(res.data, key: 'jarima_amal_sanasi'),
    );
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
    String? from,
  }) {
    final querySana = sana ?? DateTime.now().toIso8601String().substring(0, 10);
    if (from == null) {
      debugPrint(
        '🌐 [API REQ] GET ${ApiConstants.baseUrl}${ApiConstants.rahbarLokatsiyaTarix}/$xodimId?sana=$querySana',
      );
    }
    return _getMap('${ApiConstants.rahbarLokatsiyaTarix}/$xodimId', {
      'sana': querySana,
      'date': querySana,
      'from': ?from,
    });
  }

  @override
  Future<List<StaffStop>?> getStaffStops({
    required int xodimId,
    String? sana,
  }) async {
    final day = sana ?? DateTime.now().toIso8601String().substring(0, 10);
    final data = await _getMap(
      '${ApiConstants.rahbarLokatsiyaToxtashlar}/$xodimId',
      {'sana': day},
    );
    final raw = data['toxtashlar'];
    if (raw is! List) return null;
    final date = DateTime.tryParse(day);
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => StaffStop.fromJson(Map<String, dynamic>.from(e), day: date))
        .whereType<StaffStop>()
        .toList()
      ..sort((a, b) => a.from.compareTo(b.from));
  }

  @override
  Future<MatchedRoute?> getStaffMatchedRoute({
    required int xodimId,
    String? sana,
  }) async {
    final day = sana ?? DateTime.now().toIso8601String().substring(0, 10);
    final data = await _getMap(
      '${ApiConstants.rahbarLokatsiyaMarshrut}/$xodimId',
      {'sana': day},
    );
    return parseMatchedRouteFull(data, day: DateTime.tryParse(day));
  }

  @override
  Future<List<LocationOutage>?> getLocationOutages({
    required int xodimId,
    String? sana,
  }) async {
    final day = sana ?? DateTime.now().toIso8601String().substring(0, 10);
    final data = await _getMap(
      '${ApiConstants.rahbarLokatsiyaUzilishlar}/$xodimId',
      {'sana': day},
    );
    return parseLocationOutages(data);
  }

  @override
  Future<List<Map<String, dynamic>>> getLocations() async {
    return DioRetryHelper.withRetry(() async {
      // Filiallar (geofence: markaz + radius) — `GET /rahbar/lokatsiya`
      // javobidagi `filiallar` (MOBIL_UCHUN_XODIM_XARITASI.md, 2-bo'lim).
      try {
        final data = await _getMap(ApiConstants.rahbarLokatsiya, null);
        if (data['filiallar'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['filiallar'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
        }
      } catch (_) {}

      try {
        final data = await _getMap(ApiConstants.rahbarHisobotFilial, null);
        if (data['filiallar'] is List) {
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

      // `GET /rahbar/lokatsiya/live` (MOBIL_UCHUN_XODIM_XARITASI.md, 3-bo'lim).
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

      return [];
    });
  }

  /// Xarita har yangilanganda butun ro'yxatni yozadi va boshqa loglarni
  /// (masalan `[TOPSHIRIQ API]`) ko'mib yuboradi. Kerak bo'lganda `true`
  /// qiling.
  static const bool _logLiveLocations = false;

  void _logRahbarLiveLocations(List<Map<String, dynamic>> items) {
    if (!_logLiveLocations) return;
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
