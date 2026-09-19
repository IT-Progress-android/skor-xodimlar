import 'package:flutter/material.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';

class ArizaCard extends StatelessWidget {
  final ArizaEntity ariza;
  final VoidCallback? onCancel;

  const ArizaCard({super.key, required this.ariza, this.onCancel});

  Color _getStatusColor() {
    final status = ariza.status.toLowerCase();
    final statusNomi = ariza.statusNomi.toLowerCase();
    if (status.contains('rad') ||
        statusNomi.contains('rad') ||
        status.contains('reject')) {
      return const Color(0xFFDC2626); // Qizil
    }
    if (status.contains('kutil') ||
        statusNomi.contains('kutil') ||
        status.contains('pend')) {
      return const Color(0xFFD97706); // Sariq
    }
    return const Color(0xFF0D6E6E); // Zangor (Teal)
  }

  List<Color> _getStatusGradientColors() {
    final status = ariza.status.toLowerCase();
    final statusNomi = ariza.statusNomi.toLowerCase();
    if (status.contains('rad') ||
        statusNomi.contains('rad') ||
        status.contains('reject')) {
      return const [
        Color(0xFFEF4444),
        Color(0xFFF87171),
        Color(0xFFDC2626),
        Color(0xFFEF4444),
      ];
    }
    if (status.contains('kutil') ||
        statusNomi.contains('kutil') ||
        status.contains('pend')) {
      return const [
        Color(0xFFF59E0B),
        Color(0xFFFBBF24),
        Color(0xFFD97706),
        Color(0xFFF59E0B),
      ];
    }
    return const [
      Color(0xFF0D6E6E),
      Color(0xFF139797),
      Color(0xFF26BBAA),
      Color(0xFF0D6E6E),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final gradientColors = _getStatusGradientColors();

    return AnimatedRotatingBorderContainer(
      margin: const EdgeInsets.only(bottom: 14),
      borderRadius: 16,
      borderWidth: 2.0,
      gradientColors: gradientColors,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Ariza Turi & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ariza.turiNomi,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ariza.statusNomi,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Date Range & Duration Chip
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  ariza.fromDate == ariza.toDate
                      ? ariza.fromDate
                      : '${ariza.fromDate} — ${ariza.toDate}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('ariza_card_days_count', {
                      'days': '${ariza.kunlar}',
                    }),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // Comment / Izoh if present
            if (ariza.izoh != null && ariza.izoh!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('ariza_card_comment', {'text': ariza.izoh!}),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Review note if rejected or reviewed
            if (ariza.reviewIzoh != null && ariza.reviewIzoh!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  context.tr('ariza_card_review_note', {
                    'text': ariza.reviewIzoh!,
                  }),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Bottom Row: Yuborilgan time & Cancel action button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (ariza.yuborilgan.isNotEmpty)
                  Text(
                    context.tr('home_sent_at', {'date': ariza.yuborilgan}),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (ariza.isPending && onCancel != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(
                      context.tr('cancel'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
