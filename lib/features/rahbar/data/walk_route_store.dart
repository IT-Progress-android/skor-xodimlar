import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';
import 'package:skore_hodimlar/features/rahbar/data/building_index.dart'
    show LatLng;

/// Yandex piyoda marshrutlari natijalari (yo'lakka moslangan bo'laklar)
/// telefonda saqlanadi: bir marta ochilgan tarix qayta ochilganda Yandex'ga
/// so'rov ketmaydi, chiziq darhol chiziladi. O'tgan kunlar o'zgarmaydi,
/// bugungi kunning yangi bo'laklari esa o'z kalitlari bilan qo'shiladi.
///
/// Qiymat — yo'l nuqtalari; bo'sh ro'yxat — "mos yo'l yo'q" (silliq iz
/// chiziladi, qayta so'ralmaydi).
abstract class WalkRouteStore {
  Future<Map<String, List<LatLng>>> load();

  Future<void> save(Map<String, List<LatLng>> entries);
}

/// Ilova papkasidagi JSON fayl. Algoritm (tekshiruv qoidalari) o'zgarsa
/// [version] oshiriladi — eski natijalar ishlatilmaydi.
class FileWalkRouteStore implements WalkRouteStore {
  FileWalkRouteStore({this.version = 1});

  final int version;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/walk_routes_v$version.json');
  }

  @override
  Future<Map<String, List<LatLng>>> load() async {
    final file = await _file();
    if (!file.existsSync()) return {};
    final text = await file.readAsString();
    // Bir necha MB JSON — UI qotmasin, alohida isolate'da o'qiladi.
    return Isolate.run(() => decodeWalkRoutes(text));
  }

  @override
  Future<void> save(Map<String, List<LatLng>> entries) async {
    final copy = Map.of(entries);
    final text = await Isolate.run(() => encodeWalkRoutes(copy));
    final file = await _file();
    // Yarim yozilgan fayl qolmasin: avval vaqtinchalik faylga.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(file.path);
  }
}

/// Xotiradagi ombor (testlar uchun).
class MemoryWalkRouteStore implements WalkRouteStore {
  Map<String, List<LatLng>> data = {};
  int saves = 0;

  @override
  Future<Map<String, List<LatLng>>> load() async => Map.of(data);

  @override
  Future<void> save(Map<String, List<LatLng>> entries) async {
    saves++;
    data = Map.of(entries);
  }
}

/// `{"kalit": [lat, lng, lat, lng, ...]}` — ixcham ko'rinish.
String encodeWalkRoutes(Map<String, List<LatLng>> entries) => jsonEncode({
  for (final e in entries.entries)
    e.key: [
      for (final p in e.value) ...[
        double.parse(p.lat.toStringAsFixed(6)),
        double.parse(p.lng.toStringAsFixed(6)),
      ],
    ],
});

/// [encodeWalkRoutes] ning teskarisi. Buzilgan yozuvlar tashlanadi.
Map<String, List<LatLng>> decodeWalkRoutes(String text) {
  final out = <String, List<LatLng>>{};
  final Object? raw;
  try {
    raw = jsonDecode(text);
  } on FormatException {
    return out;
  }
  if (raw is! Map) return out;
  for (final e in raw.entries) {
    final v = e.value;
    if (e.key is! String || v is! List || v.length.isOdd) continue;
    if (v.any((x) => x is! num)) continue;
    out[e.key as String] = [
      for (var i = 0; i < v.length; i += 2)
        (lat: (v[i] as num).toDouble(), lng: (v[i + 1] as num).toDouble()),
    ];
  }
  return out;
}
