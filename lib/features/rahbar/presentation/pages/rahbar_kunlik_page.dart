import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_report_view.dart';

/// §3.4 Kunlik davomat — per-day totals with an attendance-% bar per day.
class RahbarKunlikPage extends StatefulWidget {
  const RahbarKunlikPage({super.key});

  @override
  State<RahbarKunlikPage> createState() => _RahbarKunlikPageState();
}

class _RahbarKunlikPageState extends State<RahbarKunlikPage> {
  final _fmt = DateFormat('yyyy-MM-dd');
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 30));
  }

  Color _color(double foiz) =>
      foiz >= 80 ? Colors.green : (foiz >= 50 ? Colors.orange : Colors.red);

  String _formatItemDate(Map<String, dynamic> k) {
    // 1. Try to find the date string from all common keys
    String? rawDate;
    for (final key in [
      'sana',
      'date',
      'kun',
      'day',
      'formatted_date',
      'date_formatted',
      'created_at',
      'time',
    ]) {
      final val = k[key];
      if (val != null &&
          val.toString().trim().isNotEmpty &&
          val.toString().trim() != 'null') {
        rawDate = val.toString().trim();
        break;
      }
    }

    // Fallback: look through all map values for a date pattern (yyyy-MM-dd or dd.MM.yyyy)
    if (rawDate == null) {
      for (final entry in k.entries) {
        final val = entry.value?.toString().trim() ?? '';
        if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(val) ||
            RegExp(r'^\d{2}\.\d{2}\.\d{4}').hasMatch(val)) {
          rawDate = val;
          break;
        }
      }
    }

    if (rawDate == null || rawDate.isEmpty) {
      final hk = (k['hafta_kuni'] ?? k['weekday'] ?? k['kun_nomi'])?.toString();
      if (hk != null && hk.isNotEmpty) {
        return BackendTextMapper.translateWeekday(hk) ?? hk;
      }
      return '';
    }

    // Clean timestamp if it contains time (e.g. 2026-09-21 00:00:00)
    if (rawDate.contains(' ')) rawDate = rawDate.split(' ').first;
    if (rawDate.contains('T')) rawDate = rawDate.split('T').first;

    // Parse DateTime if possible
    DateTime? dt;
    try {
      if (rawDate.contains('.')) {
        final parts = rawDate.split('.');
        if (parts.length == 3) {
          dt = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } else {
        dt = DateTime.tryParse(rawDate);
      }
    } catch (_) {}

    final dateDisplay = dt != null ? DateFormat('dd.MM.yyyy').format(dt) : rawDate;

    final weekdayRaw =
        (k['hafta_kuni'] ?? k['weekday'] ?? k['kun_nomi'] ?? rawDate)?.toString();
    final weekdayDisplay = BackendTextMapper.translateWeekday(weekdayRaw);

    if (weekdayDisplay != null && weekdayDisplay.isNotEmpty) {
      return '$dateDisplay · $weekdayDisplay';
    }
    return dateDisplay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(context.tr('rahbar_report_kunlik_title')),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RahbarReportView(
        fetch: () => sl<RahbarRemoteDataSource>().getKunlik(
          from: _fmt.format(_from),
          to: _fmt.format(_to),
        ),
        builder: (context, data) {
          final kunlar = (data['kunlar'] as List?) ?? const [];
          if (kunlar.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(context.tr('rahbar_no_data_in_range'))),
              ],
            );
          }
          // Newest first.
          final list = kunlar.reversed.toList();
          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.tr('rahbar_kunlik_legend'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final k = Map<String, dynamic>.from(list[i] as Map);
                    final foiz = ((k['foiz'] as num?) ?? 0).toDouble();
                    final dateLabel = _formatItemDate(k);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      dateLabel.isNotEmpty
                                          ? dateLabel
                                          : (k['sana'] ?? k['date'] ?? '').toString(),
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${foiz.toStringAsFixed(0)}%',
                                  style: GoogleFonts.outfit(
                                    color: _color(foiz),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (foiz / 100).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                color: _color(foiz),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    icon: Icons.check_circle_rounded,
                                    color: const Color(0xFF16A34A),
                                    value:
                                        '${k['kelgan'] ?? 0}/${k['jami'] ?? 0}',
                                    label: context.tr('attendance_present'),
                                  ),
                                ),
                                Expanded(
                                  child: _StatItem(
                                    icon: Icons.access_time_filled_rounded,
                                    color: Colors.orange.shade700,
                                    value: '${k['kechikkan'] ?? 0}',
                                    label: context.tr('rahbar_kpi_late'),
                                  ),
                                ),
                                Expanded(
                                  child: _StatItem(
                                    icon: Icons.assignment_late_rounded,
                                    color: Colors.blueGrey,
                                    value: '${k['arizali'] ?? 0}',
                                    label: context.tr(
                                      'rahbar_on_leave_short',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
