import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:skore_hodimlar/core/utils/day_change_watcher.dart';

/// Ilova bo'yicha yagona "bugun". 00:00 da, ilova orqa fondan qaytganda va
/// zaxira sifatida har daqiqada tekshiriladi; kun almashsa tinglovchilar
/// chaqiriladi.
///
/// Sahifalar qoidasi: sahifa "bugun"ni ko'rsatib turgan bo'lsa (ya'ni
/// [previous] kunni) — yangi kunga o'tadi va qayta yuklaydi; kalendardan
/// qo'lda tanlangan boshqa sana o'zgarmaydi. Telefon bir necha kun uxlab
/// qolsa ham ishlaydi: "kecha" emas, oxirgi ko'rilgan "bugun" bilan
/// solishtiriladi.
class AppDay extends ChangeNotifier {
  AppDay({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _today = DateUtils.dateOnly(_clock());
  }

  static final AppDay instance = AppDay();

  final DateTime Function() _clock;
  late DateTime _today;
  DateTime? _previous;
  DayChangeWatcher? _watcher;
  Timer? _fallback;

  /// Hozirgi kalendar kuni (soatsiz).
  DateTime get today => _today;

  /// Kun almashishidan oldingi "bugun" (hali almashmagan bo'lsa — `null`).
  DateTime? get previous => _previous;

  /// Ilova ishga tushganda bir marta chaqiriladi.
  void start() {
    if (_watcher != null) return;
    _watcher = DayChangeWatcher(onNewDay: _onNewDay, clock: _clock);
    // Taymer yo'qolib qolsa ham (iOS uxlatsa) — daqiqada bir tekshiruv.
    _fallback = Timer.periodic(const Duration(minutes: 1), (_) => check());
  }

  /// Kun almashganini darhol tekshiradi.
  void check() => _watcher?.check();

  void _onNewDay(DateTime today) {
    _previous = _today;
    _today = today;
    debugPrint(
      '📅 [YANGI KUN] ${_previous!.toIso8601String().substring(0, 10)}'
      ' → ${today.toIso8601String().substring(0, 10)}',
    );
    notifyListeners();
  }

  /// Sahifadagi [shown] sana kun almashguncha "bugun" edimi — ya'ni sahifa
  /// yangi kunga o'tishi kerakmi.
  bool wasToday(DateTime shown) =>
      _previous != null && DateUtils.isSameDay(shown, _previous);

  @override
  void dispose() {
    _watcher?.dispose();
    _fallback?.cancel();
    super.dispose();
  }
}

/// "Bugungacha" bo'lgan oraliqni yangi kunga suradi (uzunligi saqlanadi).
/// Oraliq oxiri [previous] bo'lmasa (qo'lda tanlangan) — o'zgarmaydi.
({DateTime from, DateTime to})? shiftRangeToNewDay({
  required DateTime from,
  required DateTime to,
  required DateTime previous,
  required DateTime today,
}) {
  if (!DateUtils.isSameDay(to, previous)) return null;
  final shift = DateUtils.dateOnly(
    today,
  ).difference(DateUtils.dateOnly(previous));
  return (from: DateUtils.dateOnly(from).add(shift), to: today);
}
