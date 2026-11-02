import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/offline_info_bottom_sheet.dart';
import 'package:skore_hodimlar/core/widgets/pull_to_refresh.dart';

/// Sahifalar (Davomat tarixi, Arizalar, Bosh sahifa) ichida internet uzilishi
/// tufayli ma'lumotlar yuklanmaganda ko'rsatiladigan zamonaviy inline / to'liq sahifali vidjet.
class NoInternetView extends StatelessWidget {
  final String? title;
  final String? message;

  /// Berilsa, sahifani pastga tortib qayta yuklash mumkin bo'ladi.
  final FutureOr<void> Function()? onRetry;
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
    final content = _content(context);
    // Ixcham ko'rinish sahifa ichida turadi — yangilashni sahifaning o'zi
    // bajaradi. To'liq ko'rinish esa o'zi pastga tortishni ushlaydi.
    if (onRetry == null || isCompact) return content;
    return RefreshableFill(
      onRefresh: () => refreshWithMinDelay(onRetry!),
      child: content,
    );
  }

  Widget _content(BuildContext context) {
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
                color: context.colors.errorSoft,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.error.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: context.colors.error,
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
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle
            Text(
              message ?? context.tr('no_internet_default_message'),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isCompact ? 12.5 : 13.5,
                color: context.colors.textSecondary,
                height: 1.35,
              ),
            ),
            SizedBox(height: isCompact ? 14 : 22),

            // Yangilash ishorasi va maslahatlar tugmasi
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRetry != null) const Flexible(child: PullToRefreshHint()),
                IconButton(
                  tooltip: context.tr('no_internet_tips_tooltip'),
                  icon: Icon(
                    Icons.help_outline_rounded,
                    color: context.colors.textSecondary,
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
