import 'package:flutter/foundation.dart';

/// Rahbar xaritasida ochilishi kerak bo'lgan xodim (masalan, "lokatsiya
/// o'chirildi" bildirishnomasi bosilganda). Shell xarita tabiga o'tadi,
/// xarita xodimni topib, kartasini ochadi va qiymatni tozalaydi.
final ValueNotifier<int?> rahbarMapFocusStaff = ValueNotifier<int?>(null);

/// Rahbar bildirishnomasi bosilganda ochiladigan sahifa.
enum RahbarOpenTarget { arizalar, kelmaganlar }

typedef RahbarOpenRequest = ({
  RahbarOpenTarget target,
  int? filialId,
  DateTime? day,
});

/// "Yangi ariza" / "xodimlar kelmadi" bildirishnomasi bosilganda: shell
/// bosh sahifa tabiga o'tadi, bosh sahifa kerakli ro'yxatni ochadi va
/// qiymatni tozalaydi.
final ValueNotifier<RahbarOpenRequest?> rahbarOpenRequest =
    ValueNotifier<RahbarOpenRequest?>(null);

/// Push `data` sidan so'rov: `ariza_new` — arizalar, `absent_alert` —
/// kelmaganlar (`filial_id`, `sana` bo'lsa o'sha filial/kun). Boshqa
/// turlar uchun `null`.
RahbarOpenRequest? rahbarOpenRequestFor(Map<String, dynamic> data) {
  final target = switch (data['type']?.toString()) {
    'ariza_new' => RahbarOpenTarget.arizalar,
    'absent_alert' => RahbarOpenTarget.kelmaganlar,
    _ => null,
  };
  if (target == null) return null;
  final filialId = int.tryParse('${data['filial_id'] ?? ''}');
  final day = DateTime.tryParse('${data['sana'] ?? ''}');
  return (
    target: target,
    filialId: filialId != null && filialId > 0 ? filialId : null,
    day: day == null ? null : DateTime(day.year, day.month, day.day),
  );
}
