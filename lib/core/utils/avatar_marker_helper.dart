import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AvatarMarkerHelper {
  static final Map<String, Uint8List> _networkImageCache = {};

  static Future<ui.Image?> _loadImage({
    String? photoUrl,
    String? assetPhotoPath,
  }) async {
    if (photoUrl != null &&
        photoUrl.isNotEmpty &&
        !photoUrl.contains('localhost') &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'))) {
      try {
        if (_networkImageCache.containsKey(photoUrl)) {
          final codec = await ui.instantiateImageCodec(
            _networkImageCache[photoUrl]!,
          );
          final fi = await codec.getNextFrame();
          return fi.image;
        }
        final dio = Dio();
        final response = await dio.get<List<int>>(
          photoUrl,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
          ),
        );
        if (response.data != null && response.data!.isNotEmpty) {
          final bytes = Uint8List.fromList(response.data!);
          _networkImageCache[photoUrl] = bytes;
          final codec = await ui.instantiateImageCodec(bytes);
          final fi = await codec.getNextFrame();
          return fi.image;
        }
      } catch (_) {}
    }

    if (assetPhotoPath != null) {
      try {
        final ByteData data = await rootBundle.load(assetPhotoPath);
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final ui.FrameInfo fi = await codec.getNextFrame();
        return fi.image;
      } catch (_) {}
    }

    return null;
  }

  /// Generates 100% Transparent PNG bytes for Yandex Map Placemark with real staff photo inside
  static Future<Uint8List> generateAvatarPinBytes({
    required String name,
    required Color statusColor,
    String? photoUrl,
    String? assetPhotoPath,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    const double width = 130.0;
    const double height = 150.0;
    const double cx = width / 2;
    const double cy = 56.0;
    const double radius = 44.0;

    // Load photo if available (from network URL or local asset)
    final ui.Image? loadedPhoto = await _loadImage(
      photoUrl: photoUrl,
      assetPhotoPath: assetPhotoPath,
    );

    // 1. Drop Shadow under pin pointer
    final Paint shadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final Path pinPath = Path();
    pinPath.addOval(
      Rect.fromCircle(center: const Offset(cx, cy), radius: radius),
    );
    pinPath.moveTo(cx - 14, cy + radius - 4);
    pinPath.lineTo(cx, height - 10);
    pinPath.lineTo(cx + 14, cy + radius - 4);
    pinPath.close();
    canvas.drawPath(pinPath, shadowPaint);

    // 2. Outer Ring & Bottom Pointer Fill (Green / Orange Status Color)
    final Paint pointerPaint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pointerPaint);

    // 3. Inner White Ring Border
    final Paint whiteBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), radius - 4, whiteBorder);

    // 4. Circular Avatar Content Clip
    canvas.save();
    final Path clipPath = Path()
      ..addOval(
        Rect.fromCircle(center: const Offset(cx, cy), radius: radius - 8),
      );
    canvas.clipPath(clipPath);

    if (loadedPhoto != null) {
      // Draw real person picture photo
      final Rect srcRect = Rect.fromLTWH(
        0,
        0,
        loadedPhoto.width.toDouble(),
        loadedPhoto.height.toDouble(),
      );
      final Rect dstRect = Rect.fromCircle(
        center: const Offset(cx, cy),
        radius: radius - 8,
      );
      canvas.drawImageRect(
        loadedPhoto,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      // Fallback: Gradient background with bold Initial
      final Paint bgPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - radius, cy - radius),
          Offset(cx + radius, cy + radius),
          const [Color(0xFF0D6E6E), Color(0xFF139797)],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

      final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'X';
      textPainter.text = TextSpan(
        text: initial,
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Outfit',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
      );
    }
    canvas.restore();

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  /// Generates clean minimalist Center Dot marker ("Oddiy nuqta") for Branch/Location Center
  static Future<Uint8List> generateOfficePinBytes() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    const double size = 56.0;
    const double center = size / 2;

    // 1. Translucent outer pulse ring (Teal #0D6E6E with 0.25 opacity)
    final Paint pulsePaint = Paint()
      ..color = const Color(0xFF0D6E6E).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(center, center), 26.0, pulsePaint);

    // 2. Drop Shadow under solid circle
    final Paint shadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(center, center + 1), 16.0, shadowPaint);

    // 3. White outer border ring
    final Paint whiteBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(center, center), 15.0, whiteBorder);

    // 4. Primary solid center dot (Teal #0D6E6E)
    final Paint centerDot = Paint()
      ..color = const Color(0xFF0D6E6E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(center, center), 10.5, centerDot);

    // 5. Inner white tiny point
    final Paint innerDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(center, center), 3.5, innerDot);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }
}
