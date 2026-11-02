import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';

/// Result of probing the network at the moment an API call failed.
@immutable
class NetworkProbe {
  /// Public (external) IP of the network the phone is on, from ipinfo/ipify.
  /// `null` means the internet itself was unreachable.
  final String? publicIp;

  /// Provider / ASN as reported by ipinfo (e.g. "AS8193 Uzbektelekom").
  final String? isp;
  final String? location;

  /// IPs `app.skor.uz` resolved to, or the DNS error.
  final String dns;

  /// Raw TCP connect to the API host on :443 — "ok (84 ms)", "timeout",
  /// "refused"... A firewall (CSF) ban shows up here as timeout/refused
  /// while the rest of the internet works.
  final String tcp;

  /// Plain HTTPS GET to the API base: status code or error.
  final String https;

  const NetworkProbe({
    required this.publicIp,
    required this.isp,
    required this.location,
    required this.dns,
    required this.tcp,
    required this.https,
  });

  bool get internetOk => publicIp != null;
  bool get tcpOk => tcp.startsWith('ok');

  Map<String, dynamic> toJson() => {
    'publicIp': publicIp,
    'isp': isp,
    'location': location,
    'dns': dns,
    'tcp': tcp,
    'https': https,
  };

  factory NetworkProbe.fromJson(Map<String, dynamic> j) => NetworkProbe(
    publicIp: j['publicIp'] as String?,
    isp: j['isp'] as String?,
    location: j['location'] as String?,
    dns: (j['dns'] ?? '-').toString(),
    tcp: (j['tcp'] ?? '-').toString(),
    https: (j['https'] ?? '-').toString(),
  );
}

/// One failed API call together with the network state at that moment —
/// exactly what the hosting support asks for: external IP, exact time and
/// the error the API returned.
@immutable
class NetworkIncident {
  final DateTime time;

  /// "POST /bot/staff/login" — query string stripped (it carries the phone).
  final String endpoint;

  /// Dio error type (connectionTimeout, badResponse...) or "httpStatus".
  final String errorType;
  final int? statusCode;

  /// Error message / start of the response body (firewall pages are HTML).
  final String detail;

  /// CDN info from response headers, e.g. "cloudflare · ray 8c1f…-TAS".
  /// The Ray ID lets the server team find the exact request in Cloudflare.
  final String? edge;
  final NetworkProbe probe;
  final String appVersion;
  final String platform;

  const NetworkIncident({
    required this.time,
    required this.endpoint,
    required this.errorType,
    required this.statusCode,
    required this.detail,
    this.edge,
    required this.probe,
    required this.appVersion,
    required this.platform,
  });

  String get verdict => NetworkDiagnosticsService.verdictFor(
    probe: probe,
    statusCode: statusCode,
    errorType: errorType,
    detail: detail,
    edge: edge,
  );

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'endpoint': endpoint,
    'errorType': errorType,
    'statusCode': statusCode,
    'detail': detail,
    'edge': edge,
    'probe': probe.toJson(),
    'appVersion': appVersion,
    'platform': platform,
  };

  factory NetworkIncident.fromJson(Map<String, dynamic> j) => NetworkIncident(
    time: DateTime.parse(j['time'] as String),
    endpoint: (j['endpoint'] ?? '').toString(),
    errorType: (j['errorType'] ?? '').toString(),
    statusCode: j['statusCode'] as int?,
    detail: (j['detail'] ?? '').toString(),
    edge: j['edge'] as String?,
    probe: NetworkProbe.fromJson(Map<String, dynamic>.from(j['probe'] as Map)),
    appVersion: (j['appVersion'] ?? '').toString(),
    platform: (j['platform'] ?? '').toString(),
  );

  /// Plain-text report to paste to the hosting support. Kept in Uzbek on
  /// purpose — it is read by the (Uzbek-speaking) server team, not the user.
  String toReport() {
    final p = probe;
    String two(int v) => v.toString().padLeft(2, '0');
    final off = time.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final local =
        '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)} '
        '(UTC$sign${two(off.inHours.abs())}:${two(off.inMinutes.abs() % 60)})';
    return [
      '🕒 Vaqt: $local',
      '🕒 UTC: ${time.toUtc().toIso8601String()}',
      '🌐 Tashqi IP: ${p.publicIp ?? "aniqlanmadi (internet yo'q)"}',
      '📶 Provayder: ${p.isp ?? "-"}',
      if (p.location != null) '📍 Joylashuv: ${p.location}',
      '🔗 So\'rov: $endpoint',
      '❌ Xatolik: $errorType'
          '${statusCode != null ? " (HTTP $statusCode)" : ""}',
      if (detail.isNotEmpty) '📝 Javob: $detail',
      if (edge != null) '☁️ CDN: $edge',
      '🧭 DNS app.skor.uz: ${p.dns}',
      '🔌 TCP :443: ${p.tcp}',
      '🔒 HTTPS: ${p.https}',
      '🩺 Xulosa: $verdict',
      '📱 Ilova: v$appVersion | $platform',
    ].join('\n');
  }
}

