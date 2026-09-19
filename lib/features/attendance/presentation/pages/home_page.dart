import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/utils/date_formatter.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_ring.dart';
import 'package:skore_hodimlar/core/widgets/location_disclosure_dialog.dart';
import 'package:skore_hodimlar/core/widgets/notification_bell_button.dart';
import 'package:skore_hodimlar/core/widgets/shimmer_loading_widget.dart';
import 'package:skore_hodimlar/core/widgets/skor_logo_widget.dart';
import 'package:skore_hodimlar/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:skore_hodimlar/features/attendance/presentation/widgets/check_in_button.dart';
import 'package:skore_hodimlar/features/profile/presentation/bloc/profile_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _phone;

  @override
  void initState() {
    super.initState();
    _loadToday();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestLocationPermission();
      AppUpdateService.checkAndShowUpdate(context);
    });
  }

  Future<void> _checkAndRequestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        if (!mounted) return;
        final accepted = await LocationDisclosureDialog.show(context);
        if (!accepted) return;
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        if (_phone != null) {
          unawaited(
            GpsLiveTrackerService.instance.startTracking(phone: _phone),
          );
        }
        await _requestBackgroundLocation(perm);
      }
    } catch (_) {}
  }

  /// Fon rejimidagi joylashuv ("Doim ruxsat berish") so'rovi.
  ///
  /// Android 11+ da bu ruxsatni oldingi (whileInUse) ruxsat berilgandan keyin,
  /// alohida so'rash shart — bitta dialogda ikkalasini so'rab bo'lmaydi.
  /// Ilgari bu umuman so'ralmasdi: manifestda ACCESS_BACKGROUND_LOCATION
  /// e'lon qilingan va Google Play talab qiladigan rozilik oynasi
  /// ko'rsatilardi, lekin ruxsatning o'zi hech qachon berilmagani uchun
  /// ilova yopilganda geofence kuzatuvi ishlamay qolardi.
  Future<void> _requestBackgroundLocation(LocationPermission current) async {
    if (!Platform.isAndroid) return;
    if (current == LocationPermission.always) return;

    // Foydalanuvchi bir marta rad etgan bo'lsa, har safar bezovta qilmaymiz.
    final prefs = sl<SharedPreferences>();
    const askedKey = 'asked_background_location';
    if (prefs.getBool(askedKey) ?? false) return;

    final status = await Permission.locationAlways.status;
    if (status.isGranted) return;

    await prefs.setBool(askedKey, true);
    await Permission.locationAlways.request();
  }

  void _loadToday() {
    final prefs = sl<SharedPreferences>();
    _phone = prefs.getString('phone') ?? prefs.getString('staff_phone');
    final staffId = prefs.getInt('staff_id');
    if (_phone != null) {
      context.read<AttendanceBloc>().add(LoadTodayAttendance(_phone!));
      context.read<ProfileBloc>().add(LoadProfile(_phone!, staffId: staffId));
      GpsLiveTrackerService.instance.startTracking(phone: _phone);
      FcmService.registerTokenOnBackend(phone: _phone, staffId: staffId);
    }
  }

  Future<void> _handleCheckInPressed(bool isCheckIn) async {
    await context.push('/check-in', extra: isCheckIn);
    if (mounted) _loadToday();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: Tooltip(
              message: context.tr('refresh'),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _loadToday,
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: SkorLogoWidget(
                    size: 34,
                    showText: false,
                    animateParticles: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Skor Xodimlar',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D6E6E),
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: const [NotificationBellButton()],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: () async => _loadToday(),
            color: const Color(0xFF0D6E6E),
            child: BlocBuilder<AttendanceBloc, AttendanceState>(
              builder: (context, state) {
                if (state is AttendanceLoading) {
                  return const HomeShimmerWidget();
                }
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 10,
                    bottom: 6,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreetingCard(),
                        const SizedBox(height: 12),
                        _buildMainCard(),
                        const SizedBox(height: 14),
                        _buildPendingRequestBanner(),
                        _buildActionArea(),
                        const SizedBox(height: 14),
                        _buildTodayTimelineCard(),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGreetingCard() {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        final prefs = sl<SharedPreferences>();
        final profileFullName =
            (prefs.getString('staff_full_name') ??
                    prefs.getString('staff_name') ??
                    '')
                .trim();

        String rawName = '';
        if (profileFullName.isNotEmpty && profileFullName != 'Xodim') {
          rawName = profileFullName;
        } else if (state is TodayAttendanceLoaded &&
            state.entity.staffName.trim().isNotEmpty) {
          rawName = state.entity.staffName.trim();
        }

        // Clean display name (if "Eshmatov Begzod", extract "Begzod")
        String displayName = rawName;
        if (rawName.contains(' ')) {
          final parts = rawName
              .split(RegExp(r'\s+'))
              .where((p) => p.isNotEmpty)
              .toList();
          if (parts.length >= 2) {
            final first = parts[0];
            final second = parts[1];
            final firstLower = first.toLowerCase();
            if (firstLower.endsWith('ov') ||
                firstLower.endsWith('ova') ||
                firstLower.endsWith('yev') ||
                firstLower.endsWith('yeva') ||
                firstLower.endsWith('eva')) {
              displayName = second;
            } else {
              displayName = first;
            }
          }
        }

        final now = DateTime.now();
        final formattedDate =
            '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D6E6E), Color(0xFF139797)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D6E6E).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isNotEmpty
                    ? context.tr('home_greeting_named', {'name': displayName})
                    : context.tr('home_greeting'),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('home_today_date', {'date': formattedDate}),
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainCard() {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        if (state is AttendanceLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0D6E6E)),
          );
        } else if (state is TodayAttendanceLoaded) {
          final data = state.entity;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  data.smena,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('home_today_attendance_time', {
                    'time': data.smenaStart,
                  }),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: data.inside
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: data.inside ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        data.inside
                            ? context.tr('home_currently_working')
                            : context.tr('home_not_working'),
                        style: TextStyle(
                          color: data.inside
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTimeColumn(
                      context.tr('attendance_check_in_label'),
                      data.checkIn?.time ?? '--:--',
                      Icons.login_rounded,
                      const Color(0xFF0D6E6E),
                    ),
                    _buildTimeColumn(
                      context.tr('attendance_check_out_label'),
                      data.checkOut?.time ?? '--:--',
                      Icons.logout_rounded,
                      const Color(0xFFF5A623),
                    ),
                  ],
                ),
                if (data.delay != null && data.delay!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      context.tr('home_delay_label', {
                        'delay': DateFormatter.formatDelayToHours(data.delay),
                      }),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        } else if (state is AttendanceError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildTimeColumn(
    String label,
    String time,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  /// Yuz tekshiruvisiz belgilangan davomat rahbar tasdig'ini kutayotgan
  /// bo'lsa, buni bosh ekranda ko'rsatamiz. Aks holda xodim davomat vaqti
  /// bo'sh turganini ko'rib, yana "Keldim" bosaverardi.
  Widget _buildPendingRequestBanner() {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        if (state is! TodayAttendanceLoaded) return const SizedBox.shrink();
        final pending = state.entity.pendingRequests;
        if (pending.isEmpty) return const SizedBox.shrink();

        final first = pending.first;
        final label = first.isIn
            ? context.tr('attendance_check_in_label')
            : context.tr('attendance_check_out_label');

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5A623).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF5A623).withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                color: Color(0xFFB45309),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home_pending_request', {'label': label}),
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    if (first.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.tr('home_sent_at', {
                          'date': '${first.createdAt}',
                        }),
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionArea() {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        bool isCheckIn = true;
        if (state is TodayAttendanceLoaded) {
          final e = state.entity;
          if (e.next == 'ketdim' ||
              (e.checkIn?.time != null && e.checkOut?.time == null)) {
            isCheckIn = false;
          }
        }

        return CheckInButton(
          isCheckIn: isCheckIn,
          onPressed: () => _handleCheckInPressed(isCheckIn),
        );
      },
    );
  }

  Widget _buildTodayTimelineCard() {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        if (state is! TodayAttendanceLoaded) {
          return const SizedBox.shrink();
        }

        final data = state.entity;
        final hasCheckIn =
            data.checkIn?.time != null && data.checkIn!.time!.isNotEmpty;
        final hasCheckOut =
            data.checkOut?.time != null && data.checkOut!.time!.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const AnimatedRotatingRing(
                        size: 32,
                        borderWidth: 1.5,
                        gradientColors: [
                          Color(0xFF0D6E6E),
                          Color(0xFF139797),
                          Color(0xFF26BBAA),
                          Color(0xFF0D6E6E),
                        ],
                        child: Center(
                          child: Icon(
                            Icons.history_toggle_off_rounded,
                            color: Color(0xFF0D6E6E),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('home_timeline_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 14),

              // Scrollable Constrained Timeline Area (Option 1)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Timeline Check-In Item
                      _buildTimelineItem(
                        title: context.tr('home_check_in_title'),
                        subtitle: hasCheckIn
                            ? context.tr('home_check_in_recorded')
                            : context.tr('home_check_in_not_recorded'),
                        time: data.checkIn?.time ?? '--:--',
                        icon: Icons.login_rounded,
                        iconColor: const Color(0xFF0D6E6E),
                        bgColor: const Color(
                          0xFF0D6E6E,
                        ).withValues(alpha: 0.12),
                        isActive: hasCheckIn,
                      ),

                      // Connector Line
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 19,
                          top: 4,
                          bottom: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 2,
                            height: 24,
                            color: hasCheckOut
                                ? const Color(0xFFF5A623)
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),

                      // Timeline Check-Out Item
                      _buildTimelineItem(
                        title: context.tr('home_check_out_title'),
                        subtitle: hasCheckOut
                            ? context.tr('home_check_out_recorded')
                            : context.tr('home_check_out_not_recorded'),
                        time: data.checkOut?.time ?? '--:--',
                        icon: Icons.logout_rounded,
                        iconColor: const Color(0xFFF5A623),
                        bgColor: const Color(
                          0xFFF5A623,
                        ).withValues(alpha: 0.12),
                        isActive: hasCheckOut,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isActive,
  }) {
    final iconWidget = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isActive ? bgColor : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isActive ? iconColor : Colors.grey.shade400,
        size: 19,
      ),
    );

    return Row(
      children: [
        isActive
            ? AnimatedRotatingRing(
                size: 42,
                borderWidth: 2,
                gradientColors: (iconColor == const Color(0xFFF5A623))
                    ? const [
                        Color(0xFFF5A623),
                        Color(0xFFFBBF24),
                        Color(0xFFD97706),
                        Color(0xFFF5A623),
                      ]
                    : const [
                        Color(0xFF0D6E6E),
                        Color(0xFF139797),
                        Color(0xFF26BBAA),
                        Color(0xFF0D6E6E),
                      ],
                child: iconWidget,
              )
            : SizedBox(width: 42, height: 42, child: Center(child: iconWidget)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? bgColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isActive ? iconColor : Colors.grey.shade400,
            ),
          ),
        ),
      ],
    );
  }
}
