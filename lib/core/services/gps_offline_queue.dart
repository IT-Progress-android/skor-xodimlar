import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Internet yo'q paytdagi GPS nuqtalari va hodisalar navbati.
///
/// Telefon xotirasidagi faylda, har yozuv bitta qator (JSON). Yangi yozuv
/// fayl oxiriga qo'shiladi, butun ro'yxat qayta yozilmaydi. Shuning uchun
/// har soniyalik nuqtalarning hammasini saqlash mumkin. Yuborilganlari
/// fayl boshidan olib tashlanadi.
class GpsOfflineQueue {
  GpsOfflineQueue({this.limit = defaultLimit, Future<File> Function()? file})
    : _fileFactory = file ?? _defaultFile;

  /// ~5,5 soatlik uzluksiz harakat (1 nuqta/soniya), ~4 MB. To'lsa eng
  /// eskilari o'chadi.
  static const defaultLimit = 20000;

  final int limit;
  final Future<File> Function() _fileFactory;
  File? _file;
  int? _count;

  static const _legacyPrefsKey = 'gps_offline_queue';

  static Future<File> _defaultFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/gps_offline_queue.jsonl');
  }

  Future<File> _open() async {
    final cached = _file;
    if (cached != null) return cached;
    final f = await _fileFactory();
    if (!f.existsSync()) await f.create(recursive: true);
    _file = f;
    await _migrateLegacy(f);
    return f;
  }

  /// Oldingi versiyada navbat SharedPreferences'da edi — yo'qolmasin.
  Future<void> _migrateLegacy(File f) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getStringList(_legacyPrefsKey);
      if (old == null || old.isEmpty) return;
      final existing = await _readLines(f);
      await _writeLines(f, [...old, ...existing]);
      await prefs.remove(_legacyPrefsKey);
      debugPrint(
        '📦 [GPS NAVBAT] eski navbatdan ${old.length} ta ko\'chirildi',
      );
    } catch (_) {}
  }

  Future<List<String>> _readLines(File f) async {
    final text = await f.readAsString();
    return const LineSplitter()
        .convert(text)
        .where((l) => l.trim().isNotEmpty)
        .toList();
  }

  Future<void> _writeLines(File f, List<String> lines) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(lines.isEmpty ? '' : '${lines.join('\n')}\n');
    await tmp.rename(f.path);
    _count = lines.length;
  }

  Future<int> length() async {
    final f = await _open();
    return _count ??= (await _readLines(f)).length;
  }

  Future<bool> get isEmpty async => await length() == 0;

  Future<void> add(Map<String, dynamic> item) async {
    final f = await _open();
    final before = await length();
    await f.writeAsString(
      '${jsonEncode(item)}\n',
      mode: FileMode.append,
      flush: true,
    );
    final n = before + 1;
    _count = n;
    if (n > limit + limit ~/ 10) {
      // Har yozuvda qisqartirmaslik uchun — 10% oshganda bir marta.
      final lines = await _readLines(f);
      if (lines.length > limit) {
        await _writeLines(f, lines.sublist(lines.length - limit));
      } else {
        _count = lines.length;
      }
    }
  }

  /// Eng eski [n] ta yozuv (o'chirmasdan). Buzilgan qatorlar tashlanadi.
  Future<List<Map<String, dynamic>>> peek(int n) async {
    final f = await _open();
    final lines = await _readLines(f);
    _count = lines.length;
    final out = <Map<String, dynamic>>[];
    for (final l in lines.take(n)) {
      try {
        out.add(Map<String, dynamic>.from(jsonDecode(l) as Map));
      } catch (_) {
        out.add(const {'kind': 'broken'});
      }
    }
    return out;
  }

  /// Eng eski [n] ta yozuvni o'chiradi (yuborilgandan keyin).
  Future<void> drop(int n) async {
    if (n <= 0) return;
    final f = await _open();
    final lines = await _readLines(f);
    await _writeLines(f, n >= lines.length ? const [] : lines.sublist(n));
  }
}
