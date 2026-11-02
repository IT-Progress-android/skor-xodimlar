import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/widgets/app_update_bottom_sheet.dart';

class AppUpdateService {
  static const String bundleId = 'uz.skor.hodimlar';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=uz.skor.hodimlar';
  static const String appStoreUrl = 'https://apps.apple.com/app/id6797519944';

  static String currentVersion = '1.0.8';
  static int currentBuildNumber = 15;
  static bool _hasPromptedThisSession = false;

  /// Oxirgi [checkUpdate] server bilan bog'lana olmadimi — qo'lda
  /// tekshirganda "eng so'nggi versiya" o'rniga xato ko'rsatish uchun.
  static bool lastCheckFailed = false;

  /// Majburiy yangilanish. Qiymat bo'lsa `AppUpdateGate` ilova o'rniga
  /// `ForceUpdatePage`ni ko'rsatadi. Oxirgi ma'lum talab diskda saqlanadi —
  /// internetni o'chirib ilovani ochish bilan chetlab o'tib bo'lmaydi.
  static final ValueNotifier<AppUpdateInfo?> forcedUpdate = ValueNotifier(null);

  static Future<AppUpdateInfo?>? _inflight;
  static DateTime? _lastCheckAt;

  static String get _forcedKey => 'forced_update_$_platformKey';

