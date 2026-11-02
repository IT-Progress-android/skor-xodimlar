import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skore_hodimlar/core/localization/task_translations.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/rahbar_map_focus.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/task_stats_cubit.dart';

void main() {
  group('TaskTranslations', () {
    test('every language has the same keys as uz', () {
      final uz = TaskTranslations.translations['uz']!.keys.toSet();
      for (final lang in ['ru', 'en', 'ky']) {
        final keys = TaskTranslations.translations[lang]!.keys.toSet();
        expect(keys.difference(uz), isEmpty, reason: '$lang has extra keys');
        expect(uz.difference(keys), isEmpty, reason: '$lang misses keys');
      }
    });

    test('every holat, period and month has a translation', () {
      final uz = TaskTranslations.translations['uz']!;
      for (final h in TaskHolat.values) {
        expect(uz.containsKey(h.translationKey), isTrue, reason: h.name);
      }
      for (final p in TaskPeriod.values) {
        expect(uz.containsKey(p.translationKey), isTrue, reason: p.name);
      }
      for (var m = 1; m <= 12; m++) {
        expect(uz.containsKey('task_month_$m'), isTrue);
        expect(uz.containsKey('task_month_full_$m'), isTrue);
      }
      for (var d = 1; d <= 7; d++) {
        expect(uz.containsKey('task_weekday_$d'), isTrue);
      }
    });
  });

  group('Task models', () {
    test('StaffTask parses the TZ payload', () {
      final t = StaffTask.fromJson({
        'id': 301,
        'title': 'Kassa hisoboti',
        'holat': 'bajarilmadi',
        'muddat': '2026-10-05T18:00:00+05:00',
        'return_comment': 'Qayta tekshiring',
      });
      expect(t.id, 301);
      expect(t.holat, TaskHolat.bajarilmadi);
      expect(t.holat.isOpen, isTrue);
      expect(t.muddat!.toUtc(), DateTime.utc(2026, 10, 5, 13));
      expect(t.returnComment, 'Qayta tekshiring');
    });

    test('unknown holat falls back to jarayonda', () {
      expect(TaskHolat.fromString('xyz'), TaskHolat.jarayonda);
      expect(TaskHolat.fromString(null), TaskHolat.jarayonda);
    });

    test('RahbarTaskDetail reads assignees and transfer target', () {
      final d = RahbarTaskDetail.fromJson({
        'id': '7',
        'title': 'T',
        'deadline': '2026-10-05T18:00:00+05:00',
        'cancelled_at': null,
        'xodimlar': [
          {
            'assignee_id': 1,
            'staff_id': 12,
            'ism': 'Aliyev Vali',
            'holat': 'otkazildi',
            'otkazildi_kimga': {'staff_id': 91, 'ism': 'Sardor'},
          },
        ],
      });
      expect(d.id, 7);
      expect(d.bekorQilingan, isFalse);
      expect(d.xodimlar.single.holat, TaskHolat.otkazildi);
      expect(d.xodimlar.single.otkazildiKimga!.staffId, 91);
    });

    test('RahbarTaskSummary reads created_at and id', () {
      final s = RahbarTaskSummary.fromJson({
        'id': 15,
        'title': 'Test topshiriq',
        'deadline': '2026-10-06T18:00:00+05:00',
        'created_at': '2026-10-03T14:00:00+05:00',
      });
      expect(s.id, 15);
      expect(s.title, 'Test topshiriq');
      expect(s.createdAt, isNotNull);
    });

    test('PageMeta reports more pages', () {
      final m = PageMeta.fromJson({
        'page': 1,
        'per_page': 30,
        'total': 57,
        'last_page': 2,
      });
      expect(m.hasMore, isTrue);
    });

    test('TaskCounters keeps null percentages', () {
      final c = TaskCounters.fromJson({'berilgan': 3, 'bajarish_foizi': null});
      expect(c.berilgan, 3);
      expect(c.bajarishFoizi, isNull);
    });
  });

  group('shiftPeriod', () {
    test('moves by the period size', () {
      final d = DateTime(2026, 10, 2);
      expect(shiftPeriod(TaskPeriod.kun, d, -1), DateTime(2026, 10, 1));
      expect(shiftPeriod(TaskPeriod.hafta, d, -1), DateTime(2026, 9, 25));
      expect(shiftPeriod(TaskPeriod.oy, d, -1), DateTime(2026, 9, 1));
      expect(shiftPeriod(TaskPeriod.yil, d, 1), DateTime(2027, 1, 1));
    });
  });

  group('FcmService.detailsFor kanal', () {
    String? ch(String? type) => FcmService.detailsFor(type).android?.channelId;
    test('davomat — maxsus ovozli kanal', () {
      expect(ch(null), 'davomat_voice_channel_v2');
      expect(ch('attendance'), 'davomat_voice_channel_v2');
    });
    test('qolganlari — standart ovoz', () {
      expect(ch('location_alert'), 'location_alert_channel');
      expect(ch('location_warning'), 'general_channel');
      expect(ch('battery_low'), 'general_channel');
      expect(ch('attendance_reminder'), 'general_channel');
      expect(ch('shift_end_reminder'), 'general_channel');
      expect(ch('task_new'), 'task_channel');
      expect(FcmService.detailsFor('general').android?.sound, isNull);
    });
    test('ilova yopiq bo\'lganda standart kanal — davomat emas', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final m = RegExp(
        r'default_notification_channel_id"\s*android:value="([^"]+)"',
      ).firstMatch(manifest);
      expect(m?.group(1), 'general_channel');
    });
  });

  group('FcmService.shouldHandle', () {
    test('admin only gets task_done, staff gets everything else', () {
      expect(FcmService.shouldHandle('admin', 'task_done'), isTrue);
      expect(FcmService.shouldHandle('admin', 'task_new'), isFalse);
      expect(FcmService.shouldHandle('admin', 'attendance_reminder'), isFalse);
      expect(FcmService.shouldHandle('staff', 'task_new'), isTrue);
      expect(FcmService.shouldHandle(null, 'attendance_reminder'), isTrue);
      expect(FcmService.shouldHandle(null, 'task_done'), isFalse);
      expect(FcmService.shouldHandle('admin', 'location_alert'), isTrue);
      expect(FcmService.shouldHandle('staff', 'location_alert'), isFalse);
      expect(FcmService.shouldHandle('staff', 'location_warning'), isTrue);
      expect(FcmService.shouldHandle('admin', 'location_warning'), isFalse);
      expect(FcmService.shouldHandle('admin', 'ariza_new'), isTrue);
      expect(FcmService.shouldHandle('admin', 'absent_alert'), isTrue);
      expect(FcmService.shouldHandle('staff', 'ariza_new'), isFalse);
      expect(FcmService.shouldHandle('staff', 'absent_alert'), isFalse);
    });
  });

  group('rahbarOpenRequestFor', () {
    test('ariza_new opens applications', () {
      final r = rahbarOpenRequestFor({'type': 'ariza_new', 'ariza_id': '5'});
      expect(r?.target, RahbarOpenTarget.arizalar);
    });

    test('absent_alert opens absent list for its branch and day', () {
      final r = rahbarOpenRequestFor({
        'type': 'absent_alert',
        'filial_id': '6',
        'sana': '2026-11-02',
      });
      expect(r?.target, RahbarOpenTarget.kelmaganlar);
      expect(r?.filialId, 6);
      expect(r?.day, DateTime(2026, 11, 2));
    });

    test('missing or zero filial and bad date are ignored', () {
      final r = rahbarOpenRequestFor({
        'type': 'absent_alert',
        'filial_id': '0',
        'sana': 'x',
      });
      expect(r?.filialId, isNull);
      expect(r?.day, isNull);
    });

    test('other types give null', () {
      expect(rahbarOpenRequestFor({'type': 'task_done'}), isNull);
      expect(rahbarOpenRequestFor({}), isNull);
    });
  });

  group('Filial filtri', () {
    test('distinctFilials drops empty, dedupes and sorts', () {
      expect(
        distinctFilials([
          'IT PROGRESS 1',
          null,
          ' ',
          'AI ACADEMY',
          'IT PROGRESS 1 ',
        ]),
        ['AI ACADEMY', 'IT PROGRESS 1'],
      );
    });

    test('TaskCounters.combine sums counts and weights percentages', () {
      final c = TaskCounters.combine(const [
        TaskCounters(
          berilgan: 8,
          ozvaqtida: 8,
          bajarishFoizi: 100,
          ozvaqtidaFoizi: 100,
          uddalamadiFoizi: 0,
        ),
        TaskCounters(
          berilgan: 2,
          ozvaqtida: 1,
          bajarilmadi: 1,
          bajarishFoizi: 50,
          ozvaqtidaFoizi: 50,
          uddalamadiFoizi: 50,
        ),
      ]);
      expect(c.berilgan, 10);
      expect(c.ozvaqtida, 9);
      expect(c.bajarilmadi, 1);
      expect(c.bajarishFoizi, 90);
      expect(c.uddalamadiFoizi, 10);
    });

    test('combine of nothing has no percentages', () {
      final c = TaskCounters.combine(const []);
      expect(c.berilgan, 0);
      expect(c.bajarishFoizi, isNull);
    });
  });

  group('FcmService.notificationIdFor', () {
    final now = DateTime(2026, 11, 2, 14, 30);

    test('bitta xodimning GPS xabarlari bitta ID oladi', () {
      final a = FcmService.notificationIdFor({
        'type': 'location_alert',
        'staff_id': '3561',
        'kind': 'lost',
      }, now);
      final b = FcmService.notificationIdFor({
        'type': 'location_alert',
        'staff_id': '3561',
        'kind': 'restored',
      }, now.add(const Duration(hours: 1)));
      expect(a, b);
      expect(
        FcmService.notificationIdFor({
          'type': 'location_alert',
          'staff_id': '3562',
        }, now),
        isNot(a),
      );
    });

    test('boshqa turlar har safar yangi ID oladi', () {
      final a = FcmService.notificationIdFor({'type': 'ariza_new'}, now);
      final b = FcmService.notificationIdFor({
        'type': 'ariza_new',
      }, now.add(const Duration(seconds: 1)));
      expect(a, isNot(b));
      expect(a, lessThan(1000000000));
    });
  });
}
