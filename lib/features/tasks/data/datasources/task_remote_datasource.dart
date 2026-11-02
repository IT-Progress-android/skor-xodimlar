import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/utils/dio_retry_helper.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';

/// Server `{"status": "error"}` yoki 4xx qaytarganda tashlanadi. [statusCode]
/// orqali UI 409/410 kabi holatlarni ajratib, ro'yxatni yangilay oladi.
class TaskApiException implements Exception {
  final String message;
  final int? statusCode;
  const TaskApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Topshiriqlar moduli API'si (TOPSHIRIQLAR_TZ_BACKEND.md).
abstract class TaskRemoteDataSource {
  // --- Xodim ---
  Future<Paged<StaffTask>> getMyTasks({required String holat, int page = 1});
  Future<StaffTask> getMyTask(int id);
  Future<StaffTask> markDone(int id, {String? comment});
  Future<int> getMyActiveCount();

  // --- Rahbar ---
  Future<Paged<RahbarTaskSummary>> getTasks({
    String? holat,
    String? qidiruv,
    int page = 1,
  });
  Future<RahbarTaskDetail> getTask(int id);
  Future<int> createTask({
    required String title,
    String? description,
    required List<int> staffIds,
    required DateTime deadline,
  });
  Future<void> updateTask(
    int id, {
    String? title,
    String? description,
    DateTime? deadline,
  });
  Future<void> cancelTask(int id);
  Future<void> addHelpers(int id, List<int> staffIds, {DateTime? muddat});
  Future<void> setStaffDeadline(int id, int staffId, DateTime muddat);
  Future<void> transfer(
    int id,
    int staffId, {
    required int yangiStaffId,
    String? izoh,
    DateTime? muddat,
  });
  Future<void> returnTask(
    int id,
    int staffId, {
    required String izoh,
    DateTime? yangiMuddat,
  });
  Future<void> removeStaff(int id, int staffId);

  Future<TaskStatsResult> getStats({
    required TaskPeriod davr,
    required DateTime sana,
    String filtr = 'hammasi',
    String saralash = 'bajarish_foizi',
    String tartib = 'desc',
    int page = 1,
  });
  Future<List<TaskDynamicsPoint>> getDynamics({
    required TaskPeriod davr,
    required DateTime sana,
    int? staffId,
  });
  Future<StaffTaskHistory> getStaffHistory(
    int staffId, {
    required TaskPeriod davr,
    required DateTime sana,
    String holat = 'hammasi',
    int page = 1,
  });

  /// Topshiriq berish uchun xodimlar ro'yxati (mavjud kundalik hisobotdan).
  Future<List<PickableStaff>> getPickableStaff();

  /// Filiallar va xodimlarning filiali (5 daqiqa keshlanadi).
  Future<FilialDirectory> getFilialDirectory();

  Future<void> registerRahbarFcmToken({
    required String token,
    required String deviceType,
    String? deviceId,
  });
  Future<void> deleteRahbarFcmToken(String token);
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final DioClient dioClient;
  final SharedPreferences sharedPreferences;
  final RahbarRemoteDataSource rahbarRemoteDataSource;

  TaskRemoteDataSourceImpl({
    required this.dioClient,
    required this.sharedPreferences,
    required this.rahbarRemoteDataSource,
  });

  Dio get _dio => dioClient.dio;

  Options get _rahbar {
    final token = sharedPreferences.getString('rahbar_token') ?? '';
    return Options(
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      validateStatus: (s) => s != null && s < 600,
    );
  }

  Options get _staff => Options(validateStatus: (s) => s != null && s < 600);

  static String _iso(DateTime d) {
    final local = d.toLocal();
    final off = local.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final h = off.inHours.abs().toString().padLeft(2, '0');
    final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}'
        'T${two(local.hour)}:${two(local.minute)}:00$sign$h:$m';
  }

