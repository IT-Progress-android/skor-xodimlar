import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService SemVer Comparison Tests', () {
    test('User on same version (1.0.8 vs 1.0.8) should NEVER prompt update', () {
      final result = AppUpdateService.compareSemVer('1.0.8', '1.0.8');
      expect(result, equals(0));
      expect(result > 0, isFalse);
    });

    test('User on newer version than store (1.0.8 vs 1.0.7) should NEVER prompt update', () {
      final result = AppUpdateService.compareSemVer('1.0.7', '1.0.8');
      expect(result, equals(-1));
      expect(result > 0, isFalse);
    });

    test('Store has newer patch version (1.0.9 vs 1.0.8) triggers update', () {
      final result = AppUpdateService.compareSemVer('1.0.9', '1.0.8');
      expect(result, equals(1));
      expect(result > 0, isTrue);
    });

    test('Store has newer minor version (1.1.0 vs 1.0.8) triggers update', () {
      final result = AppUpdateService.compareSemVer('1.1.0', '1.0.8');
      expect(result, equals(1));
      expect(result > 0, isTrue);
    });

    test('Store has newer major version (2.0.0 vs 1.0.8) triggers update', () {
      final result = AppUpdateService.compareSemVer('2.0.0', '1.0.8');
      expect(result, equals(1));
      expect(result > 0, isTrue);
    });

    test('Handles dirty strings like "v1.0.8" or "1.0.8+15"', () {
      expect(AppUpdateService.compareSemVer('v1.0.8', '1.0.8'), equals(0));
      expect(AppUpdateService.compareSemVer('1.0.8', 'v1.0.8'), equals(0));
      expect(AppUpdateService.compareSemVer('v1.0.9', '1.0.8'), equals(1));
    });
  });
}
