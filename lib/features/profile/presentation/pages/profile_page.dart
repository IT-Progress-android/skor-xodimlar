import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';
import 'package:skore_hodimlar/core/services/auth_token_store.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/utils/work_days_formatter.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_ring.dart';
import 'package:skore_hodimlar/core/widgets/app_update_bottom_sheet.dart';
import 'package:skore_hodimlar/core/widgets/language_picker_bottom_sheet.dart';
import 'package:skore_hodimlar/core/widgets/notification_bell_button.dart';
import 'package:skore_hodimlar/core/widgets/skor_logo_widget.dart';
import 'package:skore_hodimlar/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:skore_hodimlar/features/profile/domain/entities/profile_entity.dart';
import 'package:skore_hodimlar/features/profile/presentation/bloc/profile_bloc.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? phone;
  int? staffId;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    AppUpdateService.init().then((_) {
      if (mounted) setState(() {});
    });
    final prefs = sl<SharedPreferences>();
    phone = prefs.getString('phone') ?? prefs.getString('staff_phone');
    staffId = prefs.getInt('staff_id');
    if (phone != null && mounted) {
      context.read<ProfileBloc>().add(LoadProfile(phone!, staffId: staffId));
    }
  }

  Future<void> _pickAndUploadPhoto(
    ImageSource source,
    ProfileEntity profile,
  ) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        final file = File(image.path);
        context.read<ProfileBloc>().add(
          UploadPhotoSubmitted(
            phone: profile.phone,
            staffId: profile.id,
            photoFile: file,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('${context.tr('photo_picker_error')}: $e');
      }
    }
  }

  void _showPhotoPicker(ProfileEntity profile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primary,
              ),
              title: Text(context.tr('camera_photo')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(ImageSource.camera, profile);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: Text(context.tr('gallery_photo')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(ImageSource.gallery, profile);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('logout_confirmation_title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          context.tr('logout_confirmation_desc'),
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.tr('logout'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // GPS kuzatuvini va foreground xizmatni
    // to'xtatamiz — aks holda chiqqandan keyin ham
    // lokatsiya serverga yuborilaverardi.
    await GpsLiveTrackerService.instance.stopTracking();
    // Tokenni serverda ham bekor qilamiz
    // (lokal o'chirish yetarli emas).
    await AuthTokenStore.instance.revokeAndClear(sl<DioClient>().dio);
    await FcmService.deleteTokenFromBackend(phone: phone, staffId: staffId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FcmService.syncUserRole();
    if (!mounted) return;
    context.read<ProfileBloc>().add(LogoutProfile());
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                onTap: _loadData,
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
          context.tr('profile_title'),
          style: const TextStyle(
            color: Color(0xFF0D6E6E),
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: const [NotificationBellButton()],
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileInitial) {
            context.go('/login');
          } else if (state is ProfileError) {
            _showSnackBar(state.message);
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading ||
              state is ProfilePhotoUploading ||
              state is ProfilePhoneChanging) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    state is ProfilePhotoUploading
                        ? context.tr('photo_uploading')
                        : state is ProfilePhoneChanging
                        ? context.tr('phone_updating')
                        : context.tr('profile_loading'),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          if (state is ProfileLoaded) {
            final profile = state.entity;
            final attState = context.watch<AttendanceBloc>().state;
            bool isKelgan = false;
            if (attState is TodayAttendanceLoaded) {
              final today = attState.entity;
              isKelgan =
                  today.inside ||
                  (today.checkIn?.time != null &&
                      today.checkIn!.time!.isNotEmpty) ||
                  today.events.any((e) => e.isIn);
            }
            final bool isFaceActive =
                profile.hasFace || profile.hasPhoto || isKelgan;

            return RefreshIndicator(
              onRefresh: () async => _loadData(),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Top White Header with Avatar
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.only(
                        top: 24,
                        bottom: 28,
                        left: 24,
                        right: 24,
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (profile.editable.contains('photo')) {
                                _showPhotoPicker(profile);
                              }
                            },
                            child: AnimatedRotatingRing(
                              size: 110,
                              borderWidth: 3.5,
                              child: ClipOval(
                                child: Image.network(
                                  state.photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: AppColors.primary,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            profile.name.isNotEmpty
                                ? profile.name
                                : context.tr('user'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Details List - Only render fields provided by backend
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (profile.phonePretty.isNotEmpty)
                            _buildInfoTile(
                              icon: Icons.phone_android_rounded,
                              title: context.tr('phone_number'),
                              value: profile.phonePretty,
                            ),
                          if (profile.tashkilot != null &&
                              profile.tashkilot!.isNotEmpty)
                            _buildInfoTile(
                              icon: Icons.business_rounded,
                              title: context.tr('organization'),
                              value: profile.tashkilot!,
                            ),
                          if (profile.lavozim != null &&
                              profile.lavozim!.isNotEmpty)
                            _buildInfoTile(
                              icon: Icons.work_rounded,
                              title: context.tr('position'),
                              value: profile.lavozim!,
                            ),
                          if (profile.boLim != null &&
                              profile.boLim!.isNotEmpty)
                            _buildInfoTile(
                              icon: Icons.corporate_fare_rounded,
                              title: context.tr('department'),
                              value: profile.boLim!,
                            ),
                          if (profile.smena != null &&
                              profile.smena!.isNotEmpty)
                            _buildInfoTile(
                              icon: Icons.access_time_filled_rounded,
                              title: context.tr('shift'),
                              value: profile.smena!,
                            ),
                          if (profile.workDays.isNotEmpty)
                            _buildWorkDaysTile(profile.workDays),
                          _buildInfoTile(
                            icon: Icons.face_retouching_natural_rounded,
                            title: context.tr('face_verify'),
                            value: isFaceActive
                                ? context.tr('face_configured')
                                : context.tr('face_not_configured'),
                            valueColor: isFaceActive
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          _buildInfoTile(
                            icon: Icons.language_rounded,
                            title: context.tr('app_language'),
                            value:
                                '${context.currentAppLanguage.flag}  ${context.currentAppLanguage.title}',
                            onTap: () =>
                                LanguagePickerBottomSheet.show(context),
                          ),
                          _buildInfoTile(
                            icon: Icons.system_update_rounded,
                            title: context.tr('app_version'),
                            value: 'v${AppUpdateService.currentVersion}',
                            actionIcon: Icons.refresh_rounded,
                            onAction: () async {
                              final update =
                                  await AppUpdateService.checkUpdate();
                              if (context.mounted) {
                                if (update != null) {
                                  unawaited(
                                    AppUpdateBottomSheet.show(
                                      context,
                                      updateInfo: update,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr('latest_version_installed'),
                                      ),
                                      backgroundColor: const Color(0xFF16A34A),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 24),

                          // Logout Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _handleLogout,
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: AppColors.error,
                                size: 22,
                              ),
                              label: Text(
                                context.tr('logout'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                  height: 1.2,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                side: const BorderSide(
                                  color: AppColors.error,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
    IconData? actionIcon,
    VoidCallback? onAction,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          subtitle: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          trailing:
              trailing ??
              (actionIcon != null
                  ? IconButton(
                      icon: Icon(actionIcon, color: AppColors.accent),
                      onPressed: onAction,
                    )
                  : (onTap != null
                        ? const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary,
                          )
                        : null)),
        ),
      ),
    );
  }

  Widget _buildWorkDaysTile(List<String> rawDays) {
    final activeDays = WorkDaysFormatter.parse(rawDays);
    if (activeDays.isEmpty) return const SizedBox.shrink();

    final summary = WorkDaysFormatter.formatSummary(rawDays, context);
    final today = Weekday.today;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('work_days'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final double chipWidth = ((constraints.maxWidth - (6 * 6)) / 7)
                    .floorToDouble();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: Weekday.values.map((day) {
                    final isWorkDay = activeDays.contains(day);
                    final isToday = day == today;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: chipWidth,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isWorkDay
                            ? AppColors.primary
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: isToday
                            ? Border.all(
                                color: const Color(0xFFF59E0B),
                                width: 2.2,
                              )
                            : (isWorkDay
                                  ? null
                                  : Border.all(color: const Color(0xFFE2E8F0))),
                        boxShadow: isToday
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          day.getMiniName(context),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: (isWorkDay || isToday)
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isWorkDay
                                ? Colors.white
                                : (isToday
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