  static String _day(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Javobni tekshiradi: xato bo'lsa serverning `message` (yoki birinchi
  /// validatsiya xatosi) bilan [TaskApiException] tashlaydi.
  /// Backendga yuborish uchun to'liq log: `[TOPSHIRIQ API]` bo'yicha
  /// filtrlang (`adb logcat | grep "TOPSHIRIQ API"`). Token yozilmaydi.
  static void _log(String message) {
    final ts = DateTime.now().toIso8601String();
    // debugPrint uzun qatorlarni kesib yubormasligi uchun bo'laklab chiqaramiz.
    const chunk = 800;
    final text = '[TOPSHIRIQ API] $ts $message';
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

  static String _role(Options o) =>
      (o.headers?['Authorization'] != null) ? 'rahbar' : 'xodim';

  static String _hasToken(Options o) {
    final auth = o.headers?['Authorization']?.toString() ?? '';
    if (auth.isEmpty) return 'interceptor';
    return auth.length > 'Bearer '.length ? 'bor' : 'YOQ';
  }

  /// Haqiqatda yuborilgan token (interceptor'dan keyin) — faqat oxirgi
  /// 6 belgi, rahbar/xodim tokeni adashmaganini tekshirish uchun.
  static String _sentToken(RequestOptions req) {
    final auth = req.headers['Authorization']?.toString() ?? '';
    if (auth.length <= 'Bearer '.length) return 'yoq';
    final t = auth.substring('Bearer '.length);
    return '…${t.length > 6 ? t.substring(t.length - 6) : t}';
  }

  void _logResponse(Response<dynamic> res, Stopwatch sw) {
    final req = res.requestOptions;
    _log(
      '<-- ${res.statusCode} ${req.method} ${req.uri} '
      '(${sw.elapsedMilliseconds} ms) yuborilgan_token=${_sentToken(req)} '
      'javob=${_json(res.data)}',
    );
  }

  void _logError(String method, String path, Object e, Stopwatch sw) {
    if (e is DioException) {
      _log(
        'xx  $method ${e.requestOptions.uri} (${sw.elapsedMilliseconds} ms) '
        'dio=${e.type.name} status=${e.response?.statusCode} '
        'xabar=${e.message} javob=${_json(e.response?.data)}',
      );
    } else {
      _log('xx  $method $path (${sw.elapsedMilliseconds} ms) xato=$e');
    }
  }

  Map<String, dynamic> _ok(Response<dynamic> res) {
    final code = res.statusCode ?? 0;
    final data = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
    if (code >= 400 || data['status'] == 'error') {
      String? msg;
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        msg = first is List && first.isNotEmpty
            ? first.first.toString()
            : first?.toString();
      }
      msg ??= data['message']?.toString();
      if (code == 401) {
        msg = AppLocalizations.trStatic('task_err_session');
      }
      _log(
        '!!  ${res.requestOptions.method} ${res.requestOptions.uri} '
        'server xatosi: status=$code ilovada ko\'rsatiladi="${msg ?? '-'}"',
      );
      throw TaskApiException(
        (msg == null || msg.isEmpty)
            ? AppLocalizations.trStatic('task_err_generic')
            : msg,
        code,
      );
    }
    return data;
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) {
    final raw = data[key] ?? data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Options options, [
    Map<String, dynamic>? query,
  ]) {
    return DioRetryHelper.withRetry(() async {
      final sw = Stopwatch()..start();
      _log(
        '--> GET ${ApiConstants.baseUrl}$path rol=${_role(options)} '
        'token=${_hasToken(options)} query=${_json(query)}',
      );
      try {
        final res = await _dio.get(
          path,
          queryParameters: query,
          options: options,
        );
        _logResponse(res, sw);
        return _ok(res);
      } on TaskApiException {
        rethrow;
      } catch (e) {
        _logError('GET', path, e, sw);
        rethrow;
      }
    });
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Options options, [
    Map<String, dynamic>? body,
  ]) async {
    // Yozuvchi so'rovlar qayta urinilmaydi: takroriy yuborish ikki marta
    // amal bajarishi mumkin.
    final sw = Stopwatch()..start();
    _log(
      '--> $method ${ApiConstants.baseUrl}$path rol=${_role(options)} '
      'token=${_hasToken(options)} body=${_json(body)}',
    );
    try {
      final res = await _dio.request(
        path,
        data: body,
        options: options.copyWith(method: method),
      );
      _logResponse(res, sw);
      return _ok(res);
    } on TaskApiException {
      rethrow;
    } catch (e) {
      _logError(method, path, e, sw);
      rethrow;
    }
  }

  // ---------------------------------------------------------------- Xodim

  @override
  Future<Paged<StaffTask>> getMyTasks({
    required String holat,
    int page = 1,
  }) async {
    try {
      final data = await _get(ApiConstants.staffTopshiriq, _staff, {
        'holat': holat,
        'page': page,
        'per_page': 30,
      });
      return Paged(
        _list(data, 'data').map(StaffTask.fromJson).toList(),
        PageMeta.fromJson(data['meta']),
      );
    } on TaskApiException catch (e) {
      if (e.statusCode == 404) {
        return const Paged(
          [],
          PageMeta(page: 1, perPage: 30, total: 0, lastPage: 1),
        );
      }
      rethrow;
    }
  }

  @override
  Future<StaffTask> getMyTask(int id) async {
    final data = await _get('${ApiConstants.staffTopshiriq}/$id', _staff);
    final raw = data['topshiriq'] ?? data['data'] ?? data;
    return StaffTask.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<StaffTask> markDone(int id, {String? comment}) async {
    final data = await _send(
      'POST',
      '${ApiConstants.staffTopshiriq}/$id/bajardim',
      _staff,
      {if (comment != null && comment.trim().isNotEmpty) 'comment': comment},
    );
    final raw = data['topshiriq'];
    if (raw is Map) {
      return StaffTask.fromJson(Map<String, dynamic>.from(raw));
    }
    return getMyTask(id);
  }

  @override
  Future<int> getMyActiveCount() async {
    try {
      final data = await _get(ApiConstants.staffTopshiriqSoni, _staff);
      final v = data['faol'];
      return v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    } on TaskApiException catch (e) {
      if (e.statusCode == 404) return 0;
      rethrow;
    }
  }

  // ---------------------------------------------------------------- Rahbar

  @override
  Future<Paged<RahbarTaskSummary>> getTasks({
    String? holat,
    String? qidiruv,
    int page = 1,
  }) async {
    try {
      final data = await _get(ApiConstants.rahbarTopshiriq, _rahbar, {
        'holat': ?holat,
        if (qidiruv != null && qidiruv.trim().isNotEmpty) 'qidiruv': qidiruv,
        'tartib': 'desc',
        'sort': 'desc',
        'page': page,
        'per_page': 30,
      });
      return Paged(
        _list(data, 'data').map(RahbarTaskSummary.fromJson).toList(),
        PageMeta.fromJson(data['meta']),
      );
    } on TaskApiException catch (e) {
      if (e.statusCode == 404) {
        return const Paged(
          [],
          PageMeta(page: 1, perPage: 30, total: 0, lastPage: 1),
        );
      }
      rethrow;
    }
  }

  @override
  Future<RahbarTaskDetail> getTask(int id) async {
    final data = await _get('${ApiConstants.rahbarTopshiriq}/$id', _rahbar);
    return RahbarTaskDetail.fromJson(data);
  }

  @override
  Future<int> createTask({
    required String title,
    String? description,
    required List<int> staffIds,
    required DateTime deadline,
  }) async {
    final data = await _send('POST', ApiConstants.rahbarTopshiriq, _rahbar, {
      'title': title,
      if (description != null && description.trim().isNotEmpty)
        'description': description,
      'staff_ids': staffIds,
      'deadline': _iso(deadline),
    });
    final t = data['topshiriq'];
    final id = t is Map ? t['id'] : null;
    return id is num ? id.toInt() : int.tryParse('$id') ?? 0;
  }

  @override
  Future<void> updateTask(
    int id, {
    String? title,
    String? description,
    DateTime? deadline,
  }) async {
    await _send('PATCH', '${ApiConstants.rahbarTopshiriq}/$id', _rahbar, {
      'title': ?title,
      'description': ?description,
      if (deadline != null) 'deadline': _iso(deadline),
    });
  }

  @override
  Future<void> cancelTask(int id) async {
    await _send('POST', '${ApiConstants.rahbarTopshiriq}/$id/bekor', _rahbar);
  }

  @override
  Future<void> addHelpers(
    int id,
    List<int> staffIds, {
    DateTime? muddat,
  }) async {
    await _send('POST', '${ApiConstants.rahbarTopshiriq}/$id/xodim', _rahbar, {
      'staff_ids': staffIds,
      'muddat': muddat == null ? null : _iso(muddat),
    });
  }

  @override
  Future<void> setStaffDeadline(int id, int staffId, DateTime muddat) async {
    await _send(
      'PATCH',
      '${ApiConstants.rahbarTopshiriq}/$id/xodim/$staffId',
      _rahbar,
      {'muddat': _iso(muddat)},
    );
  }

  @override
  Future<void> transfer(
    int id,
    int staffId, {
    required int yangiStaffId,
    String? izoh,
    DateTime? muddat,
  }) async {
    await _send(
      'POST',
      '${ApiConstants.rahbarTopshiriq}/$id/xodim/$staffId/otkaz',
      _rahbar,
      {
        'yangi_staff_id': yangiStaffId,
        if (izoh != null && izoh.trim().isNotEmpty) 'izoh': izoh,
        if (muddat != null) 'muddat': _iso(muddat),
      },
    );
  }

  @override
  Future<void> returnTask(
    int id,
    int staffId, {
    required String izoh,
    DateTime? yangiMuddat,
  }) async {
    await _send(
      'POST',
      '${ApiConstants.rahbarTopshiriq}/$id/xodim/$staffId/qaytar',
      _rahbar,
      {
        'izoh': izoh,
        if (yangiMuddat != null) 'yangi_muddat': _iso(yangiMuddat),
      },
    );
  }

  @override
  Future<void> removeStaff(int id, int staffId) async {
    await _send(
      'DELETE',
      '${ApiConstants.rahbarTopshiriq}/$id/xodim/$staffId',
      _rahbar,
    );
  }

  @override
  Future<TaskStatsResult> getStats({
    required TaskPeriod davr,
    required DateTime sana,
    String filtr = 'hammasi',
    String saralash = 'bajarish_foizi',
    String tartib = 'desc',
    int page = 1,
  }) async {
    try {
      final data = await _get(ApiConstants.rahbarTopshiriqStatistika, _rahbar, {
        'davr': davr.name,
        'sana': _day(sana),
        'filtr': filtr,
        'saralash': saralash,
        'tartib': tartib,
        'page': page,
        'per_page': 50,
      });
      return TaskStatsResult(
        davr: TaskPeriodRange.fromJson(data['davr']),
        jami: TaskCounters.fromJson(data['jami']),
        xodimlar: _list(data, 'data').map(TaskStaffStat.fromJson).toList(),
        meta: PageMeta.fromJson(data['meta']),
      );
    } on TaskApiException catch (e) {
      if (e.statusCode == 404) {
        return const TaskStatsResult(
          davr: TaskPeriodRange(),
          jami: TaskCounters(),
          xodimlar: [],
          meta: PageMeta(page: 1, perPage: 50, total: 0, lastPage: 1),
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<TaskDynamicsPoint>> getDynamics({
    required TaskPeriod davr,
    required DateTime sana,
    int? staffId,
  }) async {
    try {
      final data = await _get(ApiConstants.rahbarTopshiriqDinamika, _rahbar, {
        'davr': davr.name,
        'sana': _day(sana),
        'staff_id': ?staffId,
      });
      return _list(data, 'nuqtalar').map(TaskDynamicsPoint.fromJson).toList();
    } on TaskApiException catch (e) {
      if (e.statusCode == 404) {
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<StaffTaskHistory> getStaffHistory(
    int staffId, {
    required TaskPeriod davr,
    required DateTime sana,
    String holat = 'hammasi',
    int page = 1,
  }) async {
    try {
      final data = await _get(
        '${ApiConstants.rahbarTopshiriq}/xodim/$staffId',
        _rahbar,
        {
          'davr': davr.name,
          'sana': _day(sana),
          'holat': holat,
          'page': page,
          'per_page': 30,
        },
      );
      final countersRaw = data['korsatkichlar'] ?? data['statistika'] ?? data;
      return StaffTaskHistory(
        TaskCounters.fromJson(countersRaw),
        _list(data, 'topshiriqlar').map(StaffTaskHistoryItem.fromJson).toList(),
        PageMeta.fromJson(data['meta']),
      );
    } on TaskApiException catch (e) {
      if (e.statusCode == 404) {
        return const StaffTaskHistory(
          TaskCounters(),
          [],
          PageMeta(page: 1, perPage: 30, total: 0, lastPage: 1),
        );
      }
      rethrow;
    }
  }

  FilialDirectory? _filialDir;
  DateTime? _filialDirAt;

  @override
  Future<FilialDirectory> getFilialDirectory() async {
    final at = _filialDirAt;
    if (_filialDir != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 5)) {
      return _filialDir!;
    }
    try {
      final dir = FilialDirectory.fromJson(
        await rahbarRemoteDataSource.getFilial(),
      );
      _filialDir = dir;
      _filialDirAt = DateTime.now();
      return dir;
    } catch (_) {
      return _filialDir ?? const FilialDirectory();
    }
  }

  @override
  Future<List<PickableStaff>> getPickableStaff() async {
    _log('--> xodimlar ro\'yxati: GET ${ApiConstants.rahbarHisobotKundalik}');
    final dirFuture = getFilialDirectory();
    final list = await rahbarRemoteDataSource.getKundalik();
    final dir = await dirFuture;
    _log('<-- xodimlar ro\'yxati: ${list.length} ta yozuv');
    final seen = <int>{};
    final result = <PickableStaff>[];
    for (final s in list) {
      if (s.id <= 0 || !seen.add(s.id)) continue;
      final filial = dir.staffFilial[s.id] ?? s.filialName?.trim();
      final parts = [
        if (s.lavozim.trim().isNotEmpty) s.lavozim.trim(),
        if ((filial ?? '').isNotEmpty) filial!,
      ];
      result.add(
        PickableStaff(
          id: s.id,
          name: s.name,
          subtitle: parts.isEmpty ? null : parts.join(' · '),
          photo: s.photo,
          filial: filial,
        ),
      );
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  @override
  Future<void> registerRahbarFcmToken({
    required String token,
    required String deviceType,
    String? deviceId,
  }) async {
    await _send('POST', ApiConstants.rahbarFcmToken, _rahbar, {
      'fcm_token': token,
      'device_type': deviceType,
      'device_id': ?deviceId,
    });
  }

  @override
  Future<void> deleteRahbarFcmToken(String token) async {
    await _send('DELETE', ApiConstants.rahbarFcmToken, _rahbar, {
      'fcm_token': token,
    });
  }
}
