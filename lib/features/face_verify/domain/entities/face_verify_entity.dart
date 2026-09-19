import 'package:equatable/equatable.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';

class FaceVerifyEntity extends Equatable {
  final bool matched;
  final double score;
  final double threshold;
  final String message;
  // Server status: ok | no_face | not_found | photo_missing | error | engine_error
  final String status;
  // Python engine detail, e.g. NO_FACE_PROBE, NO_FACE_REF, TIMEOUT (nullable).
  final String? errorCode;
  // One-time token returned on a match; must be sent to check-location so the
  // attendance record can only be created after a real face verification (§8.4).
  final String? verifyToken;
  final String? direction; // 'IN' yoki 'OUT'
  final String? eventTime; // '09:00'

  const FaceVerifyEntity({
    required this.matched,
    required this.score,
    required this.threshold,
    required this.message,
    required this.status,
    this.errorCode,
    this.verifyToken,
    this.direction,
    this.eventTime,
  });

  /// User-facing message per the API guide's decision tree (7.3). We never show
  /// the raw score — only actionable guidance.
  String get displayMessage {
    switch (status) {
      case 'ok':
        return matched
            ? AppLocalizations.trStatic('face_verify_success')
            : AppLocalizations.trStatic('face_verify_no_match');
      case 'no_face':
        return errorCode == 'NO_FACE_REF'
            ? AppLocalizations.trStatic('face_verify_ref_invalid')
            : AppLocalizations.trStatic('face_verify_face_not_visible');
      case 'not_found':
        return AppLocalizations.trStatic('err_phone_not_registered');
      case 'photo_missing':
        return AppLocalizations.trStatic('face_verify_photo_missing');
      case 'engine_error':
        switch (errorCode) {
          case 'TIMEOUT':
            return AppLocalizations.trStatic('face_verify_timeout');
          case 'SETUP_INCOMPLETE':
          case 'PYTHON_FAILED':
          case 'MODEL_LOAD_FAILED':
          case 'NO_OPENCV':
          case 'BAD_OPENCV':
            return AppLocalizations.trStatic('face_verify_not_configured');
          default:
            return AppLocalizations.trStatic('face_verify_unavailable');
        }
      default:
        return AppErrorFormatter.sanitizeMessage(message);
    }
  }

  /// Whether re-taking the selfie could plausibly succeed. Admin-side problems
  /// (missing/invalid reference photo, unknown number) are not retryable;
  /// all other transient network or errors are retryable.
  bool get retryable =>
      errorCode != 'NO_FACE_REF' &&
      status != 'photo_missing' &&
      status != 'not_found';

  @override
  List<Object?> get props => [
    matched,
    score,
    threshold,
    message,
    status,
    errorCode,
    verifyToken,
    direction,
    eventTime,
  ];
}
