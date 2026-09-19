import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_cubit.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';

/// Keeps the staff's language preference in sync with the backend
/// (`GET`/`POST /bot/staff/til`), per MOBIL_UCHUN_TIL_QOSHISH.md.
///
/// This only affects *server-sent* text (push notification titles/bodies) —
/// the app's own UI strings are handled entirely by [LanguageCubit] /
/// [AppTranslations] and never touch this endpoint. Rahbar (admin) accounts
/// have no `bot/staff` record, so every call here is a no-op for them.
class LanguageSyncService {
  static Future<String?> _staffPhone(SharedPreferences prefs) async {
    final role = prefs.getString('user_role');
    if (role == 'admin') return null;

    final rawPhone = prefs.getString('phone') ?? prefs.getString('staff_phone');
    if (rawPhone == null || rawPhone.isEmpty) return null;

    var cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 9) {
      cleanPhone = '998$cleanPhone';
    }
    return cleanPhone;
  }

  /// Call on app startup / after login: reads the language the staff last
  /// saved on the backend (e.g. from another device) and applies it locally.
  static Future<void> fetchAndApplyFromBackend(LanguageCubit cubit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanPhone = await _staffPhone(prefs);
      if (cleanPhone == null) return;

      final id = prefs.getInt('staff_id');
      final response = await sl<DioClient>().dio.get(
        ApiConstants.staffTil,
        queryParameters: {
          'phone': cleanPhone,
          if (id != null && id > 0) 'id': id,
        },
        options: Options(validateStatus: (s) => s != null && s < 500),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final til = (response.data as Map)['til']?.toString();
        if (til == null || til.isEmpty) return;
        final serverLanguage = AppLanguage.fromCode(til);
        if (serverLanguage != cubit.state.language) {
          await cubit.changeLanguage(serverLanguage);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [LANGUAGE SYNC] Serverdan til olinmadi: $e');
    }
  }

  /// Call whenever the user picks a language in-app: persists it on the
  /// backend so future push notifications arrive in that language too.
  static Future<void> pushToBackend(AppLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanPhone = await _staffPhone(prefs);
      if (cleanPhone == null) return;

      final id = prefs.getInt('staff_id');
      final response = await sl<DioClient>().dio.post(
        ApiConstants.staffTil,
        data: jsonEncode({
          'phone': cleanPhone,
          if (id != null && id > 0) 'id': id,
          'til': language.code,
        }),
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '⚠️ [LANGUAGE SYNC] Til serverga saqlanmadi: ${response.statusCode} '
          '${response.data}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [LANGUAGE SYNC] Tarmoq xatosi: $e');
    }
  }
}
