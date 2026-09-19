import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';

class RahbarArizalarPage extends StatefulWidget {
  const RahbarArizalarPage({super.key});

  @override
  State<RahbarArizalarPage> createState() => _RahbarArizalarPageState();
}

class _RahbarArizalarPageState extends State<RahbarArizalarPage> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<RahbarBloc>();
    if (bloc.state is! RahbarArizalarLoaded && bloc.state is! RahbarLoading) {
      bloc.add(LoadRahbarArizalar());
    }
  }

  void _showReviewDialog(RahbarArizaEntity ariza, String action) {
    final bool isApprove = action == 'approve';
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isApprove
              ? context.tr('rahbar_ariza_approve_title')
              : context.tr('rahbar_ariza_reject_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isApprove ? Colors.green.shade800 : AppColors.error,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove
                  ? context.tr('rahbar_ariza_confirm_approve', {
                      'name': ariza.xodimName,
                      'turi': ariza.turiNomi,
                    })
                  : context.tr('rahbar_ariza_confirm_reject', {
                      'name': ariza.xodimName,
                      'turi': ariza.turiNomi,
                    }),
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: commentController,
              maxLines: 2,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              cursorColor: const Color(0xFF0D6E6E),
              decoration: InputDecoration(
                hintText: context.tr('rahbar_ariza_comment_hint'),
                hintStyle: GoogleFonts.outfit(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isApprove
                        ? const Color(0xFF16A34A)
                        : AppColors.error,
                    width: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('no'),
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove
                  ? Colors.green.shade700
                  : AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RahbarBloc>().add(
                ReviewRahbarAriza(
                  arizaId: ariza.id,
                  action: action,
                  comment: commentController.text.trim(),
                ),
              );
            },
            child: Text(
              isApprove
                  ? context.tr('rahbar_approve')
                  : context.tr('rahbar_reject'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('rahbar_arizalar_list_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D6E6E),
            fontSize: 20,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<RahbarBloc>().add(LoadRahbarArizalar()),
        color: const Color(0xFF0D6E6E),
        child: BlocBuilder<RahbarBloc, RahbarState>(
          buildWhen: (prev, curr) =>
              curr is RahbarLoading ||
              curr is RahbarArizalarLoaded ||
              curr is RahbarError,
          builder: (context, state) {
            if (state is RahbarLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D6E6E)),
              );
            } else if (state is RahbarArizalarLoaded) {
              if (state.list.isEmpty) {
                return RahbarEmptyStateWidget(
                  icon: Icons.assignment_turned_in_rounded,
                  title: context.tr('rahbar_no_arizalar_title'),
                  subtitle: context.tr('rahbar_no_arizalar_desc'),
                  onRefresh: () =>
                      context.read<RahbarBloc>().add(LoadRahbarArizalar()),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.list.length,
                itemBuilder: (context, index) {
                  final item = state.list[index];
                  final statusLower = item.status.toLowerCase();
                  final statusNomiLower = item.statusNomi.toLowerCase();

                  final bool isRejected =
                      statusLower.contains('rad') ||
                      statusNomiLower.contains('rad') ||
                      statusLower.contains('reject') ||
                      statusNomiLower.contains('reject');

                  final bool isPending =
                      statusLower.contains('kutil') ||
                      statusNomiLower.contains('kutil') ||
                      statusLower.contains('pend') ||
                      statusNomiLower.contains('pend');

                  Color badgeColor;
                  Color badgeBgColor;
                  List<Color> gradientColors;

                  if (isRejected) {
                    badgeColor = const Color(0xFFDC2626); // Qizil matn
                    badgeBgColor = const Color(0xFFFEE2E2); // Och qizil fon
                    gradientColors = const [
                      Color(0xFFEF4444),
                      Color(0xFFF87171),
                      Color(0xFFDC2626),
                      Color(0xFFEF4444),
                    ];
                  } else if (isPending) {
                    badgeColor = const Color(0xFFD97706); // Sariq matn
                    badgeBgColor = const Color(0xFFFEF3C7); // Och sariq fon
                    gradientColors = const [
                      Color(0xFFF59E0B),
                      Color(0xFFFBBF24),
                      Color(0xFFD97706),
                      Color(0xFFF59E0B),
                    ];
                  } else {
                    // Tasdiqlangan (Approved - Zangor / Teal)
                    badgeColor = const Color(0xFF0D6E6E); // Zangor matn
                    badgeBgColor = const Color(0xFFCCFBF1); // Och zangor fon
                    gradientColors = const [
                      Color(0xFF0D6E6E),
                      Color(0xFF139797),
                      Color(0xFF26BBAA),
                      Color(0xFF0D6E6E),
                    ];
                  }

                  return AnimatedRotatingBorderContainer(
                    margin: const EdgeInsets.only(bottom: 14),
                    borderRadius: 18,
                    borderWidth: 2.0,
                    gradientColors: gradientColors,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.xodimName,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.statusNomi,
                                  style: GoogleFonts.outfit(
                                    color: badgeColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('rahbar_ariza_type_days', {
                              'turi': item.turiNomi,
                              'days': '${item.kunlar}',
                            }),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('rahbar_ariza_date_range', {
                              'from': item.fromDate,
                              'to': item.toDate,
                            }),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (item.izoh != null && item.izoh!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              context.tr('ariza_card_comment', {
                                'text': item.izoh!,
                              }),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (isPending) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _showReviewDialog(item, 'reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                        color: AppColors.error,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      context.tr('rahbar_reject'),
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _showReviewDialog(item, 'approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      context.tr('rahbar_approve'),
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            } else if (state is RahbarError) {
              return RahbarEmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: context.tr('error_occurred_title'),
                subtitle: state.message,
                onRefresh: () =>
                    context.read<RahbarBloc>().add(LoadRahbarArizalar()),
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D6E6E)),
            );
          },
        ),
      ),
    );
  }
}
