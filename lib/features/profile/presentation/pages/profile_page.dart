import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/core/security/app_lock_service.dart';
import 'package:skore_hodimlar/core/security/security_settings_page.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';
import 'package:skore_hodimlar/core/services/auth_token_store.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/theme/theme_cubit.dart';
import 'package:skore_hodimlar/core/utils/work_days_formatter.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_ring.dart';
import 'package:skore_hodimlar/core/widgets/app_update_bottom_sheet.dart';
import 'package:skore_hodimlar/core/widgets/language_picker_bottom_sheet.dart';
import 'package:skore_hodimlar/core/widgets/notification_bell_button.dart';
import 'package:skore_hodimlar/core/widgets/pull_to_refresh.dart';
import 'package:skore_hodimlar/core/widgets/skor_logo_widget.dart';
import 'package:skore_hodimlar/core/widgets/theme_picker_bottom_sheet.dart';
import 'package:skore_hodimlar/features/profile/presentation/bloc/profile_bloc.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? phone;
  int? staffId;

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

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? context.colors.error
            : context.colors.primary,
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
                color: context.colors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: context.colors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('logout_confirmation_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          context.tr('logout_confirmation_desc'),
          style: TextStyle(fontSize: 15, color: context.colors.textSecondary),
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
              style: TextStyle(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.error,
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
    await FcmService.clearPrefsKeepingDeviceId(prefs);
    await FcmService.syncUserRole();
    await AppLockService.instance.clear();
    if (!mounted) return;
    context.read<ProfileBloc>().add(LogoutProfile());
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.colors.surface,
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
          style: TextStyle(
            color: context.colors.primary,
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
          if (state is ProfileLoading || state is ProfilePhoneChanging) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: context.colors.primary),
                  const SizedBox(height: 16),
                  Text(
                    state is ProfilePhoneChanging
                        ? context.tr('phone_updating')
                        : context.tr('profile_loading'),
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ],
              ),
            );
          }

          if (state is ProfileLoaded) {
            final profile = state.entity;

            return RefreshIndicator(
              onRefresh: () => refreshWithMinDelay(_loadData),
              color: context.colors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Top White Header with Avatar
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
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
                          AnimatedRotatingRing(
                            size: 110,
                            borderWidth: 3.5,
                            child: ClipOval(
                              child: Image.network(
                                state.photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.person,
                                      size: 60,
                                      color: context.colors.primary,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            profile.name.isNotEmpty
                                ? profile.name
                                : context.tr('user'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textPrimary,
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
                            icon: Icons.language_rounded,
                            title: context.tr('app_language'),
                            value:
                                '${context.currentAppLanguage.flag}  ${context.currentAppLanguage.title}',
                            onTap: () =>
                                LanguagePickerBottomSheet.show(context),
                          ),
                          _buildInfoTile(
                            icon: ThemePickerBottomSheet.iconFor(themeMode),
                            title: context.tr('app_theme'),
                            value: context.tr(
                              ThemePickerBottomSheet.labelKeyFor(themeMode),
                            ),
                            onTap: () => ThemePickerBottomSheet.show(context),
                          ),
                          _buildInfoTile(
                            icon: Icons.lock_outline_rounded,
                            title: context.tr('security_title'),
                            value: context.tr('security_subtitle'),
                            onTap: () => SecuritySettingsPage.open(context),
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
                                } else if (AppUpdateService.lastCheckFailed) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr('update_check_failed'),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr('latest_version_installed'),
                                      ),
                                      backgroundColor: context.colors.success,
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
                              icon: Icon(
                                Icons.logout_rounded,
                                color: context.colors.error,
                                size: 22,
                              ),
                              label: Text(
                                context.tr('logout'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.error,
                                  height: 1.2,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                side: BorderSide(
                                  color: context.colors.error,
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
        side: BorderSide(color: context.colors.divider),
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
              color: context.colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.colors.primary, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
          subtitle: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? context.colors.textPrimary,
            ),
          ),
          trailing:
              trailing ??
              (actionIcon != null
                  ? IconButton(
                      icon: Icon(actionIcon, color: context.colors.accent),
                      onPressed: onAction,
                    )
                  : (onTap != null
                        ? Icon(
                            Icons.chevron_right_rounded,
                            color: context.colors.textSecondary,
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
        side: BorderSide(color: context.colors.divider),
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
                    color: context.colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: context.colors.primary,
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
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
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
                            ? context.colors.primary
                            : context.colors.surfaceStrong,
                        borderRadius: BorderRadius.circular(10),
                        border: isToday
                            ? Border.all(
                                color: context.colors.warning,
                                width: 2.2,
                              )
                            : (isWorkDay
                                  ? null
                                  : Border.all(color: context.colors.border)),
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
                                      ? context.colors.textPrimary
                                      : context.colors.textHint),
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
