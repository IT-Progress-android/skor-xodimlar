import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/core/widgets/location_disclosure_dialog.dart';
import 'package:skore_hodimlar/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:skore_hodimlar/features/face_verify/presentation/bloc/face_verify_bloc.dart';
import 'package:skore_hodimlar/features/face_verify/presentation/widgets/selfie_camera_widget.dart';

class CheckInPage extends StatefulWidget {
  final bool isCheckIn;
  const CheckInPage({super.key, required this.isCheckIn});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  int _step = 1;

  String? _phone;
  int? _staffId;
  double? _lat;
  double? _lng;
  bool _isMock = false;
  String? _errorOverride;

  String? _verifyToken;

  bool _engineDown = false;
  String _engineDownMessage = '';
  bool _fallbackUsed = false;

  /// Tizimda xodimning etalon rasmi bormi (profil javobidagi `has_photo`).
  /// Ma'lumot hali yuklanmagan bo'lsa `true` deb olamiz — kamera ochiladi va
  /// oqim avvalgidek davom etadi.
  late final bool _hasReferencePhoto =
      sl<SharedPreferences>().getBool('has_reference_photo') ?? true;

  Future<void> _onCapture(Uint8List imageBytes) async {
    setState(() {
      _step = 2;
      _errorOverride = null;
    });

    final prefs = sl<SharedPreferences>();
    final phone = prefs.getString('phone') ?? prefs.getString('staff_phone');
    if (phone == null) {
      setState(() {
        _errorOverride = context.tr('checkin_user_not_found');
        _step = 4;
      });
      return;
    }
    _phone = phone;
    _staffId = prefs.getInt('staff_id');

    try {
      final position = await _determinePosition();
      if (position != null) {
        _lat = position.latitude;
        _lng = position.longitude;
        _isMock = position.isMocked;
      } else {
        _lat = 0.0;
        _lng = 0.0;
        _isMock = false;
      }
    } catch (_) {
      _lat = 0.0;
      _lng = 0.0;
      _isMock = false;
    }

    if (!mounted) return;
    context.read<FaceVerifyBloc>().add(
      VerifyFace(
        phone: _phone!,
        imageBytes: imageBytes,
        staffId: _staffId?.toString(),
      ),
    );
  }

  Future<Position?> _determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return null;
        final accepted = await LocationDisclosureDialog.show(context);
        if (!accepted) return null;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkStep = _step <= 3;

