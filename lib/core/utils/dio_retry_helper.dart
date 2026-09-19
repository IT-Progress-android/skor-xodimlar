import 'dart:async';
import 'package:dio/dio.dart';

import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';

/// Network retry and error message helper per Bosh-Sahifa-Timeout.pdf §2.3 & §2.4
class DioRetryHelper {
  /// Retries a Dio request up to [maxAttempts] times for network/connection errors.
  /// Does NOT retry on HTTP 401, 403, 404, 422 errors.
  static Future<T> withRetry<T>(
    Future<T> Function() request, {
    int maxAttempts = 3,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        return await request();
      } on DioException catch (e) {
        final bool isRetryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        // Don't retry if not a network issue, or if this is the last attempt
        if (!isRetryable || i == maxAttempts - 1) {
          rethrow;
        }

        // Exponential backoff: 1s, 2s, 4s
        final delaySeconds = 1 << i;
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
    throw StateError(AppLocalizations.trStatic('err_could_not_connect'));
  }

  /// Converts a DioException or Object into a user-friendly Uzbek error message (§2.4).
  static String formatErrorMessage(dynamic e) {
    return AppErrorFormatter.toUzbek(e);
  }
}