/// Records failed API calls with enough network context to tell a server-side
/// IP ban apart from a dead internet connection or a backend error.
///
/// Hooked into `DioClient`, so every API call (including login) is covered.
/// Incidents are only stored when they carry signal: plain "no internet"
/// failures are skipped.
class NetworkDiagnosticsService {
  NetworkDiagnosticsService._();
  static final NetworkDiagnosticsService instance =
      NetworkDiagnosticsService._();

  static const String prefKey = 'network_incidents_v1';
  static const int maxIncidents = 20;

  /// Retries and parallel requests fail together — one incident per window.
  static const Duration throttle = Duration(seconds: 20);

  /// Bumps whenever a new incident is stored (UI can listen).
  final ValueNotifier<int> revision = ValueNotifier(0);

  DateTime? _lastRecordedAt;
  bool _recording = false;

  /// Probe implementation; replaceable in tests (real probes need network).
  @visibleForTesting
  Future<NetworkProbe> Function() probeRunner = _runProbe;

  @visibleForTesting
  DateTime Function() now = DateTime.now;

  @visibleForTesting
  void resetForTest() {
    _lastRecordedAt = null;
    _recording = false;
    probeRunner = _runProbe;
    now = DateTime.now;
  }

  /// True if an incident was stored in the last [within] — lets the login
  /// screen offer "details" on its error snackbar.
  bool hasRecentIncident({Duration within = const Duration(seconds: 45)}) {
    final last = _lastRecordedAt;
    return last != null && now().difference(last) <= within;
  }

  // ---- Classification -----------------------------------------------------

