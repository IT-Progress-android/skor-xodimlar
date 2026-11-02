import 'package:flutter/material.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';

class ArizaCard extends StatelessWidget {
  final ArizaEntity ariza;
  final VoidCallback? onCancel;

  const ArizaCard({super.key, required this.ariza, this.onCancel});

  Color _getStatusColor(BuildContext context) {
    final status = ariza.status.toLowerCase();
    if (status.contains('rad') || status.contains('reject')) {
      return context.colors.error; // Qizil
    }
    if (status.contains('kutil') || status.contains('pend')) {
      return const Color(0xFFD97706); // Sariq
    }
    return context.colors.primary; // Zangor (Teal)
  }

  List<Color> _getStatusGradientColors(BuildContext context) {
    final status = ariza.status.toLowerCase();
    if (status.contains('rad') || status.contains('reject')) {
      return [
        context.colors.error,
        const Color(0xFFF87171),
        context.colors.error,
        context.colors.error,
      ];
    }
    if (status.contains('kutil') || status.contains('pend')) {
      return [
        context.colors.warning,
        const Color(0xFFFBBF24),
        const Color(0xFFD97706),
        context.colors.warning,
      ];
    }
    return [
      context.colors.primary,
      Color(0xFF139797),
      Color(0xFF26BBAA),
      context.colors.primary,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final gradientColors = _getStatusGradientColors(context);

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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.colors.textPrimary,
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
                    BackendTextMapper.translateArizaStatus(ariza.statusNomi),
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
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: context.colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  ariza.fromDate == ariza.toDate
                      ? ariza.fromDate
                      : '${ariza.fromDate} — ${ariza.toDate}',
                  style: TextStyle(
                    color: context.colors.textPrimary,
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
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('ariza_card_days_count', {
                      'days': '${ariza.kunlar}',
                    }),
                    style: TextStyle(
                      color: context.colors.primary,
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
                style: TextStyle(
                  color: context.colors.textSecondary,
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
                  color: context.colors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.colors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  context.tr('ariza_card_review_note', {
                    'text': ariza.reviewIzoh!,
                  }),
                  style: TextStyle(
                    color: context.colors.error,
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
                    style: TextStyle(
                      color: context.colors.textHint,
                      fontSize: 11,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (ariza.isPending && onCancel != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.error,
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
