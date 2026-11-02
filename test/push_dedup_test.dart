import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/services/push_dedup.dart';

void main() {
  const today = '2026-10-14';

  test('eslatma kuniga bir marta', () {
    expect(shouldShowPush('attendance_reminder', today: today), isTrue);
    expect(
      shouldShowPush('attendance_reminder', lastShownDay: today, today: today),
      isFalse,
    );
    expect(
      shouldShowPush(
        'shift_end_reminder',
        lastShownDay: '2026-10-13',
        today: today,
      ),
      isTrue,
    );
  });

  test('turi yo\'q eslatma — attendance_reminder', () {
    expect(shouldShowPush(null, lastShownDay: today, today: today), isFalse);
  });

  test('auto_ketdi ko\'rsatilmaydi, topshiriqlar har doim', () {
    expect(shouldShowPush('auto_ketdi', today: today), showAutoKetdiPush);
    expect(
      shouldShowPush('task_new', lastShownDay: today, today: today),
      isTrue,
    );
  });

  test('ikkinchi bir xil push e\'tiborsiz, ertasi kuni yana chiqadi', () async {
    SharedPreferences.setMockInitialValues({});
    final d = DateTime(2026, 10, 14, 8, 50);
    expect(await claimPushDisplay('attendance_reminder', now: d), isTrue);
    expect(await claimPushDisplay('attendance_reminder', now: d), isFalse);
    expect(await claimPushDisplay('shift_end_reminder', now: d), isTrue);
    expect(await claimPushDisplay('shift_end_reminder', now: d), isFalse);
    expect(
      await claimPushDisplay(
        'attendance_reminder',
        now: d.add(const Duration(days: 1)),
      ),
      isTrue,
    );
  });
}