  /// Whether a Dio failure is worth diagnosing (network-level or 5xx).
  static bool isDiagnosable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return true;
      case DioExceptionType.badResponse:
        return (e.response?.statusCode ?? 0) >= 500;
      case DioExceptionType.unknown:
        return e.error is SocketException ||
            e.error is HandshakeException ||
            e.error is HttpException;
      case DioExceptionType.cancel:
      case DioExceptionType.transformTimeout:
        return false;
    }
  }

  /// Whether an HTTP response that reached us looks like a firewall /
  /// WAF rejection rather than our backend's own JSON answer.
  static bool isSuspiciousResponse(int? status, dynamic data) {
    if (status == null) return false;
    if (status == 429 || status == 406) return true;
    // Our API always answers with JSON; ModSecurity / CSF deny pages are HTML.
    if (status == 403) return data is! Map;
    return false;
  }

  static String verdictFor({
    required NetworkProbe probe,
    required int? statusCode,
    required String errorType,
    String detail = '',
    String? edge,
  }) {
    if (!probe.internetOk) {
      return "Qurilmada internet yo'q yoki juda sekin — server muammosi emas.";
    }
    if (!probe.tcpOk) {
      return 'Internet ishlayapti, lekin app.skor.uz manziliga '
          'TCP ulanish bo\'lmadi (${probe.tcp}). Bu IP yoki provayder '
          'yo\'nalishi bloklangan bo\'lishi ehtimoli yuqori.';
    }
    // Cloudflare 52x: the edge answered but could not reach our origin —
    // typically the hosting firewall (CSF) blocking Cloudflare's own IPs.
    if (statusCode != null && statusCode >= 520 && statusCode <= 527) {
      return 'Cloudflare ishlayapti, lekin asosiy serverga (origin) ulana '
          'olmadi (HTTP $statusCode). Odatda hosting firewall (CSF/LFD) '
          'Cloudflare IP manzilini bloklaganda yoki server javob bermaganda '
          'bo\'ladi — CSF\'da Cloudflare IP diapazonlari whitelistda ekanini '
          'tekshiring.';
    }
    final viaCloudflare =
        (edge ?? '').toLowerCase().contains('cloudflare') ||
        detail.toLowerCase().contains('cloudflare');
    if (viaCloudflare &&
        (statusCode == 403 || statusCode == 429 || statusCode == 503)) {
      return "So'rovni Cloudflare o'zi rad etdi (HTTP $statusCode): bu IP "
          'uchun WAF / Bot / Rate-limit qoidasi yoki challenge ishlagan '
          '(mobil ilova challenge\'ni yecha olmaydi). Cloudflare → Security → '
          'Events bo\'limida Ray ID bo\'yicha qidiring.';
    }
    if (statusCode == 429) {
      return "Server so'rovlar limitidan oshildi deb rad etdi (HTTP 429).";
    }
    if (statusCode == 403 || statusCode == 406) {
      return "Server ulanishni qabul qildi, lekin so'rovni xavfsizlik "
          'qoidasi (ModSecurity/WAF) bilan rad etdi (HTTP $statusCode).';
    }
    if (statusCode == 422 &&
        (detail.contains('majburiy') || detail.contains('required'))) {
      return "So'rov serverga yetib bordi (HTTP 422), lekin POST so'rov tanasi "
          "(phone maydoni) proxy/WAF yoki serverda bo'sh keldi: $detail";
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Server ichki xatosi (HTTP $statusCode) — backend loglarini '
          'tekshirish kerak.';
    }
    if (errorType.contains('Timeout')) {
      return 'Serverga ulanish bor, lekin javob kechikdi (timeout) — server '
          'band yoki sekin.';
    }
    return "Serverga ulanish hozir bor — API javobi: HTTP ${statusCode ?? '-'} ($errorType).";
  }

  // ---- Recording ----------------------------------------------------------

  /// Called from DioClient.onError.
  Future<void> recordDioError(DioException e) async {
    if (!isDiagnosable(e)) return;
    final response = e.response;
    await _record(
      options: e.requestOptions,
      errorType: e.type.name,
      statusCode: response?.statusCode,
      edge: response != null ? edgeInfo(response.headers) : null,
      detail: response != null
          ? _bodySnippet(response.data)
          : _clip('${e.error ?? e.message ?? ''}', 300),
    );
  }

  /// Called from DioClient.onResponse for non-JSON 403 / 406 / 429.
  Future<void> recordSuspiciousResponse(Response<dynamic> r) async {
    if (!isSuspiciousResponse(r.statusCode, r.data)) return;
    await _record(
      options: r.requestOptions,
      errorType: 'httpStatus',
      statusCode: r.statusCode,
      edge: edgeInfo(r.headers),
      detail: _bodySnippet(r.data),
    );
  }

  /// Explicitly records a login HTTP failure (e.g. 422, 403, 500) with
  /// external IP, exact time, and raw API response for support diagnostics.
  Future<NetworkIncident?> recordLoginFailureResponse(
    Response<dynamic> r, {
    String? customErrorType,
  }) async {
    return _record(
      options: r.requestOptions,
      errorType: customErrorType ?? 'HTTP_${r.statusCode}',
      statusCode: r.statusCode,
      edge: edgeInfo(r.headers),
      detail: _bodySnippet(r.data),
      force: true,
    );
  }

  /// Explicitly records a login DioException (timeout, socket, SSL, etc.)
  /// with external IP, exact time, and error details for support diagnostics.
  Future<NetworkIncident?> recordLoginDioException(DioException e) async {
    final response = e.response;
    return _record(
      options: e.requestOptions,
      errorType: e.type.name,
      statusCode: response?.statusCode,
      edge: response != null ? edgeInfo(response.headers) : null,
      detail: response != null
          ? _bodySnippet(response.data)
          : _clip('${e.error ?? e.message ?? ''}', 300),
      force: true,
    );
  }

  Future<NetworkIncident?> _record({
    required RequestOptions options,
    required String errorType,
    required int? statusCode,
    required String detail,
    String? edge,
    bool force = false,
  }) async {
    final at = now();
    final last = _lastRecordedAt;
    if (!force &&
        (_recording || (last != null && at.difference(last) < throttle))) {
      return null;
    }
    _recording = true;
    try {
      final probe = await probeRunner();
      if (!force && !probe.internetOk) return null;

      final incident = NetworkIncident(
        time: at,
        endpoint: '${options.method} ${_pathOnly(options)}',
        errorType: errorType,
        statusCode: statusCode,
        detail: detail,
        edge: edge,
        probe: probe,
        appVersion: AppUpdateService.currentVersion,
        platform: _platform(),
      );
      _lastRecordedAt = at;
      await _save(incident);
      debugPrint(
        '════════════════════════════════════════════════════════════════',
      );
      debugPrint('🩺 [SUPPORT DIAGNOSTIKA MA\'LUMOTI — LOGIN / API XATOLIGI]');
      debugPrint(incident.toReport());
      debugPrint(
        '════════════════════════════════════════════════════════════════',
      );
      return incident;
    } catch (e) {
      debugPrint('🩺 [NET DIAG] yozib bo\'lmadi: $e');
      return null;
    } finally {
      _recording = false;
    }
  }

  /// Manual "check now" from the diagnostics sheet. Not stored.
  Future<NetworkIncident> runManualCheck() async {
    final probe = await probeRunner();
    return NetworkIncident(
      time: now(),
      endpoint: 'Qo\'lda tekshiruv',
      errorType: 'manual',
      statusCode: null,
      detail: '',
      probe: probe,
      appVersion: AppUpdateService.currentVersion,
      platform: _platform(),
    );
  }

  // ---- Storage ------------------------------------------------------------

  Future<List<NetworkIncident>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map(
            (e) =>
                NetworkIncident.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(NetworkIncident incident) async {
    final list = [incident, ...await load()].take(maxIncidents).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
    revision.value++;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKey);
    _lastRecordedAt = null;
    revision.value++;
  }

  // ---- Helpers ------------------------------------------------------------

  /// "cloudflare · ray 8c1f2e3d4c5b6a79-TAS · mitigated: challenge" from
  /// response headers, or null when no CDN headers are present.
  static String? edgeInfo(Headers headers) {
    final server = headers.value('server');
    final ray = headers.value('cf-ray');
    final mitigated = headers.value('cf-mitigated');
    final parts = [
      ?server,
      if (ray != null) 'ray $ray',
      if (mitigated != null) 'mitigated: $mitigated',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _pathOnly(RequestOptions o) {
    final uri = o.uri;
    return uri.path.isEmpty ? o.path.split('?').first : uri.path;
  }

  static String _platform() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unknown';
    }
  }

  static String _clip(String s, int max) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }

  /// Response body for the report, with any credential-like fields removed.
  @visibleForTesting
  static String bodySnippet(dynamic data) => _bodySnippet(data);

  static String _bodySnippet(dynamic data) {
    if (data == null) return '';
    if (data is Map) {
      final safe = Map<String, dynamic>.from(data)
        ..removeWhere((k, _) {
          final key = k.toLowerCase();
          return key.contains('token') ||
              key.contains('password') ||
              key.contains('parol');
        });
      return _clip(jsonEncode(safe), 300);
    }
    // HTML deny pages: strip tags, keep the human-readable text.
    return _clip(data.toString().replaceAll(RegExp(r'<[^>]*>'), ' '), 300);
  }

  // ---- Probes -------------------------------------------------------------

  static Future<NetworkProbe> _runProbe() async {
    final host = Uri.parse(ApiConstants.baseUrl).host;
    final results = await Future.wait([
      _publicInfo(),
      _dns(host),
      _tcp(host),
      _https(),
    ]);
    final info = results[0] as Map<String, String?>?;
    return NetworkProbe(
      publicIp: info?['ip'],
      isp: info?['org'],
      location: info?['loc'],
      dns: results[1] as String,
      tcp: results[2] as String,
      https: results[3] as String,
    );
  }

  /// Uses third-party services on purpose: if our server banned the IP it
  /// can't tell us what that IP is.
  static Future<Map<String, String?>?> _publicInfo() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    try {
      final r = await dio.get<dynamic>('https://ipinfo.io/json');
      final d = r.data is Map ? r.data as Map : jsonDecode('${r.data}') as Map;
      final ip = d['ip']?.toString();
      if (ip != null && ip.isNotEmpty) {
        final place = [
          d['city'],
          d['country'],
        ].where((e) => e != null && '$e'.isNotEmpty).join(', ');
        return {
          'ip': ip,
          'org': d['org']?.toString(),
          'loc': place.isEmpty ? null : place,
        };
      }
    } catch (_) {}
    try {
      final r = await dio.get<dynamic>('https://api.ipify.org?format=json');
      final d = r.data is Map ? r.data as Map : jsonDecode('${r.data}') as Map;
      final ip = d['ip']?.toString();
      if (ip != null && ip.isNotEmpty) return {'ip': ip};
    } catch (_) {}
    return null;
  }

  static Future<String> _dns(String host) async {
    try {
      final addrs = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 5));
      return addrs.map((a) => a.address).join(', ');
    } on TimeoutException {
      return 'timeout';
    } catch (e) {
      return 'xato: ${_clip('$e', 80)}';
    }
  }

  static Future<String> _tcp(String host) async {
    final sw = Stopwatch()..start();
    try {
      final s = await Socket.connect(
        host,
        443,
        timeout: const Duration(seconds: 6),
      );
      s.destroy();
      return 'ok (${sw.elapsedMilliseconds} ms)';
    } on SocketException catch (e) {
      final raw = e.osError?.message ?? e.message;
      final msg = raw.toLowerCase();
      if (msg.contains('timed out') || msg.contains('timeout')) {
        return 'timeout (${sw.elapsedMilliseconds} ms)';
      }
      if (msg.contains('refused')) return 'refused (ulanish rad etildi)';
      return 'xato: ${_clip(raw, 80)}';
    } catch (e) {
      return 'xato: ${_clip('$e', 80)}';
    }
  }

  static Future<String> _https() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        validateStatus: (_) => true,
        responseType: ResponseType.plain,
      ),
    );
    final sw = Stopwatch()..start();
    try {
      final r = await dio.get<String>(ApiConstants.baseUrl);
      final edge = edgeInfo(r.headers);
      return 'HTTP ${r.statusCode} (${sw.elapsedMilliseconds} ms)'
          '${edge != null ? ' · $edge' : ''}';
    } on DioException catch (e) {
      return '${e.type.name} (${sw.elapsedMilliseconds} ms)';
    } catch (e) {
      return 'xato: ${_clip('$e', 80)}';
    }
  }
}
