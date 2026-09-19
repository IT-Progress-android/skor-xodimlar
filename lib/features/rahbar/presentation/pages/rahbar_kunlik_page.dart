import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
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
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final k = Map<String, dynamic>.from(list[i] as Map);
              final foiz = ((k['foiz'] as num?) ?? 0).toDouble();
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${k['sana']} · ${k['hafta_kuni'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${foiz.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: _color(foiz),
                              fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 8),
                      Text(
                        context.tr('rahbar_kunlik_summary', {
                          'present': '${k['kelgan'] ?? 0}',
                          'total': '${k['jami'] ?? 0}',
                          'late': '${k['kechikkan'] ?? 0}',
                          'ariza': '${k['arizali'] ?? 0}',
                        }),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
