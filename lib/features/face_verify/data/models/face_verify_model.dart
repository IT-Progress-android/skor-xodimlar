import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/face_verify/domain/entities/face_verify_entity.dart';

class FaceVerifyModel extends FaceVerifyEntity {
  const FaceVerifyModel({
    required super.matched,
    required super.score,
    required super.threshold,
    required super.message,
    required super.status,
    super.errorCode,
    super.verifyToken,
    super.direction,
    super.eventTime,
  });

  factory FaceVerifyModel.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final rawMsg = json['message']?.toString() ?? '';
    final sanitizedMsg = AppErrorFormatter.sanitizeMessage(
      rawMsg,
      statusCode: statusCode,
    );

    return FaceVerifyModel(
      // Decide on `matched`, never on the HTTP status code (API guide 2.2).
      matched: json['matched'] == true,
      score: (json['score'] as num? ?? 0.0).toDouble(),
      threshold: (json['threshold'] as num? ?? 0.0).toDouble(),
      message: sanitizedMsg,
      status:
          json['status']?.toString() ??
          (json['matched'] == true ? 'ok' : 'error'),
      errorCode: json['error_code']?.toString() ?? json['code']?.toString(),
      verifyToken: json['verify_token']?.toString(),
      direction: json['direction']?.toString(),
      eventTime: json['event_time']?.toString(),
    );
  }
}
