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

  /// Generates a clean fallback user pin marker (100% vector drawn, 0% checkerboard)
  static Future<Uint8List> generateDefaultPinBytes({
    Color color = const Color(0xFF0D6E6E),
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    const double width = 80.0;
    const double height = 96.0;
    const double cx = width / 2;
    const double cy = 36.0;
    const double radius = 28.0;

    // 1. Drop shadow
    final Paint shadowPaint = Paint()
      ..color = const Color(0x35000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final Path pinPath = Path();
    pinPath.addOval(
      Rect.fromCircle(center: const Offset(cx, cy), radius: radius),
    );
    pinPath.moveTo(cx - 10, cy + radius - 3);
    pinPath.lineTo(cx, height - 6);
    pinPath.lineTo(cx + 10, cy + radius - 3);
    pinPath.close();
    canvas.drawPath(pinPath, shadowPaint);

    // 2. Outer pin body
    final Paint pointerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pointerPaint);

    // 3. Inner white circle
    final Paint whiteBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), radius - 3.5, whiteBorder);

    // 4. Inner fill circle
    final Paint innerFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), radius - 6.5, innerFill);

    // 5. User icon silhouette: head + shoulders
    final Paint iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy - 5), 6.5, iconPaint);
    final Rect shoulderRect = Rect.fromCenter(
      center: const Offset(cx, cy + 9),
      width: 20,
      height: 14,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        shoulderRect,
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      iconPaint,
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  /// Generates Start Point ("A" boshlanish) marker for route history
  static Future<Uint8List> generateStartPinBytes() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    const double width = 64.0;
    const double height = 76.0;
    const double cx = width / 2;
    const double cy = 28.0;
    const double radius = 22.0;

    // Drop shadow
    final Paint shadowPaint = Paint()
      ..color = const Color(0x35000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final Path pinPath = Path();
    pinPath.addOval(
      Rect.fromCircle(center: const Offset(cx, cy), radius: radius),
    );
    pinPath.moveTo(cx - 8, cy + radius - 2);
    pinPath.lineTo(cx, height - 4);
    pinPath.lineTo(cx + 8, cy + radius - 2);
    pinPath.close();
    canvas.drawPath(pinPath, shadowPaint);

    // Green pin body
    final Paint pinPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // Inner white circle
    final Paint whiteCircle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), radius - 3.0, whiteCircle);

    // Green letter "A"
    final TextPainter tp = TextPainter(
      text: const TextSpan(
        text: 'A',
        style: TextStyle(
          color: Color(0xFF16A34A),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  /// Lokatsiya uzilishi belgisi markazining balandligi (rasm ichida, dp) —
  /// xaritada `anchor` shu nuqtaga qo'yiladi.
  static const double outageDotY = 11.0;
  static const double outageMarkerHeight = 44.0;

  /// Lokatsiya uzilishi belgisi (tomchisiz): chiziq ustida kichik doira va
  /// ostida vaqt. [start] — uzilgan joy (ichida "!"), aks holda qayta
  /// ulangan joy (bo'sh halqa).
  static Future<Uint8List> generateOutageMarkerBytes({
    required String time,
    required Color color,
    required bool start,
    double pixelRatio = 3,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const double width = 64.0;
    const double height = outageMarkerHeight;
    const double cx = width / 2;
    const double cy = outageDotY;
    canvas.scale(pixelRatio);

    final shadow = Paint()
      ..color = const Color(0x44000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    if (start) {
      canvas.drawCircle(const Offset(cx, cy + 1), 9, shadow);
      canvas.drawCircle(const Offset(cx, cy), 9, Paint()..color = color);
      canvas.drawCircle(
        const Offset(cx, cy),
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white,
      );
      final mark = TextPainter(
        text: const TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      mark.paint(canvas, Offset(cx - mark.width / 2, cy - mark.height / 2));
    } else {
      canvas.drawCircle(const Offset(cx, cy + 1), 6.5, shadow);
      canvas.drawCircle(const Offset(cx, cy), 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        const Offset(cx, cy),
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color,
      );
    }

    final tp = TextPainter(
      text: TextSpan(
        text: time,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(cx, 33),
        width: tp.width + 10,
        height: tp.height + 6,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(pill.shift(const Offset(0, 1)), shadow);
    canvas.drawRRect(pill, Paint()..color = Colors.white);
    canvas.drawRRect(
      pill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.6),
    );
    tp.paint(canvas, Offset(cx - tp.width / 2, 33 - tp.height / 2));

    final ui.Image img = await recorder.endRecording().toImage(
      (width * pixelRatio).ceil(),
      (height * pixelRatio).ceil(),
    );
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  /// To'xtash joyi metkasi: rangli pin ichida tartib raqami ("1", "2"...).
  static Future<Uint8List> generateNumberPinBytes({
    required String label,
    required Color color,
    double pixelRatio = 3,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Mantiqiy o'lcham (dp); rasm [pixelRatio] bilan aniq chiziladi.
    const double width = 44.0;
    const double height = 56.0;
    const double cx = width / 2;
    const double cy = 20.0;
    const double radius = 17.0;
    canvas.scale(pixelRatio);

    // Tomchi: yuqorida doira, pastga silliq uchli.
    final Path pin = Path()
      ..moveTo(cx, height - 3)
      ..cubicTo(
        cx - 4,
        height - 12,
        cx - radius,
        cy + radius * 0.75,
        cx - radius,
        cy,
      )
      ..arcToPoint(
        const Offset(cx + radius, cy),
        radius: const Radius.circular(radius),
      )
      ..cubicTo(
        cx + radius,
        cy + radius * 0.75,
        cx + 4,
        height - 12,
        cx,
        height - 3,
      )
      ..close();

    canvas.drawPath(
      pin.shift(const Offset(0, 1.5)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawPath(pin, Paint()..color = color);
    canvas.drawPath(
      pin,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: label.length > 2 ? 13 : 17,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    final ui.Image img = await recorder.endRecording().toImage(
      (width * pixelRatio).ceil(),
      (height * pixelRatio).ceil(),
    );
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  static Future<Uint8List> generateEndPinBytes() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    const double width = 64.0;
    const double height = 76.0;
    const double cx = width / 2;
    const double cy = 28.0;
    const double radius = 22.0;

    // Drop shadow
    final Paint shadowPaint = Paint()
      ..color = const Color(0x35000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final Path pinPath = Path();
    pinPath.addOval(
      Rect.fromCircle(center: const Offset(cx, cy), radius: radius),
    );
    pinPath.moveTo(cx - 8, cy + radius - 2);
    pinPath.lineTo(cx, height - 4);
    pinPath.lineTo(cx + 8, cy + radius - 2);
    pinPath.close();
    canvas.drawPath(pinPath, shadowPaint);

    // Teal / primary pin body
    final Paint pinPaint = Paint()
      ..color = const Color(0xFF0D6E6E)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // Inner white circle
    final Paint whiteCircle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), radius - 3.0, whiteCircle);

    // Teal letter "B"
    final TextPainter tp = TextPainter(
      text: const TextSpan(
        text: 'B',
        style: TextStyle(
          color: Color(0xFF0D6E6E),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }
}
