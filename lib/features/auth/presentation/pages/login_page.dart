import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/enums/user_role.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_cubit.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';
import 'package:skore_hodimlar/core/services/auth_token_store.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/services/language_sync_service.dart';
import 'package:skore_hodimlar/core/utils/phone_formatter.dart';
import 'package:skore_hodimlar/core/widgets/language_picker_bottom_sheet.dart';
import 'package:skore_hodimlar/core/widgets/skor_logo_widget.dart';
import 'package:skore_hodimlar/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  UserRole _selectedRole = UserRole.staff;
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final TextEditingController _adminLoginController = TextEditingController();
  final TextEditingController _adminPasswordController =
      TextEditingController();
  bool _obscurePassword = true;

  final ScrollController _scrollController = ScrollController();
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart),
        );
    _animController.forward();

    _phoneFocusNode.addListener(() {
      if (_phoneFocusNode.hasFocus) {
        if (_phoneController.text.isEmpty) {
          _phoneController.text = '+998 ';
          _phoneController.selection = const TextSelection.collapsed(offset: 5);
        }
      } else {
        if (_phoneController.text.trim() == '+998') {
          _phoneController.clear();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkAndShowUpdate(context);
      _showLogoutReasonIfAny();
    });
  }

  /// Server bizni 401 bilan chiqarib yuborgan bo'lsa, sababini tushuntiramiz.
  /// Aks holda foydalanuvchi "o'zim chiqmadim-ku" deb hayron bo'ladi.
  void _showLogoutReasonIfAny() {
    final reason = AuthTokenStore.instance.takeLogoutReason();
    if (reason == null || !mounted) return;

    final message = switch (reason) {
      'logged_in_elsewhere' => context.tr('login_logout_reason_elsewhere'),
      _ => context.tr('login_session_expired'),
    };
    _showSnackBar(message);
  }

  @override
  void dispose() {
    _phoneFocusNode.dispose();
    _phoneController.dispose();
    _adminLoginController.dispose();
    _adminPasswordController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onStaffLogin() async {
    final rawText = _phoneController.text.trim();
    final digits = PhoneFormatter.extractSubscriberDigits(rawText);

    if (digits.isEmpty) {
      _showSnackBar(context.tr('login_enter_phone'));
      return;
    }

    if (digits.length != 9) {
      _showSnackBar(context.tr('login_phone_length_error'));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.remove('rahbar_token');

    final fullPhone = '998$digits';
    if (mounted) {
      context.read<AuthBloc>().add(LoginSubmitted(fullPhone));
    }
  }

  void _onAdminLogin() {
    final login = _adminLoginController.text.trim();
    final password = _adminPasswordController.text;

    if (login.isEmpty || password.isEmpty) {
      _showSnackBar(context.tr('login_enter_credentials'));
      return;
    }

    context.read<RahbarBloc>().add(
      RahbarLoginSubmitted(login: login, password: password),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Bitta telefon raqamiga bir nechta xodim biriktirilgan bo'lsa, server
  /// tizim (badge) raqamini so'raydi. Shu raqam bilan qayta kirishga urinamiz.
  Future<void> _askPersonCode(String phone, String serverMessage) async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('login_person_code_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              serverMessage,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: context.tr('login_person_code_hint'),
                prefixIcon: const Icon(
                  Icons.badge_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('login_person_code_note'),
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: GoogleFonts.outfit(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              context.tr('login_continue'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    controller.dispose();

    if (code == null || code.isEmpty) return;
    if (!mounted) return;
    context.read<AuthBloc>().add(LoginSubmitted(phone, personCode: code));
  }

  void _openContactModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: AppColors.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('login_contact_us'),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('login_contact_desc'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () async {
                  unawaited(HapticFeedback.lightImpact());
                  final Uri url = Uri.parse('tel:+998944477484');
                  try {
                    final launched = await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!launched) {
                      await launchUrl(url);
                    }
                  } catch (_) {}
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.phone_in_talk_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '+998 (94) 447-74-84',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthMultiple) {
              context.go('/select-org', extra: state.staffList);
            } else if (state is AuthSuccess) {
              FcmService.syncUserRole();
              FcmService.registerTokenOnBackend(
                phone: state.phone,
                staffId: state.staff.id,
              );
              GpsLiveTrackerService.instance.startTracking(phone: state.phone);
              LanguageSyncService.fetchAndApplyFromBackend(
                context.read<LanguageCubit>(),
              );
              context.go('/');
            } else if (state is AuthNeedsPersonCode) {
              _askPersonCode(state.phone, state.message);
            } else if (state is AuthFailure) {
              _showSnackBar(state.message);
            }
          },
        ),
        BlocListener<RahbarBloc, RahbarState>(
          listener: (context, state) {
            if (state is RahbarAuthSuccess) {
              FcmService.syncUserRole();
              context.go('/rahbar');
            } else if (state is RahbarError) {
              _showSnackBar(state.message);
            }
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

          return Scaffold(
            backgroundColor: AppColors.background,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        isKeyboardOpen ? 4 : 12,
                        24,
                        isKeyboardOpen ? 24 : 20,
                      ),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(height: isKeyboardOpen ? 0 : 8),

                            // Adaptive Brand Logo (Adapts size dynamically when keyboard opens)
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: SkorLogoWidget(
                                size: isKeyboardOpen ? 44 : 72,
                                showText: !isKeyboardOpen,
                                animateParticles: true,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: isKeyboardOpen ? 8 : 16,
                            ),

                            // Main White Card
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 420),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.tr('login_welcome'),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.tr('login_select_type'),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Role Selector TabBar (Modern Sliding Glow Pill)
                                  _buildRoleTabBar(),
                                  const SizedBox(height: 22),

                                  // Dynamic Form Content (Directional Slide & Fade Transition)
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 320),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder: (child, animation) {
                                      final isStaffChild =
                                          (child.key as ValueKey).value ==
                                          'staff_form';
                                      final offsetAnimation = Tween<Offset>(
                                        begin: Offset(
                                          isStaffChild ? -0.15 : 0.15,
                                          0.0,
                                        ),
                                        end: Offset.zero,
                                      ).animate(animation);

                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: offsetAnimation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _selectedRole == UserRole.staff
                                        ? _buildStaffForm(
                                            key: const ValueKey('staff_form'),
                                          )
                                        : _buildAdminForm(
                                            key: const ValueKey('admin_form'),
                                          ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Support Contact Link
                                  Center(
                                    child: GestureDetector(
                                      onTap: _openContactModal,
                                      child: Text.rich(
                                        TextSpan(
                                          text: context.tr('login_no_account'),
                                          style: GoogleFonts.outfit(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: context.tr(
                                                'login_contact_us',
                                              ),
                                              style: GoogleFonts.outfit(
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.bold,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      onPressed: () => LanguagePickerBottomSheet.show(context),
                      icon: const Icon(
                        Icons.language_rounded,
                        color: AppColors.primary,
                      ),
                      tooltip: context.tr('app_language'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaffForm({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('login_phone_label'),
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          keyboardType: TextInputType.phone,
          maxLength: 17,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [UzbekPhoneInputFormatter()],
          textAlignVertical: TextAlignVertical.center,
          scrollPadding: const EdgeInsets.only(bottom: 140),
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFeatures: const [
              FontFeature.liningFigures(),
              FontFeature.tabularFigures(),
            ],
          ),
          decoration: InputDecoration(
            hintText: '+998 90 123 45 67',
            hintStyle: GoogleFonts.outfit(
              color: AppColors.textHint,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFeatures: const [
                FontFeature.liningFigures(),
                FontFeature.tabularFigures(),
              ],
            ),
            prefixIcon: const Icon(
              Icons.phone_android_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _onStaffLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        context.tr('login_submit'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdminForm({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('login_admin_login_label'),
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _adminLoginController,
          scrollPadding: const EdgeInsets.only(bottom: 140),
          style: GoogleFonts.outfit(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: context.tr('login_admin_login_hint'),
            hintStyle: GoogleFonts.outfit(
              color: AppColors.textHint,
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('login_password_label'),
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _adminPasswordController,
          obscureText: _obscurePassword,
          scrollPadding: const EdgeInsets.only(bottom: 140),
          style: GoogleFonts.outfit(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: GoogleFonts.outfit(
              color: AppColors.textHint,
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(
              Icons.lock_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 18),
        BlocBuilder<RahbarBloc, RahbarState>(
          builder: (context, state) {
            final isLoading = state is RahbarLoading;
            return SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _onAdminLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        context.tr('login_admin_submit'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoleTabBar() {
    final isStaff = _selectedRole == UserRole.staff;

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = (constraints.maxWidth - 8) / 2;

          return Stack(
            children: [
              // 1. Animated Sliding Pill Indicator with Glowing Elevation
              AnimatedAlign(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                alignment: isStaff
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: halfWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isStaff
                          ? [AppColors.primary, const Color(0xFF139797)]
                          : [const Color(0xFF0F766E), const Color(0xFF085454)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Interactive Role Tabs with Animated Icons and Colors
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_selectedRole != UserRole.staff) {
                          setState(() => _selectedRole = UserRole.staff);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isStaff ? 1.0 : 0.6,
                              child: Icon(
                                Icons.badge_rounded,
                                size: 18,
                                color: isStaff
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: GoogleFonts.outfit(
                                fontWeight: isStaff
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 14,
                                color: isStaff
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                letterSpacing: 0.2,
                              ),
                              child: Text(context.tr('login_role_staff')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_selectedRole != UserRole.admin) {
                          setState(() => _selectedRole = UserRole.admin);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          });
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: !isStaff ? 1.0 : 0.6,
                              child: Icon(
                                Icons.shield_rounded,
                                size: 18,
                                color: !isStaff
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: GoogleFonts.outfit(
                                fontWeight: !isStaff
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 14,
                                color: !isStaff
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                letterSpacing: 0.2,
                              ),
                              child: Text(context.tr('login_role_admin')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
