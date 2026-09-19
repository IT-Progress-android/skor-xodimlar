import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/face_verify/data/models/face_verify_model.dart';

abstract class FaceRemoteDataSource {
  Future<FaceVerifyModel> verifyFace(
    String phone,
    Uint8List imageBytes, {
    String? staffId,
  });
}

class FaceRemoteDataSourceImpl implements FaceRemoteDataSource {
  final Dio dio;

  FaceRemoteDataSourceImpl(this.dio);

  @override
  Future<FaceVerifyModel> verifyFace(
    String phone,
    Uint8List imageBytes, {
    String? staffId,
  }) async {
    if (imageBytes.isEmpty) {
      throw Exception(AppLocalizations.trStatic('err_empty_image'));
    }

    final formData = FormData.fromMap({
      'phone': phone,
      'id': ?staffId,
      'selfie': MultipartFile.fromBytes(
        imageBytes,
        filename: 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    try {
      final response = await dio.post(
        ApiConstants.faceVerify,
        data: formData,
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 600,
          followRedirects: false,
        ),
      );

      if (response.data is Map) {
        final map = Map<String, dynamic>.from(response.data as Map);
        final rawMsg = map['message']?.toString() ?? '';

        // Agar server redirect (301/302/405) yoki metod xatosi qaytarsa:
        if (response.statusCode == 405 ||
            rawMsg.contains('GET method is not supported') ||
            (map['status'] == 'error' &&
                rawMsg.contains('Supported methods: POST'))) {
          return FaceVerifyModel(
            matched: false,
            score: 0.0,
            threshold: 0.0,
            status: 'engine_error',
            errorCode: 'TIMEOUT',
            message: AppLocalizations.trStatic('err_connection_lost'),
          );
        }

        if (response.statusCode == 413 ||
            rawMsg.contains('failed to upload') ||
            rawMsg.contains('payload too large')) {
          return FaceVerifyModel(
            matched: false,
            score: 0.0,
            threshold: 0.0,
            status: 'engine_error',
            errorCode: 'TIMEOUT',
            message: AppLocalizations.trStatic('err_image_too_large'),
          );
        }

        return FaceVerifyModel.fromJson(map, statusCode: response.statusCode);
      }

      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 405) {
        return FaceVerifyModel(
          matched: false,
          score: 0.0,
          threshold: 0.0,
          status: 'engine_error',
          errorCode: 'TIMEOUT',
          message: AppLocalizations.trStatic('err_connection_lost'),
        );
      }

      throw Exception(AppErrorFormatter.fromStatusCode(response.statusCode));
    } on DioException catch (e) {
      throw Exception(AppErrorFormatter.toUzbek(e));
    } catch (e) {
      throw Exception(AppErrorFormatter.toUzbek(e));
    }
  }
}
