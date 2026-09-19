import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_filial_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_kundalik_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_kunlik_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_qoldiruvchilar_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_xodimlar_report_page.dart';

/// §3 Hisobotlar — entry point to every report screen.
class RahbarReportsHubPage extends StatelessWidget {
  const RahbarReportsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_ReportEntry>[
      _ReportEntry(
        context.tr('rahbar_report_kundalik_title'),
        context.tr('rahbar_report_kundalik_desc'),
        Icons.today_rounded,
        const RahbarKundalikPage(),
      ),
      _ReportEntry(
        context.tr('rahbar_report_xodimlar_title'),
        context.tr('rahbar_report_xodimlar_desc'),
        Icons.groups_rounded,
        const RahbarXodimlarReportPage(),
      ),
      _ReportEntry(
        context.tr('rahbar_report_kunlik_title'),
        context.tr('rahbar_report_kunlik_desc'),
        Icons.bar_chart_rounded,
        const RahbarKunlikPage(),
      ),
      _ReportEntry(
        context.tr('rahbar_report_qoldiruvchilar_title'),
        context.tr('rahbar_report_qoldiruvchilar_desc'),
        Icons.person_off_rounded,
        const RahbarQoldiruvchilarPage(),
      ),
      _ReportEntry(
        context.tr('rahbar_report_filial_title'),
        context.tr('rahbar_report_filial_desc'),
        Icons.apartment_rounded,
        const RahbarFilialPage(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(context.tr('rahbar_nav_reports')),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = items[i];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0D6E6E).withValues(alpha: 0.1),
                child: Icon(e.icon, color: const Color(0xFF0D6E6E)),
              ),
              title: Text(
                e.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(e.subtitle, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => sl<RahbarBloc>(),
                    child: e.page,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
  const _ReportEntry(this.title, this.subtitle, this.icon, this.page);
}
