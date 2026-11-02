import 'dart:async';

/// Ariza push'i (`ariza_new` — rahbarga, `manual_review` — xodimga) ilova
/// ochiq paytda kelganda — push turi. Ochiq turgan ariza ro'yxati serverdan
/// qayta yuklanadi (aks holda rad etilgan ariza "Kutilmoqda" bo'lib qoladi).
final arizaPushes = StreamController<String>.broadcast();
