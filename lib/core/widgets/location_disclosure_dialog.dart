import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';

/// Google Playning "Prominent Disclosure and Consent Requirement"
/// (BACKGROUND_LOCATION) talablariga 100% javob beradigan maxsus
/// ochiq ma'lumot va rozilik oynasi.
class LocationDisclosureDialog extends StatelessWidget {
  final bool isBackgroundMode;

  const LocationDisclosureDialog({super.key, this.isBackgroundMode = false});

  static const String prefKey = 'has_accepted_location_disclosure';
  static const String bgPrefKey = 'has_accepted_bg_location_disclosure';

  /// Oldingi fon (Foreground) joylashuvi so'ralishidan oldin ko'rsatiladi
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LocationDisclosureDialog(isBackgroundMode: false),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, true);
      return true;
    }
    return false;
  }

  /// Orqa fon (Background / "Har doim ruxsat berish") so'ralishidan oldin ko'rsatiladi
  static Future<bool> showBackgroundDisclosure(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LocationDisclosureDialog(isBackgroundMode: true),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(bgPrefKey, true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon with circular badge
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBackgroundMode
                          ? Icons.share_location_rounded
                          : Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  isBackgroundMode
                      ? context.tr('bg_location_disclosure_title')
                      : context.tr('location_disclosure_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),

                // Mandatory Google Play Prominent Disclosure Statement Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    isBackgroundMode
                        ? context.tr('bg_location_disclosure_statement')
                        : context.tr('location_disclosure_statement'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF074E4E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Features / Context items
                _buildFeatureRow(
                  icon: Icons.access_time_filled_rounded,
                  title: context.tr('location_feature_time_title'),
                  desc: context.tr('location_feature_time_desc'),
                ),
                const SizedBox(height: 12),
                _buildFeatureRow(
                  icon: Icons.shield_rounded,
                  title: context.tr('location_feature_privacy_title'),
                  desc: context.tr('location_feature_privacy_desc'),
                ),
                const SizedBox(height: 24),

                // Accept / Settings button
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1,
                  ),
                  child: Text(
                    isBackgroundMode
                        ? context.tr('bg_location_open_settings')
                        : context.tr('location_accept'),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Decline button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    isBackgroundMode
                        ? context.tr('bg_location_cancel')
                        : context.tr('location_decline'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
