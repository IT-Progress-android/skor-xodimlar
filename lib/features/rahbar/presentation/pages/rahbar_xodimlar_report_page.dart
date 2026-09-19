import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_report_view.dart';
import 'package:url_launcher/url_launcher.dart';

/// §3.2 Xodimlar davomati — aggregate per staff over a date range (default 30 days).
class RahbarXodimlarReportPage extends StatefulWidget {
  const RahbarXodimlarReportPage({super.key});

  @override
  State<RahbarXodimlarReportPage> createState() =>
      _RahbarXodimlarReportPageState();
}

class _RahbarXodimlarReportPageState extends State<RahbarXodimlarReportPage> {
  final _fmt = DateFormat('yyyy-MM-dd');
  final _displayFmt = DateFormat('dd.MM.yyyy');
  late DateTime _from;
  late DateTime _to;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 30));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0D6E6E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  int _parseInt(dynamic val) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  double _getWorkedHours(Map<String, dynamic> x) {
    // 1. Direct hours (num or String)
    final rawHours =
        x['ishlangan_soat'] ??
        x['jami_ishlangan_soat'] ??
        x['soat'] ??
        x['jami_soat'] ??
        x['hours'] ??
        x['total_hours'] ??
        x['work_hours'];
    if (rawHours != null) {
      if (rawHours is num) return rawHours.toDouble();
      if (rawHours is String) {
        final parsed = double.tryParse(rawHours);
        if (parsed != null) return parsed;
      }
    }

    // 2. Minutes (num or String) -> convert to hours
    final rawMinutes =
        x['jami_ishlangan_daqiqa'] ??
        x['ishlangan_daqiqa'] ??
        x['minutes_worked'] ??
        x['worked_minutes'] ??
        x['minutes'] ??
        x['daqiqa'];
    if (rawMinutes != null) {
      if (rawMinutes is num) return rawMinutes.toDouble() / 60.0;
      if (rawMinutes is String) {
        final parsed = double.tryParse(rawMinutes);
        if (parsed != null) return parsed / 60.0;
      }
    }

    return 0.0;
  }

  String _formatHoursDisplay(double hours) {
    if (hours <= 0) return context.tr('rahbar_hours_worked', {'hours': '0'});
    if (hours % 1 == 0) {
      return context.tr('rahbar_hours_worked', {'hours': '${hours.toInt()}'});
    }
    return context.tr('rahbar_hours_worked', {
      'hours': hours.toStringAsFixed(1),
    });
  }

  Widget _buildAvatar(String? photoUrl, String name, {double radius = 20}) {
    final bool validUrl =
        photoUrl != null &&
        photoUrl.isNotEmpty &&
        !photoUrl.contains('localhost') &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'));

    Widget fallbackAvatar() => CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF0D6E6E).withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0D6E6E),
          fontSize: radius * 0.75,
        ),
      ),
    );

    if (!validUrl) return fallbackAvatar();

    return CachedNetworkImage(
      imageUrl: photoUrl,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(radius: radius, backgroundImage: imageProvider),
      placeholder: (context, url) => fallbackAvatar(),
      errorWidget: (context, url, error) => fallbackAvatar(),
    );
  }

  void _showStaffDetails(BuildContext context, Map<String, dynamic> x) {
    final name =
        (x['name'] ??
                x['xodim_name'] ??
                x['full_name'] ??
                context.tr('rahbar_staff_fallback'))
            .toString();
    final bolim = (x['bolim'] ?? x['department'] ?? '').toString();
    final lavozim = (x['lavozim'] ?? x['position'] ?? '').toString();
    final phone = (x['phone'] ?? x['telefon'] ?? '').toString();
    final photo = x['photo']?.toString();

    final kelganKun = _parseInt(
      x['kelgan_kun'] ?? x['days_present'] ?? x['kelgan'] ?? x['present'],
    );
    final kelmaganKun = _parseInt(
      x['kelmagan_kun'] ?? x['days_absent'] ?? x['kelmagan'] ?? x['absent'],
    );
    final kechikkanKun = _parseInt(
      x['kechikkan_kun'] ?? x['days_late'] ?? x['kechikkan'] ?? x['late'],
    );
    final arizaliKun = _parseInt(
      x['arizali_kun'] ??
          x['sababli_kun'] ??
          x['arizali'] ??
          x['sababli'] ??
          x['leave_days'],
    );
    final kechikishDaqiqa = _parseInt(
      x['kechikish_daqiqa'] ??
          x['jami_kechikish'] ??
          x['late_minutes'] ??
          x['delay'],
    );

    final hours = _getWorkedHours(x);
    final jamiKun = kelganKun + kelmaganKun + arizaliKun;
    final double foiz = jamiKun > 0
        ? (kelganKun / jamiKun * 100).clamp(0.0, 100.0)
        : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile Header
            Row(
              children: [
                _buildAvatar(photo, name, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (bolim.isNotEmpty || lavozim.isNotEmpty)
                        Text(
                          '$bolim${lavozim.isNotEmpty ? " · $lavozim" : ""}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (phone.isNotEmpty)
                  IconButton.filledTonal(
                    icon: const Icon(
                      Icons.phone_rounded,
                      color: Color(0xFF0D6E6E),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    tooltip: context.tr('rahbar_call'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Date Range Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: Color(0xFF0D6E6E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('rahbar_period_label', {
                      'from': _displayFmt.format(_from),
                      'to': _displayFmt.format(_to),
                    }),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D6E6E),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    context.tr('rahbar_attendance_percent', {
                      'percent': foiz.toStringAsFixed(0),
                    }),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: foiz >= 80
                          ? Colors.green.shade700
                          : (foiz >= 50
                                ? Colors.orange.shade800
                                : Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: foiz / 100.0,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foiz >= 80
                      ? const Color(0xFF16A34A)
                      : (foiz >= 50 ? Colors.orange : Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Detail KPI Grid
            Text(
              context.tr('rahbar_attendance_metrics_title'),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                _buildDetailKpiTile(
                  icon: Icons.check_circle_rounded,
                  title: context.tr('rahbar_kpi_days_present_title'),
                  value: context.tr('ariza_card_days_count', {
                    'days': '$kelganKun',
                  }),
                  color: const Color(0xFF16A34A),
                ),
                _buildDetailKpiTile(
                  icon: Icons.cancel_rounded,
                  title: context.tr('rahbar_kpi_days_absent_title'),
                  value: context.tr('ariza_card_days_count', {
                    'days': '$kelmaganKun',
                  }),
                  color: kelmaganKun > 0
                      ? const Color(0xFFDC2626)
                      : Colors.grey.shade600,
                ),
                _buildDetailKpiTile(
                  icon: Icons.access_time_filled_rounded,
                  title: context.tr('rahbar_kpi_days_late_title'),
                  value: context.tr('ariza_card_days_count', {
                    'days': '$kechikkanKun',
                  }),
                  color: kechikkanKun > 0
                      ? const Color(0xFFEA580C)
                      : Colors.grey.shade600,
                ),
                _buildDetailKpiTile(
                  icon: Icons.assignment_rounded,
                  title: context.tr('rahbar_kpi_days_leave_title'),
                  value: context.tr('ariza_card_days_count', {
                    'days': '$arizaliKun',
                  }),
                  color: arizaliKun > 0
                      ? Colors.purple.shade700
                      : Colors.grey.shade600,
                ),
                _buildDetailKpiTile(
                  icon: Icons.timer_rounded,
                  title: context.tr('rahbar_kpi_hours_total_title'),
                  value: _formatHoursDisplay(hours),
                  color: const Color(0xFF0D6E6E),
                ),
                _buildDetailKpiTile(
                  icon: Icons.warning_amber_rounded,
                  title: context.tr('rahbar_kpi_delay_total_title'),
                  value: kechikishDaqiqa > 0
                      ? (kechikishDaqiqa >= 60
                            ? context.tr('rahbar_hours_mins_short', {
                                'hours': '${kechikishDaqiqa ~/ 60}',
                                'mins': '${kechikishDaqiqa % 60}',
                              })
                            : context.tr('rahbar_minutes_plain', {
                                'mins': '$kechikishDaqiqa',
                              }))
                      : context.tr('rahbar_minutes_plain', {'mins': '0'}),
                  color: kechikishDaqiqa > 0
                      ? Colors.orange.shade900
                      : Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6E6E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  context.tr('close'),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailKpiTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
        iconTheme: const IconThemeData(color: Color(0xFF0D6E6E)),
        title: Text(
          context.tr('rahbar_report_xodimlar_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D6E6E),
            fontSize: 18,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _pickRange,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D6E6E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0D6E6E).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: Color(0xFF0D6E6E),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_displayFmt.format(_from)} — ${_displayFmt.format(_to)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D6E6E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: context.tr('rahbar_search_staff_name'),
                hintStyle: GoogleFonts.outfit(
                  color: AppColors.textHint,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF0D6E6E),
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF0D6E6E),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Report Content
          Expanded(
            child: RahbarReportView(
              key: ValueKey('${_fmt.format(_from)}_${_fmt.format(_to)}'),
              fetch: () => sl<RahbarRemoteDataSource>().getXodimlarReport(
                from: _fmt.format(_from),
                to: _fmt.format(_to),
              ),
              builder: (context, data) {
                final List<dynamic> rawXodimlar =
                    (data['xodimlar'] as List?) ?? const [];
                List<Map<String, dynamic>> xodimlar = rawXodimlar
                    .map(
                      (e) => e is Map
                          ? Map<String, dynamic>.from(e)
                          : <String, dynamic>{},
                    )
                    .toList();

                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  xodimlar = xodimlar.where((x) {
                    final name = (x['name'] ?? x['xodim_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final bolim = (x['bolim'] ?? '').toString().toLowerCase();
                    return name.contains(query) || bolim.contains(query);
                  }).toList();
                }

                if (xodimlar.isEmpty) {
                  return RahbarEmptyStateWidget(
                    icon: Icons.people_alt_rounded,
                    title: context.tr('rahbar_data_not_found'),
                    subtitle: query.isNotEmpty
                        ? context.tr('rahbar_search_no_staff', {'query': query})
                        : context.tr('rahbar_no_staff_data_period'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: xodimlar.length,
                  itemBuilder: (context, index) {
                    final x = xodimlar[index];
                    final name =
                        (x['name'] ??
                                x['xodim_name'] ??
                                x['full_name'] ??
                                context.tr('rahbar_staff_fallback'))
                            .toString();
                    final bolim = (x['bolim'] ?? x['department'] ?? '')
                        .toString();
                    final lavozim = (x['lavozim'] ?? x['position'] ?? '')
                        .toString();
                    final photo = x['photo']?.toString();

                    final kelganKun = _parseInt(
                      x['kelgan_kun'] ??
                          x['days_present'] ??
                          x['kelgan'] ??
                          x['present'],
                    );
                    final kelmaganKun = _parseInt(
                      x['kelmagan_kun'] ??
                          x['days_absent'] ??
                          x['kelmagan'] ??
                          x['absent'],
                    );
                    final kechikkanKun = _parseInt(
                      x['kechikkan_kun'] ??
                          x['days_late'] ??
                          x['kechikkan'] ??
                          x['late'],
                    );
                    final arizaliKun = _parseInt(
                      x['arizali_kun'] ??
                          x['sababli_kun'] ??
                          x['arizali'] ??
                          x['sababli'],
                    );

                    final double hours = _getWorkedHours(x);
                    final bool hasProblem = kelmaganKun > 5 || kechikkanKun > 3;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showStaffDetails(context, x),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: hasProblem
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : const Color(
                                      0xFF0D6E6E,
                                    ).withValues(alpha: 0.12),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Avatar, Name & Worked Hours badge
                              Row(
                                children: [
                                  _buildAvatar(photo, name, radius: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (bolim.isNotEmpty ||
                                            lavozim.isNotEmpty)
                                          Text(
                                            '$bolim${lavozim.isNotEmpty ? " · $lavozim" : ""}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF0D6E6E,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF0D6E6E,
                                        ).withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.timer_rounded,
                                          size: 14,
                                          color: Color(0xFF0D6E6E),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatHoursDisplay(hours),
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: const Color(0xFF0D6E6E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Row 2: Stats chips
                              Row(
                                children: [
                                  _buildStatChip(
                                    icon: Icons.check_circle_rounded,
                                    label: context.tr('ariza_card_days_count', {
                                      'days': '$kelganKun',
                                    }),
                                    subtitle: context.tr('attendance_present'),
                                    color: const Color(0xFF16A34A),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildStatChip(
                                    icon: Icons.cancel_rounded,
                                    label: context.tr('ariza_card_days_count', {
                                      'days': '$kelmaganKun',
                                    }),
                                    subtitle: context.tr('attendance_absent'),
                                    color: kelmaganKun > 0
                                        ? const Color(0xFFDC2626)
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildStatChip(
                                    icon: Icons.access_time_filled_rounded,
                                    label: context.tr('ariza_card_days_count', {
                                      'days': '$kechikkanKun',
                                    }),
                                    subtitle: context.tr('rahbar_kpi_late'),
                                    color: kechikkanKun > 0
                                        ? const Color(0xFFEA580C)
                                        : Colors.grey.shade600,
                                  ),
                                  if (arizaliKun > 0) ...[
                                    const SizedBox(width: 6),
                                    _buildStatChip(
                                      icon: Icons.assignment_rounded,
                                      label: context.tr(
                                        'ariza_card_days_count',
                                        {'days': '$arizaliKun'},
                                      ),
                                      subtitle: context.tr(
                                        'rahbar_on_leave_short',
                                      ),
                                      color: Colors.purple.shade700,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: color == Colors.grey.shade600
                        ? AppColors.textSecondary
                        : color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