  /// Initialize current package info dynamically
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        currentVersion = info.version;
      }
      final parsedBuild = int.tryParse(info.buildNumber);
      if (parsedBuild != null && parsedBuild > 0) {
        currentBuildNumber = parsedBuild;
      }
    } catch (_) {}
  }

  /// Semantic version comparison:
  /// Returns 1 if v1 > v2, 0 if v1 == v2, -1 if v1 < v2.
  static int compareSemVer(String v1, String v2) {
    final v1Clean = v1.replaceAll(RegExp(r'[^0-9.]'), '');
    final v2Clean = v2.replaceAll(RegExp(r'[^0-9.]'), '');

    final p1 = v1Clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final p2 = v2Clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (int i = 0; i < maxLen; i++) {
      final c1 = i < p1.length ? p1[i] : 0;
      final c2 = i < p2.length ? p2[i] : 0;
      if (c1 > c2) return 1;
      if (c1 < c2) return -1;
    }
    return 0;
  }

  /// Ilova chizilishidan oldin: saqlangan majburiy talab hali ham
  /// o'rnatilgan versiyadan yangi bo'lsa — darvoza birinchi kadrdayoq yopiq.
  static Future<void> restoreForcedUpdate(SharedPreferences prefs) async {
    await init();
    final raw = prefs.getString(_forcedKey);
    if (raw == null) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final info = AppUpdateInfo(
        version: (json['version'] ?? '').toString(),
        buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 0,
        title: (json['title'] ?? '').toString(),
        releaseNotes: [
          for (final n in (json['releaseNotes'] as List? ?? const [])) '$n',
        ],
        isMandatory: true,
        playStoreUrl: json['playStoreUrl']?.toString(),
        appStoreUrl: json['appStoreUrl']?.toString(),
      );
      if (_isNewerThanInstalled(info)) {
        forcedUpdate.value = info;
      } else {
        // Foydalanuvchi allaqachon yangilagan.
        await prefs.remove(_forcedKey);
      }
    } catch (_) {
      await prefs.remove(_forcedKey);
    }
  }

  static bool _isNewerThanInstalled(AppUpdateInfo info) {
    final cmp = compareSemVer(info.version, currentVersion);
    return cmp > 0 || (cmp == 0 && info.buildNumber > currentBuildNumber);
  }

  static void _setForced(AppUpdateInfo? info) {
    forcedUpdate.value = info;
    try {
      final prefs = sl<SharedPreferences>();
      if (info == null) {
        prefs.remove(_forcedKey);
      } else if (info.version.isNotEmpty) {
        prefs.setString(
          _forcedKey,
          jsonEncode({
            'version': info.version,
            'buildNumber': info.buildNumber,
            'title': info.title,
            'releaseNotes': info.releaseNotes,
            'playStoreUrl': info.playStoreUrl,
            'appStoreUrl': info.appStoreUrl,
          }),
        );
      }
    } catch (_) {}
  }

  /// Ilova ochilganda / fondan qaytganda. Majburiy talab bo'lmasa, tez-tez
  /// qaytib kirishlarda serverni har safar bezovta qilmaymiz.
  static Future<void> refresh() async {
    final last = _lastCheckAt;
    if (forcedUpdate.value == null &&
        last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2)) {
      return;
    }
    await checkUpdate();
  }

  /// Server eski versiyani rad etdi (HTTP 426 Upgrade Required).
  static Future<void> onUpgradeRequired() async {
    if (forcedUpdate.value != null) return;
    final update = await checkUpdate();
    if (forcedUpdate.value != null) return;
    // Tekshiruv natija bermasa ham server so'rovni rad etgan — umumiy
    // yangilash sahifasi (do'kon havolasi standart) ko'rsatiladi.
    forcedUpdate.value =
        update ??
        AppUpdateInfo(
          version: '',
          buildNumber: 0,
          isMandatory: true,
          playStoreUrl: playStoreUrl,
          appStoreUrl: appStoreUrl,
        );
  }

  /// Checks Apple App Store / Google Play / Backend for available updates.
  /// Bir vaqtda kelgan chaqiruvlar bitta so'rovni bo'lishadi; natija
  /// majburiy bo'lsa darvoza yopiladi, server "majburiy emas" desa ochiladi
  /// (tarmoq xatosida oldingi holat saqlanadi).
  static Future<AppUpdateInfo?> checkUpdate() {
    return _inflight ??= _checkUpdate()
        .then((update) {
          _lastCheckAt = DateTime.now();
          if (update != null && update.isMandatory) {
            _setForced(update);
          } else if (!lastCheckFailed) {
            _setForced(null);
          }
          return update;
        })
        .whenComplete(() => _inflight = null);
  }

  static Future<AppUpdateInfo?> _checkUpdate() async {
    await init();
    lastCheckFailed = false;

    // 0. Yangi API: admin paneldagi versiya/build bilan server o'zi solishtiradi.
    // Hali chiqmagan bo'lsa (404) yoki javob bermasa — pastdagi eski usul.
    final serverResult = await _checkViaSettingsApi();
    if (serverResult != null) return serverResult.info;

    // 1. iOS: Foydalanuvchi faqat rasmiy App Store orqali yangilay oladi.
    // Shuning uchun birinchi navbatda iTunes do'konida haqiqatdan yangi versiya borligini tekshiramiz.
    if (Platform.isIOS) {
      try {
        final dio = Dio();
        final res = await dio.get(
          'https://itunes.apple.com/lookup?bundleId=$bundleId&country=uz',
          options: Options(
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );

        if (res.statusCode == 200 && res.data is Map) {
          final results = (res.data['results'] as List?) ?? const [];
          if (results.isNotEmpty) {
            final appData = Map<String, dynamic>.from(results.first as Map);
            final storeVersion = (appData['version'] ?? '').toString();
            final trackViewUrl = (appData['trackViewUrl'] ?? appStoreUrl)
                .toString();
            final rawNotes = appData['releaseNotes']?.toString() ?? '';

            // Faqat App Store'dagi versiya hozirgi o'rnatilganidan qat'iy katta bo'lsagina!
            if (storeVersion.isNotEmpty &&
                compareSemVer(storeVersion, currentVersion) > 0) {
              List<String> notesList = [];
              if (rawNotes.isNotEmpty) {
                notesList = rawNotes
                    .split('\n')
                    .map((s) => s.replaceAll(RegExp(r'^[•\-\*\s]+'), '').trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
              }
              if (notesList.isEmpty) {
                notesList = [
                  AppLocalizations.trStatic('update_notes_default_1'),
                  AppLocalizations.trStatic('update_notes_default_2'),
                ];
              }

              return AppUpdateInfo(
                version: storeVersion,
                buildNumber: currentBuildNumber + 1,
                releaseNotes: notesList,
                isMandatory: false,
                appStoreUrl: trackViewUrl,
                playStoreUrl: playStoreUrl,
              );
            } else {
              // App Store'da yangi versiya yo'q (masalan do'konda ham shu versiya).
              // Foydalanuvchini do'konga ovora qilib yubormaymiz.
              return null;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Android (yoki iOS da iTunes tekshiruvida xatolik bo'lsa zaxira sifatida backend)
    try {
      final dio = sl<DioClient>().dio;
      final res = await dio.get(
        '/app/version',
        queryParameters: {'platform': Platform.isIOS ? 'ios' : 'android'},
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if ((res.statusCode == 200 || res.statusCode == 403) && res.data is Map) {
        final data = Map<String, dynamic>.from(res.data as Map);
        final update = AppUpdateInfo.fromJson(data);

        // Faqat remote versiya hozirgi versiyadan qat'iy katta bo'lsagina yangilanish ko'rsatiladi
        if (compareSemVer(update.version, currentVersion) > 0) {
          // Agar iOS bo'lsa va App Store'da hali chiqmagan bo'lsa chiqarmaymiz
          if (Platform.isIOS) {
            return null;
          }
          return update;
        }
        return null;
      }
    } catch (_) {}

    lastCheckFailed = true;
    return null;
  }

  /// `GET /settings/app-version?platform=&version=&buildNumber=`.
  /// Token talab qilinmaydi, shuning uchun auth interceptorsiz alohida Dio.
  /// `null` — endpoint yo'q yoki javob yaroqsiz (eski usulga o'tiladi);
  /// aks holda `info` null bo'lsa — yangilanish yo'q.
  static Future<({AppUpdateInfo? info})?> _checkViaSettingsApi() async {
    try {
      final res =
          await Dio(
            BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              headers: {'Accept': 'application/json'},
              validateStatus: (s) => s != null && s < 600,
            ),
          ).get(
            '/settings/app-version',
            queryParameters: {
              'platform': Platform.isIOS ? 'ios' : 'android',
              'version': currentVersion,
              'buildNumber': currentBuildNumber,
            },
          );
      final data = res.data;
      if (res.statusCode != 200 ||
          data is! Map ||
          data['success'] != true ||
          data['hasUpdate'] is! bool) {
        return null;
      }
      final json = Map<String, dynamic>.from(data);
      if (json['hasUpdate'] != true) return (info: null);

      final info = AppUpdateInfo.fromVersionCheck(json);
      return (
        info: AppUpdateInfo(
          version: info.version,
          buildNumber: info.buildNumber,
          title: info.title,
          releaseNotes: info.releaseNotes,
          isMandatory: info.isMandatory,
          playStoreUrl: info.playStoreUrl ?? playStoreUrl,
          appStoreUrl: info.appStoreUrl ?? appStoreUrl,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static String get _platformKey => Platform.isIOS ? 'ios' : 'android';

  /// Ixtiyoriy yangilanish har bir versiya uchun bir marta so'raladi:
  /// "Keyinroq" bosilgan versiya haqida qayta bezovta qilmaymiz.
  static bool _alreadyNotified(AppUpdateInfo update) {
    try {
      final prefs = sl<SharedPreferences>();
      final version = prefs.getString('last_notified_version_$_platformKey');
      final build = prefs.getInt('last_notified_build_$_platformKey') ?? 0;
      return version == update.version && build >= update.buildNumber;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _markNotified(AppUpdateInfo update) async {
    try {
      final prefs = sl<SharedPreferences>();
      await prefs.setString(
        'last_notified_version_$_platformKey',
        update.version,
      );
      await prefs.setInt(
        'last_notified_build_$_platformKey',
        update.buildNumber,
      );
    } catch (_) {}
  }

  /// Automatically checks and shows the update bottom sheet if a new version is available
  static Future<void> checkAndShowUpdate(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_hasPromptedThisSession && !force) return;

    final update = await checkUpdate();
    if (update == null || !context.mounted) return;
    // Majburiy yangilanishni `AppUpdateGate` alohida sahifa qilib,
    // butun ilova o'rniga ko'rsatadi — bu yerda faqat ixtiyoriysi.
    if (update.isMandatory) return;
    if (!force) {
      if (_alreadyNotified(update)) return;
      await _markNotified(update);
    }
    if (!context.mounted) return;
    _hasPromptedThisSession = true;
    await AppUpdateBottomSheet.show(context, updateInfo: update);
  }
}
