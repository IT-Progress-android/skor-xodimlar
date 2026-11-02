import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/core/widgets/pull_to_refresh.dart';
import 'package:skore_hodimlar/features/applications/presentation/ariza_refresh.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';

class RahbarArizalarPage extends StatefulWidget {
  const RahbarArizalarPage({super.key});

  @override
  State<RahbarArizalarPage> createState() => _RahbarArizalarPageState();
}

class _RahbarArizalarPageState extends State<RahbarArizalarPage> {
  late final StreamSubscription<String> _pushSub;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<RahbarBloc>();
    if (bloc.state is! RahbarArizalarLoaded && bloc.state is! RahbarLoading) {
      bloc.add(LoadRahbarArizalar());
    }
    _pushSub = arizaPushes.stream.listen((type) {
      if (type == 'ariza_new' && mounted) {
        context.read<RahbarBloc>().add(LoadRahbarArizalar());
      }
    });
  }

  @override
  void dispose() {
    _pushSub.cancel();
    super.dispose();
  }

  void _showReviewDialog(RahbarArizaEntity ariza, String action) {
    final bool isApprove = action == 'approve';
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isApprove
              ? context.tr('rahbar_ariza_approve_title')
              : context.tr('rahbar_ariza_reject_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isApprove ? context.colors.success : context.colors.error,
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
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: commentController,
              maxLines: 2,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: context.colors.primary,
              decoration: InputDecoration(
                hintText: context.tr('rahbar_ariza_comment_hint'),
                hintStyle: GoogleFonts.outfit(
                  color: context.colors.textHint,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: context.colors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isApprove
                        ? context.colors.success
                        : context.colors.error,
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
              style: GoogleFonts.outfit(color: context.colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove
                  ? Colors.green.shade700
                  : context.colors.error,
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('rahbar_arizalar_list_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.colors.primary,
            fontSize: 20,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => refreshWithMinDelay(
          () => context.read<RahbarBloc>().add(LoadRahbarArizalar()),
        ),
        color: context.colors.primary,
        child: BlocBuilder<RahbarBloc, RahbarState>(
          buildWhen: (prev, curr) =>
              curr is RahbarLoading ||
              curr is RahbarArizalarLoaded ||
              curr is RahbarError,
          builder: (context, state) {
            if (state is RahbarLoading) {
              return Center(
                child: CircularProgressIndicator(color: context.colors.primary),
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

                  final bool isRejected =
                      statusLower.contains('rad') ||
                      statusLower.contains('reject');

                  final bool isPending =
                      statusLower.contains('kutil') ||
                      statusLower.contains('pend');

                  Color badgeColor;
                  Color badgeBgColor;
                  List<Color> gradientColors;

                  if (isRejected) {
                    badgeColor = context.colors.error; // Qizil matn
                    badgeBgColor = context.colors.errorSoft; // Och qizil fon
                    gradientColors = [
                      context.colors.error,
                      Color(0xFFF87171),
                      context.colors.error,
                      context.colors.error,
                    ];
                  } else if (isPending) {
                    badgeColor = const Color(0xFFD97706); // Sariq matn
                    badgeBgColor = context.colors.warningSoft; // Och sariq fon
                    gradientColors = [
                      context.colors.warning,
                      Color(0xFFFBBF24),
                      Color(0xFFD97706),
                      context.colors.warning,
                    ];
                  } else {
                    // Tasdiqlangan (Approved - Zangor / Teal)
                    badgeColor = context.colors.primary; // Zangor matn
                    badgeBgColor = context.colors.primarySoft; // Och zangor fon
                    gradientColors = [
                      context.colors.primary,
                      Color(0xFF139797),
                      Color(0xFF26BBAA),
                      context.colors.primary,
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
                                  color: context.colors.textPrimary,
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
                                  BackendTextMapper.translateArizaStatus(
                                    item.statusNomi,
                                  ),
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
                              color: context.colors.textSecondary,
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
                              color: context.colors.textPrimary,
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
                                color: context.colors.textSecondary,
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
                                      foregroundColor: context.colors.error,
                                      side: BorderSide(
                                        color: context.colors.error,
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
            return Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            );
          },
        ),
      ),
    );
  }
}