    return Scaffold(
      backgroundColor: isDarkStep ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isCheckIn
              ? context.tr('checkin_confirm_checkin_title')
              : context.tr('checkin_confirm_checkout_title'),
        ),
        backgroundColor: isDarkStep ? Colors.black : Colors.white,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkStep ? Colors.white : Colors.black,
        ),
        titleTextStyle: TextStyle(
          color: isDarkStep ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<FaceVerifyBloc, FaceVerifyState>(
            listener: (context, state) {
              if (state is FaceVerifyMatched) {
                _verifyToken = state.entity.verifyToken;
                setState(() {
                  _step = 3;
                });
                if (_phone == null || _lat == null || _lng == null) {
                  setState(() {
                    _errorOverride = context.tr('checkin_incomplete_data');
                    _step = 4;
                  });
                  return;
                }
                if (widget.isCheckIn) {
                  context.read<AttendanceBloc>().add(
                    CheckInSubmit(
                      _phone!,
                      _lat!,
                      _lng!,
                      verifyToken: _verifyToken,
                      isMock: _isMock,
                    ),
                  );
                } else {
                  context.read<AttendanceBloc>().add(
                    CheckOutSubmit(
                      _phone!,
                      _lat!,
                      _lng!,
                      verifyToken: _verifyToken,
                      isMock: _isMock,
                    ),
                  );
                }
              } else if (state is FaceVerifyEngineDown) {
                setState(() {
                  _engineDown = true;
                  _engineDownMessage = state.message;
                  _step = 4;
                });
              } else if (state is FaceVerifyNotMatched ||
                  state is FaceVerifyError) {
                setState(() {
                  _step = 4;
                });
              }
            },
          ),
          BlocListener<AttendanceBloc, AttendanceState>(
            listener: (context, state) {
              if (state is CheckLocationSuccess ||
                  state is CheckLocationTooFar ||
                  state is CheckLocationPendingReview ||
                  state is AttendanceError) {
                setState(() {
                  _step = 4;
                });
              }
            },
          ),
        ],
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        // Tizimda etalon rasm bo'lmasa selfi olishdan foyda yo'q — yuz
        // tekshiruvi baribir muvaffaqiyatsiz bo'ladi. Foydalanuvchini
        // behuda ovora qilmasdan, holatni tushuntiramiz.
        if (!_hasReferencePhoto) return _buildNoFaceProfileNotice();
        return SelfieCameraWidget(onCapture: _onCapture);
      case 2:
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
                    color: Color(0xFF0D6E6E),
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
      case 3:
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
                    color: Color(0xFF0D6E6E),
                    strokeWidth: 3.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('checkin_verifying_location'),
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
      case 4:
        return _buildResult();
      default:
        return const SizedBox();
    }
  }

  void _retry() {
    setState(() {
      _errorOverride = null;
      _engineDown = false;
      _fallbackUsed = false;
      _verifyToken = null;
      _lat = null;
      _lng = null;
      _step = 1;
    });
  }

  Future<void> _useLocationFallback() async {
    setState(() {
      _engineDown = false;
      _step = 3;
      _errorOverride = null;
    });

    final prefs = sl<SharedPreferences>();
    final phone = prefs.getString('phone') ?? prefs.getString('staff_phone');
    if (phone == null) {
      setState(() {
        _errorOverride = context.tr('checkin_user_not_found');
        _step = 4;
      });
      return;
    }
    _phone = phone;
    _staffId = prefs.getInt('staff_id');

    try {
      final position = await _determinePosition();
      _lat = position?.latitude ?? 0.0;
      _lng = position?.longitude ?? 0.0;
      _isMock = position?.isMocked ?? false;
    } catch (_) {
      _lat = 0.0;
      _lng = 0.0;
      _isMock = false;
    }

    if (!mounted) return;
    setState(() {
      _fallbackUsed = true;
    });

    if (widget.isCheckIn) {
      context.read<AttendanceBloc>().add(
        CheckInSubmit(_phone!, _lat!, _lng!, isMock: _isMock),
      );
    } else {
      context.read<AttendanceBloc>().add(
        CheckOutSubmit(_phone!, _lat!, _lng!, isMock: _isMock),
      );
    }
  }

  Widget _buildResult() {
    if (_engineDown) {
      return _buildEngineDownResult();
    }

    final faceState = context.read<FaceVerifyBloc>().state;
    final attState = context.read<AttendanceBloc>().state;

    bool success = true;
    String message = _fallbackUsed
        ? context.tr('checkin_marked_by_location')
        : context.tr('checkin_saved_successfully');
    String subMessage = '';
    bool canRetry = false;

    if (_errorOverride != null) {
      success = false;
      message = AppErrorFormatter.sanitizeMessage(_errorOverride!);
      canRetry = true;
    } else if (faceState is FaceVerifyNotMatched) {
      success = false;
      message = AppErrorFormatter.sanitizeMessage(
        faceState.message.isNotEmpty
            ? faceState.message
            : context.tr('checkin_face_not_matched'),
      );
      if (faceState.entity?.errorCode == 'NO_FACE_REF') {
        subMessage = context.tr('checkin_face_invalid_ref');
      } else if (faceState.entity?.status == 'photo_missing') {
        subMessage = context.tr('checkin_face_photo_missing');
      }
      canRetry = faceState.retryable;
    } else if (faceState is FaceVerifyError) {
      success = false;
      message = AppErrorFormatter.sanitizeMessage(
        faceState.message.isNotEmpty
            ? faceState.message
            : context.tr('checkin_face_verify_error'),
      );
      canRetry = true;
    }

    if (attState is CheckLocationTooFar) {
      success = false;
      final e = attState.entity;
      final masofa = e.distanceM;
      final ruxsat = e.allowedM;
      if (masofa != null && masofa > 1000) {
        message = context.tr('checkin_too_far_km', {
          'km': (masofa / 1000).toStringAsFixed(1),
        });
      } else if (masofa != null && ruxsat != null) {
        message = context.tr('checkin_get_closer_m', {
          'meters': (masofa - ruxsat).round().toString(),
        });
      } else if (e.distance != null) {
        message = context.tr('checkin_outside_zone_distance', {
          'distance': '${e.distance}',
        });
      } else {
        message = context.tr('checkin_outside_zone');
      }
      canRetry = true;
    } else if (attState is AttendanceError) {
      success = false;
      message = AppErrorFormatter.sanitizeMessage(
        attState.message.isNotEmpty
            ? attState.message
            : context.tr('checkin_save_error'),
      );
      canRetry = true;
    }

    // Yuz tekshiruvisiz belgilangan davomat darhol yozilmaydi — server uni
    // rahbar tasdig'iga yuboradi (HTTP 202 + status: pending_review).
    // Foydalanuvchiga "belgilandi" deb aytish noto'g'ri bo'lardi.
    if (attState is CheckLocationPendingReview) {
      success = true;
      canRetry = false;
      final e = attState.entity;
      message = e.message.isNotEmpty
          ? e.message
          : context.tr('checkin_pending_review_sent');
      subMessage = e.requestId != null
          ? context.tr('checkin_pending_review_id', {'id': '${e.requestId}'})
          : context.tr('checkin_pending_review_note');
    }

    // On a successful record, show the exact time the server saved (and note if
    // it was already recorded) — §5.2A.
    if (success && !_fallbackUsed && attState is CheckLocationSuccess) {
      final e = attState.entity;
      if (e.duplicate) {
        message = e.eventTime != null
            ? context.tr('checkin_already_recorded', {'time': e.eventTime!})
            : context.tr('checkin_already_recorded_generic');
      } else if (e.eventTime != null) {
        message = context.tr('checkin_recorded_success', {
          'time': e.eventTime!,
        });
      }
    }

    if (message.trim().isEmpty) {
      message = context.tr('generic_error_retry');
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: success ? Colors.black87 : Colors.red.shade900,
              ),
            ),
            if (subMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                subMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 40),
            if (!success && canRetry)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6E6E),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _retry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  context.tr('retry'),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            if (!success && canRetry) const SizedBox(height: 12),
            (!success && canRetry)
                ? TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      context.tr('checkin_back_to_main'),
                      style: const TextStyle(
                        color: Color(0xFF0D6E6E),
                        fontSize: 16,
                      ),
                    ),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6E6E),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => context.pop(),
                    child: Text(
                      context.tr('checkin_back_to_main'),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  /// Tizimda etalon yuz rasmi yo'q xodim uchun tushuntirish ekrani.
  Widget _buildNoFaceProfileNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_accounts_rounded,
              color: Color(0xFFF5A623),
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('checkin_no_photo_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('checkin_no_photo_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6E6E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _useLocationFallback,
              icon: const Icon(Icons.location_on, color: Colors.white),
              label: Text(
                context.tr('checkin_mark_by_location'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                context.tr('checkin_back_to_main'),
                style: const TextStyle(color: Color(0xFF0D6E6E), fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineDownResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Color(0xFFF5A623), size: 80),
            const SizedBox(height: 24),
            Text(
              _engineDownMessage.isNotEmpty
                  ? _engineDownMessage
                  : context.tr('checkin_engine_down'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('checkin_engine_down_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6E6E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _useLocationFallback,
              icon: const Icon(Icons.location_on, color: Colors.white),
              label: Text(
                context.tr('checkin_mark_by_location'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                context.tr('checkin_back_to_main'),
                style: const TextStyle(color: Color(0xFF0D6E6E), fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
