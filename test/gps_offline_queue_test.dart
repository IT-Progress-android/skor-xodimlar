import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/services/gps_offline_queue.dart';

void main() {
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('gpsq');
  });

  tearDown(() => dir.delete(recursive: true));

  GpsOfflineQueue make({int limit = 100}) => GpsOfflineQueue(
    limit: limit,
    file: () async => File('${dir.path}/q.jsonl'),
  );

  test('tartib saqlanadi: qo\'shish, o\'qish, o\'chirish', () async {
    final q = make();
    for (var i = 0; i < 5; i++) {
      await q.add({'kind': 'ping', 'i': i});
    }
    expect(await q.length(), 5);
    expect((await q.peek(2)).map((e) => e['i']), [0, 1]);
    await q.drop(2);
    expect((await q.peek(10)).map((e) => e['i']), [2, 3, 4]);
    // Qayta ochilganda ham (servis qayta ishga tushdi) saqlanib qoladi.
    expect(await make().length(), 3);
  });

  test('limitdan oshsa eng eskilari o\'chadi', () async {
    final q = make(limit: 10);
    for (var i = 0; i < 12; i++) {
      await q.add({'i': i});
    }
    final all = await q.peek(100);
    expect(all.length, 10);
    expect(all.first['i'], 2);
  });

  test('eski SharedPreferences navbati ko\'chiriladi', () async {
    SharedPreferences.setMockInitialValues({
      'gps_offline_queue': ['{"kind":"event","i":0}'],
    });
    final q = make();
    await q.add({'kind': 'ping', 'i': 1});
    expect((await q.peek(10)).map((e) => e['i']), [0, 1]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('gps_offline_queue'), isNull);
  });
}
