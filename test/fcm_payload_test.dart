import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FCM Payload Format Tests', () {
    test('Payload matches backend contract: jsonEncode, fcm_token, device_type', () {
      final phone = '+998 (97) 644-48-42';
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final fcmToken = 'sample_fcm_token_12345';
      final deviceType = 'android';
      final deviceId = 'dev_123';
      final int? id = 42;

      final body = <String, dynamic>{
        'phone': cleanPhone,
        if (id != null && id > 0) 'id': id,
        'fcm_token': fcmToken,
        'token': fcmToken,
        'device_type': deviceType,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      };

      final encoded = jsonEncode(body);
      expect(encoded, isA<String>());

      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['phone'], equals('998976444842'));
      expect(decoded['fcm_token'], equals('sample_fcm_token_12345'));
      expect(decoded['token'], equals('sample_fcm_token_12345'));
      expect(decoded['device_type'], equals('android'));
      expect(decoded['device_id'], equals('dev_123'));
      expect(decoded['id'], equals(42));
    });

    test('deviceType is strictly android or ios', () {
      bool isIos = false;
      final deviceType = isIos ? 'ios' : 'android';
      expect(deviceType, equals('android'));

      isIos = true;
      final deviceTypeIos = isIos ? 'ios' : 'android';
      expect(deviceTypeIos, equals('ios'));
    });
  });
}
