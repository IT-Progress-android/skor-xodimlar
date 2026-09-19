import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  /// Checks Apple App Store / Google Play / Backend for available updates
  static Future<AppUpdateInfo?> checkUpdate() async {
    await init();

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
      }
    } catch (_) {}

    return null;
  }

  /// Automatically checks and shows the update bottom sheet if a new version is available
  static Future<void> checkAndShowUpdate(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_hasPromptedThisSession && !force) return;

    final update = await checkUpdate();
    if (update != null && context.mounted) {
      _hasPromptedThisSession = true;
      await AppUpdateBottomSheet.show(context, updateInfo: update);
    }
  }
}
