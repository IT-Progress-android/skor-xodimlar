import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_report_view.dart';

/// §3.5 Qoldiruvchilar — staff with the most unexcused absences.
class RahbarQoldiruvchilarPage extends StatelessWidget {
  const RahbarQoldiruvchilarPage({super.key});

  void _showDates(BuildContext context, Map<String, dynamic> x) {
    final sanalar = (x['sanalar'] as List?) ?? const [];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          x['name']?.toString() ?? '',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: context.colors.textPrimary,
          ),
        ),
        content: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sanalar
              .map<Widget>(
                (s) => Chip(
                  label: Text(
                    s.toString(),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  backgroundColor: context.colors.surfaceStrong,
                  side: BorderSide.none,
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.tr('close'),
              style: GoogleFonts.outfit(
                color: context.colors.primary,
                fontWeight: FontWeight.bold,
              ),
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
        title: Text(context.tr('rahbar_report_qoldiruvchilar_title')),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: RahbarReportView(
        fetch: () => sl<RahbarRemoteDataSource>().getQoldiruvchilar(engKam: 1),
        builder: (context, data) {
          final xodimlar = (data['xodimlar'] as List?) ?? const [];
          if (xodimlar.isEmpty) {
            return RahbarEmptyStateWidget(
              icon: Icons.verified_rounded,
              title: context.tr('rahbar_no_absentees'),
              refreshable: true,
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: xodimlar.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final x = Map<String, dynamic>.from(xodimlar[i] as Map);
              final photo = x['photo']?.toString() ?? '';
              final name = x['name']?.toString() ?? '';
              final bool validUrl =
                  photo.isNotEmpty &&
                  !photo.contains('localhost') &&
                  (photo.startsWith('http://') || photo.startsWith('https://'));

              Widget fallbackAvatar() => CircleAvatar(
                backgroundColor: const Color(
                  0xFF0D6E6E,
                ).withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.colors.primary,
                  ),
                ),
              );

              return ListTile(
                leading: !validUrl
                    ? fallbackAvatar()
                    : CachedNetworkImage(
                        imageUrl: photo,
                        imageBuilder: (context, provider) =>
                            CircleAvatar(backgroundImage: provider),
                        placeholder: (context, url) => fallbackAvatar(),
                        errorWidget: (context, url, error) => fallbackAvatar(),
                      ),
                title: Text(name),
                subtitle: Text('${x['bolim'] ?? ''} · ${x['phone'] ?? ''}'),
                trailing: Chip(
                  backgroundColor: context.colors.errorSoft,
                  label: Text(
                    context.tr('rahbar_absent_days_count', {
                      'absent': '${x['qoldirgan_kun'] ?? 0}',
                      'total': '${x['jami_kun'] ?? 0}',
                    }),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                onTap: () => _showDates(context, x),
              );
            },
          );
        },
      ),
    );
  }
}
