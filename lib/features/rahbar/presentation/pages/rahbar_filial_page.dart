import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_report_view.dart';

/// §3.3 Filial xodimlari — attendance grouped by branch (expandable panels).
class RahbarFilialPage extends StatefulWidget {
  const RahbarFilialPage({super.key});

  @override
  State<RahbarFilialPage> createState() => _RahbarFilialPageState();
}

class _RahbarFilialPageState extends State<RahbarFilialPage> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          context.tr('rahbar_report_filial_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D6E6E),
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RahbarReportView(
        fetch: () => sl<RahbarRemoteDataSource>().getFilial(),
        builder: (context, data) {
          final rawFiliallar = (data['filiallar'] as List?) ?? const [];

          // Separate valid branches from "Filial biriktirilmagan"
          final List<Map<String, dynamic>> validBranches = [];
          Map<String, dynamic>? unassignedBranch;

          for (final item in rawFiliallar) {
            final f = Map<String, dynamic>.from(item as Map);
            final nom = (f['nom'] ?? f['name'] ?? '').toString().trim();
            final isUnassigned =
                nom.isEmpty ||
                nom.toLowerCase().contains('biriktirilmagan') ||
                nom.toLowerCase().contains('unassigned') ||
                nom.toLowerCase() == 'null';

            if (isUnassigned) {
              unassignedBranch = f;
            } else {
              validBranches.add(f);
            }
          }

          final List<Map<String, dynamic>> filiallar = List.from(validBranches);
          if (unassignedBranch != null) {
            final unassignedStaff =
                (unassignedBranch['xodimlar'] as List?) ?? [];
            final unassignedJami =
                (unassignedBranch['jami'] as num?)?.toInt() ??
                unassignedStaff.length;
            if (unassignedJami > 0 || unassignedStaff.isNotEmpty) {
              filiallar.add({
                ...unassignedBranch,
                'nom': (unassignedBranch['nom'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty
                    ? unassignedBranch['nom']
                    : 'Filial biriktirilmagan',
                'jami': unassignedJami,
                'kelgan': (unassignedBranch['kelgan'] as num?)?.toInt() ?? 0,
                'xodimlar': unassignedStaff,
              });
            }
          }

          if (filiallar.isEmpty) {
            return RahbarEmptyStateWidget(
              icon: Icons.apartment_rounded,
              title: context.tr('rahbar_branches_not_found'),
              subtitle: context.tr('rahbar_branches_empty_desc'),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: ExpansionPanelList(
              elevation: 0,
              expandedHeaderPadding: EdgeInsets.zero,
              expansionCallback: (index, isOpen) {
                setState(() {
                  if (isOpen) {
                    _expanded.add(index);
                  } else {
                    _expanded.remove(index);
                  }
                });
              },
              children: List.generate(filiallar.length, (index) {
                final f = filiallar[index];
                final nom =
                    f['nom']?.toString() ??
                    context.tr('rahbar_branch_fallback');
                final jami = (f['jami'] as num?)?.toInt() ?? 0;
                final kelgan = (f['kelgan'] as num?)?.toInt() ?? 0;
                final xodimlar = (f['xodimlar'] as List?) ?? const [];
                final double percent = jami > 0
                    ? (kelgan / jami).clamp(0.0, 1.0)
                    : 0.0;

                return ExpansionPanel(
                  isExpanded: _expanded.contains(index),
                  canTapOnHeader: true,
                  backgroundColor: Colors.white,
                  headerBuilder: (ctx, isExpanded) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D6E6E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF0D6E6E),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      nom,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      context.tr('rahbar_arrived_count', {
                        'present': '$kelgan',
                        'total': '$jami',
                      }),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing: SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: percent,
                            strokeWidth: 3.5,
                            backgroundColor: Colors.grey.shade200,
                            color: percent > 0.5
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF0D6E6E),
                          ),
                          Text(
                            '${(percent * 100).round()}%',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  body: xodimlar.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            context.tr('rahbar_branch_no_staff'),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade100),
                            ),
                          ),
                          child: Column(
                            children: xodimlar.map<Widget>((x) {
                              final xm = Map<String, dynamic>.from(x as Map);
                              final name =
                                  xm['name']?.toString() ??
                                  xm['xodim']?.toString() ??
                                  context.tr('rahbar_staff_fallback');
                              final checkIn =
                                  xm['check_in']?.toString() ??
                                  xm['in']?.toString() ??
                                  '—';
                              final checkOut =
                                  xm['check_out']?.toString() ??
                                  xm['out']?.toString() ??
                                  '—';
                              final hasIn =
                                  checkIn != '—' &&
                                  checkIn.isNotEmpty &&
                                  checkIn != '--:--';

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 2,
                                ),
                                leading: Icon(
                                  hasIn
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 18,
                                  color: hasIn
                                      ? const Color(0xFF16A34A)
                                      : Colors.red.shade400,
                                ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                trailing: Text(
                                  '$checkIn → $checkOut',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: hasIn
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
