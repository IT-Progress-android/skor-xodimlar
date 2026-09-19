import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';

typedef OnCaptureBytes = void Function(Uint8List imageBytes);

enum _Stage { positioning, blink, capturing }

/// Live selfie widget that detects a face on the camera stream and captures
/// automatically once the face is centered and close enough — no shutter
/// button. Similar to bank face-verification flows.
class SelfieCameraWidget extends StatefulWidget {
  final OnCaptureBytes onCapture;

  const SelfieCameraWidget({super.key, required this.onCapture});

  @override
  State<SelfieCameraWidget> createState() => _SelfieCameraWidgetState();
}

class _SelfieCameraWidgetState extends State<SelfieCameraWidget>
    with WidgetsBindingObserver {
  static const _teal = Color(0xFF0D6E6E);
  // Consecutive good frames required before auto-capturing (~0.7s of stability).
  static const _requiredGoodFrames = 6;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      // Needed for eye-open probabilities used by the blink liveness check.
      enableClassification: true,
      enableTracking: false,
    ),
  );

  CameraController? _controller;
  CameraDescription? _camera;
  bool _initializing = true;
  bool _initInProgress = false;
  bool _detecting = false;
  bool _capturing = false;
  int _goodFrames = 0;
  String _status = '';
  String? _error;

  // Liveness: the user must be positioned, then blink once, before we capture.
  // This blocks a still photo / screenshot held up to the camera.
  _Stage _stage = _Stage.positioning;
  // Blink progress: 0 = need eyes open, 1 = eyes open seen, 2 = blink (close→open) done.
  int _blinkPhase = 0;
  static const _eyeOpen = 0.6;
  static const _eyeShut = 0.25;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        controller.dispose();
        _controller = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reset flag so _initCamera() can run again after user grants permission in Settings
      _initInProgress = false;
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_initInProgress) return;
    _initInProgress = true;

    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    if (!mounted) {
      _initInProgress = false;
      return;
    }
    setState(() {
      _initializing = true;
      _error = null;
      _capturing = false;
      _goodFrames = 0;
      _blinkPhase = 0;
      _stage = _Stage.positioning;
      _status = context.tr('selfie_position_face');
    });

    try {
      // First check current status without triggering a system dialog
      var camStatus = await Permission.camera.status;

      // Only request if not yet determined (first time)
      if (camStatus.isDenied) {
        camStatus = await Permission.camera.request();
      }

      if (!mounted) return;
      if (!camStatus.isGranted) {
        // Already permanently denied — just show our UI, don't call request()
        _fail(context.tr('selfie_camera_permission_denied'));
        return;
      }

      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        _fail(context.tr('selfie_camera_not_found'));
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = front;

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        // ML Kit needs a single-plane buffer: NV21 on Android, BGRA on iOS.
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      await controller.startImageStream(_processFrame);
    } catch (_) {
      if (!mounted) return;
      _fail(context.tr('selfie_camera_open_failed'));
    } finally {
      _initInProgress = false;
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _initializing = false;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_detecting || _capturing || !mounted) return;
    _detecting = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _faceDetector.processImage(input);
      _evaluate(faces, image);
    } catch (_) {
      // Ignore transient per-frame errors; the next frame retries.
    } finally {
      _detecting = false;
    }
  }

  void _evaluate(List<Face> faces, CameraImage image) {
    if (_capturing || _stage == _Stage.capturing || !mounted) return;

    // Face must be present, alone, centered and close enough in every stage.
    if (faces.isEmpty) {
      _reset(context.tr('selfie_face_not_detected'));
      return;
    }
    if (faces.length > 1) {
      _reset(context.tr('selfie_only_one_face'));
      return;
    }

    final face = faces.first;
    final box = face.boundingBox;
    final shortSide = math.min(image.width, image.height).toDouble();
    final faceSize = math.max(box.width, box.height);
    if (faceSize < shortSide * 0.40) {
      _reset(context.tr('selfie_come_closer'));
      return;
    }
    if (faceSize > shortSide * 1.05) {
      _reset(context.tr('selfie_move_back'));
      return;
    }

    if (_stage == _Stage.positioning) {
      _goodFrames++;
      _setStatus(context.tr('selfie_hold_still'));
      if (_goodFrames >= _requiredGoodFrames) {
        setState(() {
          _stage = _Stage.blink;
          _blinkPhase = 0;
        });
      }
      return;
    }

    // _Stage.blink — require a real open → closed → open eye transition so a
    // still photo held to the camera can't pass.
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) {
      _setStatus(context.tr('selfie_blink_once'));
      return;
    }
    final eyeOpenness = (left + right) / 2;

    if (_blinkPhase == 0) {
      if (eyeOpenness > _eyeOpen) _blinkPhase = 1;
      _setStatus(context.tr('selfie_blink_once'));
    } else if (_blinkPhase == 1) {
      if (eyeOpenness < _eyeShut) _blinkPhase = 2;
      _setStatus(context.tr('selfie_blink_once'));
    } else {
      if (eyeOpenness > _eyeOpen) {
        _autoCapture();
      }
    }
  }

  void _reset(String status) {
    _goodFrames = 0;
    _blinkPhase = 0;
    if (_stage != _Stage.positioning) {
      setState(() => _stage = _Stage.positioning);
    }
    _setStatus(status);
  }

  void _setStatus(String status) {
    if (status != _status && mounted) {
      setState(() => _status = status);
    }
  }

  Future<void> _autoCapture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    _capturing = true;
    if (mounted) {
      setState(() {
        _stage = _Stage.capturing;
        _status = context.tr('selfie_capturing');
      });
    }

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final file = await controller.takePicture();
      final bytes = await _compressSelfie(file.path);
      if (!mounted) return;
      widget.onCapture(bytes);
    } catch (_) {
      _capturing = false;
      if (mounted) {
        setState(() => _error = context.tr('selfie_capture_error'));
      }
    }
  }

  // Shrink + fix EXIF orientation before upload. The server ignores EXIF, so a
  // rotated selfie can fail face detection; oversize files just slow the request.
  Future<Uint8List> _compressSelfie(String path) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 800,
        minHeight: 800,
        quality: 75,
        autoCorrectionAngle: true,
        format: CompressFormat.jpeg,
      );
      if (result != null && result.isNotEmpty) return result;
    } catch (_) {
      // Fall through to the raw file bytes if native compressor is unavailable.
    }
    return File(path).readAsBytes();
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    final camera = _camera;
    if (controller == null || camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        compensation = (sensorOrientation + compensation) % 360;
      } else {
        compensation = (sensorOrientation - compensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  // Fills the circle while preserving the camera's aspect ratio (no stretch).
  Widget _buildPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        // previewSize is reported in landscape; swap for a portrait layout.
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    if (_error != null || _controller == null) {
      final isPermissionError =
          _error == context.tr('selfie_camera_permission_denied');
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_photography, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  isPermissionError
                      ? context.tr('selfie_permission_denied_desc')
                      : (_error ?? context.tr('selfie_camera_unavailable')),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                if (isPermissionError) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: openAppSettings,
                    child: Text(
                      context.tr('selfie_open_settings'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _initCamera,
                    child: Text(
                      context.tr('retry'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ] else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _initCamera,
                    child: Text(
                      context.tr('retry'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (_capturing || _stage == _Stage.capturing) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: _teal,
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('checkin_verifying_face'),
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Ring: teal while positioning, amber during the blink check,
    // green once capturing.
    final Color ringColor = _stage == _Stage.blink
        ? const Color(0xFFF5A623)
        : _teal;

    final String heading;
    if (_stage == _Stage.blink) {
      heading = context.tr('selfie_close_eyes');
    } else if (_status == context.tr('selfie_come_closer') ||
        _status == context.tr('selfie_move_back')) {
      heading = _status;
    } else {
      heading = context.tr('selfie_hold_in_circle');
    }

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                heading,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 4),
                ),
                child: ClipOval(child: _buildPreview(_controller!)),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
