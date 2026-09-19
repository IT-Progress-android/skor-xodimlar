import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/services/network_connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkConnectivityService Tests', () {
    late NetworkConnectivityService service;

    setUp(() {
      service = NetworkConnectivityService.instance;
    });

    tearDown(() {
      // Reset state to online after tests
      service.notifyOnline();
    });

    test('initial state defaults to online', () {
      expect(service.isOnline, isTrue);
      expect(service.isOffline, isFalse);
    });

    test('notifyOffline changes state to offline', () {
      service.notifyOffline();
      expect(service.isOnline, isFalse);
      expect(service.isOffline, isTrue);
    });

    test('notifyOnline restores state to online', () {
      service.notifyOffline();
      expect(service.isOnline, isFalse);

      service.notifyOnline();
      expect(service.isOnline, isTrue);
      expect(service.isOffline, isFalse);
    });

    test('onConnectivityChanged stream emits status updates', () async {
      final emitted = <bool>[];
      final subscription = service.onConnectivityChanged.listen(emitted.add);

      service.notifyOffline();
      service.notifyOnline();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      expect(emitted, [false, true]);
    });
  });
}
