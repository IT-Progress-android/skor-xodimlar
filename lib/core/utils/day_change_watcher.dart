import 'dart:async';

import 'package:flutter/widgets.dart';

/// Telefon kalendar kuni almashganini (00:00) kuzatadi va [onNewDay] ni
/// yangi kun (soatsiz) bilan chaqiradi.
///
/// Ikki yo'l bilan tekshiriladi:
/// - keyingi yarim tunga taymer — ilova ochiq turganda aynan 00:00 da;
/// - ilova orqa fondan qaytganda — telefon uxlab qolsa taymer kechikadi
///   yoki umuman ishlamaydi, shuning uchun qaytganda kun qayta solishtiriladi.
class DayChangeWatcher with WidgetsBindingObserver {
  DayChangeWatcher({required this.onNewDay, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _day = _today();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  final void Function(DateTime today) onNewDay;
  final DateTime Function() _clock;

  late DateTime _day;
  Timer? _timer;
  bool _disposed = false;

  /// Hozirgi kalendar kuni (soatsiz).
  DateTime get today => _day;

  DateTime _today() {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  void _schedule() {
    _timer?.cancel();
    final now = _clock();
    final next = DateTime(now.year, now.month, now.day + 1);
    // 1 s zaxira: taymer biroz erta uyg'onsa ham yangi kun bo'lsin.
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), check);
  }

  /// Kun almashgan bo'lsa [onNewDay] ni chaqiradi. Ilova qaytganda va
  /// taymerda avtomatik chaqiriladi.
  void check() {
    if (_disposed) return;
    final now = _today();
    if (now != _day) {
      _day = now;
      onNewDay(now);
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
