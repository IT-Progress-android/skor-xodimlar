import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/offline_info_bottom_sheet.dart';

/// Sahifalar (Davomat tarixi, Arizalar, Bosh sahifa) ichida internet uzilishi
/// tufayli ma'lumotlar yuklanmaganda ko'rsatiladigan zamonaviy inline / to'liq sahifali vidjet.
class NoInternetView extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final bool isCompact;

  const NoInternetView({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: isCompact ? 56 : 76,
              height: isCompact ? 56 : 76,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: const Color(0xFFDC2626),
                size: isCompact ? 28 : 38,
              ),
            ),
            SizedBox(height: isCompact ? 12 : 18),

            // Title
            Text(
              title ?? context.tr('no_internet_title'),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isCompact ? 16 : 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle
            Text(
              message ?? context.tr('no_internet_default_message'),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isCompact ? 12.5 : 13.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            SizedBox(height: isCompact ? 14 : 22),

            // Retry and Help Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRetry != null)
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      context.tr('no_internet_reload'),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: context.tr('no_internet_tips_tooltip'),
                  icon: const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  onPressed: () => OfflineInfoBottomSheet.show(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
