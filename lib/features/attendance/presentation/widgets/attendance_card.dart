import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/core/utils/date_formatter.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/features/attendance/domain/entities/attendance_entity.dart';

class AttendanceCard extends StatefulWidget {
  final AttendanceReportEntity report;

  const AttendanceCard({super.key, required this.report});

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    // status allaqachon BackendTextMapper orqali ilovaning tiliga o'girilgan.
    final presentText = AppLocalizations.trStatic('attendance_present');
    final lateText = AppLocalizations.trStatic('status_kechikkan');
    final bool isPresent =
        report.checkIn != null ||
        report.status == presentText ||
        report.status == lateText;
    final bool isLate = BackendTextMapper.isLate(report.delay);

    final bool hasAriza = report.ariza != null;

    // Status-based gradient colors
    List<Color> statusGradient;
    if (isPresent && isLate) {
      statusGradient = const [
        Color(0xFFF59E0B),
        Color(0xFFFBBF24),
        Color(0xFFD97706),
        Color(0xFFF59E0B),
      ];
    } else if (isPresent) {
      statusGradient = const [
        Color(0xFF16A34A),
        Color(0xFF22C55E),
        Color(0xFF15803D),
        Color(0xFF16A34A),
      ];
    } else if (hasAriza) {
      statusGradient = const [
        Color(0xFF0D6E6E),
        Color(0xFF139797),
        Color(0xFF26BBAA),
        Color(0xFF0D6E6E),
      ];
    } else {
      statusGradient = const [
        Color(0xFFDC2626),
        Color(0xFFEF4444),
        Color(0xFFB91C1C),
        Color(0xFFDC2626),
      ];
    }

    // report.weekday — BackendTextMapper.translateWeekday orqali allaqachon
    // ilovaning tiliga o'girilgan. Shunchaki ko'rsatamiz.
    final String rawDate = report.date.trim();
    String displayDate;
    if (rawDate.isNotEmpty) {
      displayDate = report.weekday != null && report.weekday!.isNotEmpty
          ? '$rawDate · ${report.weekday}'
          : rawDate;
    } else {
      displayDate = context.tr('today');
    }

    final hasSessions = report.sessions.isNotEmpty;
    final hasEvents = report.events.isNotEmpty;
    final canExpand = hasSessions || hasEvents;

    final sessionsCount = report.counts.sessions > 0
        ? report.counts.sessions
        : (hasSessions ? report.sessions.length : (report.hasRecord ? 1 : 0));
    final eventsCount = report.counts.events > 0
        ? report.counts.events
        : (hasEvents
              ? report.events.length
              : (hasSessions ? report.sessions.length * 2 : 0));
    final openCount = report.counts.open;

    return AnimatedRotatingBorderContainer(
      borderRadius: 16,
      borderWidth: 2.0,
      gradientColors: statusGradient,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: isPresent && isLate
                          ? Colors.orange.shade800
                          : isPresent
                          ? Colors.green.shade700
                          : hasAriza
                          ? const Color(0xFF0D6E6E)
                          : Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayDate,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isPresent && isLate
                            ? Colors.orange.shade800
                            : isPresent
                            ? Colors.green.shade700
                            : hasAriza
                            ? const Color(0xFF0D6E6E)
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                if (canExpand)
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpanded
                              ? context.tr('close')
                              : context.tr('attendance_details'),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D6E6E),
                          ),
                        ),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: const Color(0xFF0D6E6E),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Time & Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.login_rounded,
                      size: 18,
                      color: Color(0xFF0D6E6E),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      report.checkIn ?? '--:--',
                      style: GoogleFonts.outfit(
                        color: report.checkIn != null
                            ? Colors.black87
                            : Colors.grey,
                        fontWeight: report.checkIn != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Color(0xFFF5A623),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      report.checkOut ?? '--:--',
                      style: GoogleFonts.outfit(
                        color: report.checkOut != null
                            ? Colors.black87
                            : Colors.grey,
                        fontWeight: report.checkOut != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPresent
                            ? Colors.green.withValues(alpha: 0.1)
                            : (hasAriza
                                  ? const Color(
                                      0xFF0D6E6E,
                                    ).withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPresent
                            ? context.tr('attendance_present')
                            : context.tr('attendance_absent'),
                        style: GoogleFonts.outfit(
                          color: isPresent
                              ? Colors.green.shade800
                              : (hasAriza
                                    ? const Color(0xFF0D6E6E)
                                    : Colors.red.shade800),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isLate) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_filled_rounded,
                              size: 11,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              context.tr('home_delay_label', {
                                'delay': DateFormatter.formatDelayToHours(
                                  report.delay!,
                                ),
                              }),
                              style: GoogleFonts.outfit(
                                color: Colors.orange.shade900,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // Multi-Check Summary info per Kop-Martalik-Davomat.pdf §5.3
            if (sessionsCount > 0 || eventsCount > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    context.tr('attendance_sessions_summary', {
                      'sessions': '$sessionsCount',
                      'events': '$eventsCount',
                    }),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (openCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        context.tr('attendance_open_sessions', {
                          'count': '$openCount',
                        }),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Ariza Badge if present
            if (hasAriza) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6E6E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0D6E6E).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flight_takeoff_rounded,
                      size: 14,
                      color: Color(0xFF0D6E6E),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      report.ariza!.nomi,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D6E6E),
                      ),
                    ),
                    if (report.ariza!.izoh != null &&
                        report.ariza!.izoh!.isNotEmpty) ...[
                      Text(
                        ' · ${report.ariza!.izoh}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Expanded Sessions & Events Breakdown per Kop-Martalik-Davomat.pdf §5.2
            if (canExpand && _isExpanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Sessions
              if (hasSessions) ...[
                Text(
                  context.tr('attendance_sessions_title'),
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                ...report.sessions.map((s) {
                  final bool isComplete = s.complete;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isComplete
                            ? Colors.grey.shade200
                            : Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isComplete
                              ? Icons.check_circle_rounded
                              : Icons.warning_amber_rounded,
                          size: 18,
                          color: isComplete ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${s.checkIn ?? '—'}  →  ${s.checkOut ?? '—'}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        Text(
                          isComplete
                              ? context.tr('attendance_session_minutes', {
                                  'minutes': '${s.minutes ?? 0}',
                                })
                              : (s.note ??
                                    context.tr('attendance_session_open')),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: isComplete
                                ? FontWeight.w600
                                : FontWeight.bold,
                            color: isComplete
                                ? const Color(0xFF0D6E6E)
                                : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // Individual Events (Har bir harakat)
              if (hasEvents) ...[
                const SizedBox(height: 10),
                Text(
                  context.tr('attendance_events_title'),
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                ...report.events.map((ev) {
                  final bool isIn = ev.isIn;
                  final displayTime = ev.timeFull ?? ev.time;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isIn
                          ? Colors.green.withValues(alpha: 0.05)
                          : Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isIn ? Icons.login_rounded : Icons.logout_rounded,
                          size: 16,
                          color: isIn
                              ? const Color(0xFF0D6E6E)
                              : const Color(0xFFF5A623),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ev.label.isNotEmpty
                              ? ev.label
                              : (isIn
                                    ? context.tr('attendance_event_in')
                                    : context.tr('attendance_event_out')),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: isIn
                                ? const Color(0xFF0D6E6E)
                                : const Color(0xFFF5A623),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayTime,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        if (ev.device != null && ev.device!.isNotEmpty) ...[
                          const Spacer(),
                          Flexible(
                            child: Text(
                              ev.device!,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
