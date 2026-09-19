import 'dart:io';
import 'package:dio/dio.dart';
import 'package:skore_hodimlar/core/errors/exceptions.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/features/profile/data/models/profile_model.dart';

class PhotoUploadResult {
  final String photoUrl;
  final bool hikSynced;
  final String? hikNote;
  const PhotoUploadResult({
    required this.photoUrl,
    required this.hikSynced,
    this.hikNote,
  });
}

class PhoneChangeResult {
  final String newPhone;
  final String newPhonePretty;
  final String message;
  const PhoneChangeResult({
    required this.newPhone,
    required this.newPhonePretty,
    required this.message,
  });
}

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile(String phone, {int? staffId});
  Future<PhotoUploadResult> uploadPhoto(
    String phone,
    int staffId,
    File photoFile,
  );
  Future<PhoneChangeResult> changePhone(
    String currentPhone,
    int staffId,
    String newPhone9Digits,
  );
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final DioClient dioClient;
  ProfileRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<ProfileModel> getProfile(String phone, {int? staffId}) async {
    try {
      final queryParams = <String, dynamic>{'phone': phone};
      if (staffId != null) queryParams['id'] = staffId;

      final response = await dioClient.dio.get(
        '/bot/staff/profile',
        queryParameters: queryParams,
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final body = Map<String, dynamic>.from(response.data as Map);
        return ProfileModel.fromJson(body);
      } else {
        final fallbackRes = await dioClient.dio.get(
          '/bot/profile-by-phone',
          queryParameters: {'phone': phone},
          options: Options(
            headers: {'Accept': 'application/json'},
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (fallbackRes.statusCode == 200 && fallbackRes.data is Map) {
          final body = Map<String, dynamic>.from(fallbackRes.data as Map);
          return ProfileModel.fromJson(body);
        }
        throw ServerException(
          AppLocalizations.trStatic('err_profile_load_failed'),
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(AppLocalizations.trStatic('err_no_internet'));
    }
  }

  @override
  Future<PhotoUploadResult> uploadPhoto(
    String phone,
    int staffId,
    File photoFile,
  ) async {
    try {
      final formData = FormData.fromMap({
        'phone': phone,
        'id': staffId,
        'photo': await MultipartFile.fromFile(
          photoFile.path,
          filename: 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await dioClient.dio.post(
        '/bot/staff/profile/photo',
        data: formData,
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final body = (response.data is Map)
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if (response.statusCode == 200 &&
          (body['status'] == 'ok' || body.containsKey('photo_url'))) {
        return PhotoUploadResult(
          photoUrl: body['photo_url'] as String? ?? '',
          hikSynced: body['hik_synced'] as bool? ?? true,
          hikNote: body['hik_note'] as String?,
        );
      } else {
        final msg =
            body['message']?.toString() ??
            AppLocalizations.trStatic('err_photo_upload_failed');
        throw ServerException(msg);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        AppLocalizations.trStatic('err_photo_upload_could_not'),
      );
    }
  }

  @override
  Future<PhoneChangeResult> changePhone(
    String currentPhone,
    int staffId,
    String newPhone9Digits,
  ) async {
    try {
      final payload = {
        'phone': currentPhone,
        'id': staffId,
        'new_phone': '998$newPhone9Digits',
      };

      final response = await dioClient.dio.post(
        '/bot/staff/profile/phone',
        data: payload,
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final body = (response.data is Map)
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if (response.statusCode == 200 && body['status'] == 'ok') {
        return PhoneChangeResult(
          newPhone: body['phone'] as String? ?? '998$newPhone9Digits',
          newPhonePretty:
              body['phone_pretty'] as String? ?? '+998 $newPhone9Digits',
          message:
              body['message'] as String? ??
              AppLocalizations.trStatic('profile_phone_updated'),
        );
      } else if (response.statusCode == 409 || body['status'] == 'duplicate') {
        throw ServerException(
          body['message']?.toString() ??
              AppLocalizations.trStatic('err_phone_duplicate'),
        );
      } else {
        throw ServerException(
          body['message']?.toString() ??
              AppLocalizations.trStatic('err_phone_change_failed'),
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        AppLocalizations.trStatic('err_phone_change_error'),
      );
    }
  }
}
