import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/widgets/pull_to_refresh.dart';

/// Bo'sh yoki xato holat. [onRefresh] berilsa "pastga torting" ishorasi
/// chiqadi; yangilashning o'zini ustidagi `RefreshIndicator` bajaradi.
class RahbarEmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onRefresh;

  /// Ustida `RefreshIndicator` bor bo'lsa `true` — ishora ko'rsatiladi.
  final bool refreshable;

  const RahbarEmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRefresh,
    this.refreshable = false,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollableFill(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    context.colors.primary.withValues(alpha: 0.12),
                    const Color(0xFF139797).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: context.colors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, size: 42, color: context.colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            if (subtitle != null) const SizedBox(height: 8),
            if (subtitle != null)
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
              ),
            if (onRefresh != null || refreshable) ...[
              const SizedBox(height: 20),
              const PullToRefreshHint(),
            ],
          ],
        ),
      ),
    );
  }
}
