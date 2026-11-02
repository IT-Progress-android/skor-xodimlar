import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/network_diagnostics_service.dart';
import 'package:skore_hodimlar/core/theme/app_theme.dart';
import 'package:skore_hodimlar/core/widgets/network_diagnostics_sheet.dart';

const _bannedProbe = NetworkProbe(
  publicIp: '195.158.1.10',
  isp: 'AS8193 Uzbektelekom',
  location: 'Tashkent, UZ',
  dns: '185.1.2.3',
  tcp: 'timeout (6003 ms)',
  https: 'connectionTimeout (6001 ms)',
);

const _healthyProbe = NetworkProbe(
  publicIp: '84.54.1.2',
  isp: 'AS41202 Beeline',
  location: null,
  dns: '185.1.2.3',
  tcp: 'ok (45 ms)',
  https: 'HTTP 404 (120 ms)',
);

const _offlineProbe = NetworkProbe(
  publicIp: null,
  isp: null,
  location: null,
  dns: 'timeout',
  tcp: 'timeout (6000 ms)',
  https: 'connectionError (10 ms)',
);

DioException _timeout({String path = '/bot/staff/login?phone=998901234567'}) =>
    DioException(
      requestOptions: RequestOptions(
        path: path,
        method: 'POST',
        baseUrl: 'https://app.sifatcall.uz/api',
      ),
      type: DioExceptionType.connectionTimeout,
      message: 'Connection timed out',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final service = NetworkDiagnosticsService.instance;
  var clock = DateTime(2026, 9, 24, 14, 30, 5);

  setUpAll(() async {
    await runZonedGuarded(() async {
      AppTheme.lightTheme;
      AppTheme.darkTheme;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }, (_, _) {});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service.resetForTest();
    clock = DateTime(2026, 9, 24, 14, 30, 5);
    service.now = () => clock;
    service.probeRunner = () async => _bannedProbe;
  });

  group('classification', () {
    test('network-level failures and 5xx are diagnosable', () {
      expect(NetworkDiagnosticsService.isDiagnosable(_timeout()), isTrue);
      final ro = RequestOptions(path: '/x');
      expect(
        NetworkDiagnosticsService.isDiagnosable(
          DioException(
            requestOptions: ro,
            type: DioExceptionType.unknown,
            error: const SocketException('Connection reset by peer'),
          ),
        ),
        isTrue,
      );
      expect(
        NetworkDiagnosticsService.isDiagnosable(
          DioException.badResponse(
            statusCode: 502,
            requestOptions: ro,
            response: Response(requestOptions: ro, statusCode: 502),
          ),
        ),
        isTrue,
      );
      expect(
        NetworkDiagnosticsService.isDiagnosable(
          DioException(requestOptions: ro, type: DioExceptionType.cancel),
        ),
        isFalse,
      );
    });

    test('only firewall-looking responses count as suspicious', () {
      bool s(int c, dynamic d) =>
          NetworkDiagnosticsService.isSuspiciousResponse(c, d);
      expect(s(403, '<html>Forbidden by ModSecurity</html>'), isTrue);
      expect(s(403, {'message': 'Ruxsat yo\'q'}), isFalse); // our own API
      expect(s(429, {'message': 'Too many'}), isTrue);
      expect(s(406, null), isTrue);
      expect(s(401, 'x'), isFalse);
      expect(s(200, 'x'), isFalse);
    });

    test('verdict pinpoints an IP ban vs other causes', () {
      String v(NetworkProbe p, {int? code, String type = 'x'}) =>
          NetworkDiagnosticsService.verdictFor(
            probe: p,
            statusCode: code,
            errorType: type,
          );
      expect(v(_bannedProbe), contains('bloklangan'));
      expect(v(_offlineProbe), contains("internet yo'q"));
      expect(v(_healthyProbe, code: 403), contains('ModSecurity'));
      expect(v(_healthyProbe, code: 429), contains('429'));
      expect(v(_healthyProbe, code: 500), contains('ichki xatosi'));
      expect(
        v(_healthyProbe, type: 'receiveTimeout'),
        contains('javob kechikdi'),
      );
    });
  });

  group('recording', () {
    test('stores IP, provider, exact time and the API error', () async {
      await service.recordDioError(_timeout());
      final list = await service.load();
      expect(list, hasLength(1));

      final report = list.single.toReport();
      expect(report, contains('195.158.1.10'));
      expect(report, contains('Uzbektelekom'));
      expect(report, contains('2026-09-24 14:30:05'));
      expect(report, contains('UTC:'));
      expect(report, contains('POST /api/bot/staff/login'));
      expect(report, contains('connectionTimeout'));
      expect(report, contains('TCP :443: timeout'));
      expect(report, contains('bloklangan'));
      expect(service.hasRecentIncident(), isTrue);
    });

    test('never leaks the phone number from the query string', () async {
      await service.recordDioError(_timeout());
      final report = (await service.load()).single.toReport();
      expect(report, isNot(contains('998901234567')));
    });

    test('skips failures caused by the phone having no internet', () async {
      service.probeRunner = () async => _offlineProbe;
      await service.recordDioError(_timeout());
      expect(await service.load(), isEmpty);
    });

    test('ignores non-network errors such as cancellations', () async {
      await service.recordDioError(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.cancel,
        ),
      );
      expect(await service.load(), isEmpty);
    });

    test('retries/parallel failures within 20s make one entry', () async {
      await service.recordDioError(_timeout());
      clock = clock.add(const Duration(seconds: 5));
      await service.recordDioError(_timeout());
      expect(await service.load(), hasLength(1));

      clock = clock.add(const Duration(seconds: 30));
      await service.recordDioError(_timeout());
      expect(await service.load(), hasLength(2));
    });

    test('keeps only the newest $maxIncidents incidents', () async {
      for (var i = 0; i < 25; i++) {
        clock = clock.add(const Duration(minutes: 1));
        await service.recordDioError(_timeout());
      }
      final list = await service.load();
      expect(list, hasLength(NetworkDiagnosticsService.maxIncidents));
      expect(list.first.time, clock); // newest first
    });

    test('records HTML deny pages and strips the markup', () async {
      service.probeRunner = () async => _healthyProbe;
      final ro = RequestOptions(path: '/bot/staff/login', method: 'POST');
      await service.recordSuspiciousResponse(
        Response(
          requestOptions: ro,
          statusCode: 403,
          data: '<html><body><h1>Forbidden</h1> mod_security</body></html>',
        ),
      );
      final i = (await service.load()).single;
      expect(i.statusCode, 403);
      expect(i.detail, contains('Forbidden'));
      expect(i.detail, isNot(contains('<h1>')));
      expect(i.toReport(), contains('ModSecurity'));
    });

    test('Cloudflare 52x points at the origin firewall', () async {
      service.probeRunner = () async => _healthyProbe;
      final ro = RequestOptions(path: '/bot/staff/login', method: 'POST');
      await service.recordDioError(
        DioException.badResponse(
          statusCode: 522,
          requestOptions: ro,
          response: Response(
            requestOptions: ro,
            statusCode: 522,
            data:
                '<html><title>Connection timed out</title> error code: 522</html>',
            headers: Headers.fromMap({
              'server': ['cloudflare'],
              'cf-ray': ['8c1f2e3d4c5b6a79-TAS'],
            }),
          ),
        ),
      );
      final report = (await service.load()).single.toReport();
      expect(report, contains('ray 8c1f2e3d4c5b6a79-TAS'));
      expect(report, contains('HTTP 522'));
      expect(report, contains('origin'));
      expect(report, contains('CSF'));
    });

    test('Cloudflare block/challenge is told apart from our API', () async {
      service.probeRunner = () async => _healthyProbe;
      final ro = RequestOptions(path: '/bot/staff/login', method: 'POST');
      await service.recordSuspiciousResponse(
        Response(
          requestOptions: ro,
          statusCode: 403,
          data: '<html>Just a moment...</html>',
          headers: Headers.fromMap({
            'server': ['cloudflare'],
            'cf-ray': ['8c1f000000000001-FRA'],
            'cf-mitigated': ['challenge'],
          }),
        ),
      );
      final report = (await service.load()).single.toReport();
      expect(report, contains('mitigated: challenge'));
      expect(report, contains("Cloudflare o'zi rad etdi"));
      expect(report, contains('Ray ID'));
    });

    test('drops token/password fields from response bodies', () {
      final s = NetworkDiagnosticsService.bodySnippet({
        'message': 'err',
        'token': 'SECRET1',
        'api_token': 'SECRET2',
        'password': 'SECRET3',
      });
      expect(s, contains('err'));
      expect(s, isNot(contains('SECRET')));
    });

    test('survives corrupt storage', () async {
      SharedPreferences.setMockInitialValues({
        NetworkDiagnosticsService.prefKey: '{not json',
      });
      expect(await service.load(), isEmpty);
    });

    test('clear empties the log', () async {
      await service.recordDioError(_timeout());
      await service.clear();
      expect(await service.load(), isEmpty);
      expect(service.hasRecentIncident(), isFalse);
    });
  });

  group('sheet', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('shows incidents, runs a check and copies (${mode.name})', (
        tester,
      ) async {
        await service.recordDioError(_timeout());
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            locale: AppLanguage.english.locale,
            supportedLocales: AppLanguage.supportedLocales,
            localizationsDelegates: const [AppLocalizations.delegate],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => NetworkDiagnosticsSheet.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Network diagnostics'), findsOneWidget);
        expect(find.textContaining('195.158.1.10'), findsOneWidget);

        service.probeRunner = () async => _healthyProbe;
        await tester.tap(find.text('Check now'));
        await tester.pumpAndSettle();
        expect(find.text('Current status'), findsOneWidget);
        expect(find.textContaining('84.54.1.2'), findsOneWidget);

        await tester.tap(find.text('Copy all'));
        await tester.pumpAndSettle();
        expect(copied, contains('84.54.1.2'));
        expect(copied, contains('195.158.1.10'));
        expect(find.text('Copied'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

const maxIncidents = NetworkDiagnosticsService.maxIncidents;
