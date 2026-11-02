import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';

/// Bitta kunlik davomat ro'yxatini (`/rahbar/hisobot/kundalik?sana=`) yuklaydi.
typedef KundalikLoader =
    Future<List<RahbarStaffAttendanceEntity>> Function(DateTime day);

/// Rahbarning barcha arizalari (`/rahbar/arizalar`).
typedef ArizalarLoader = Future<List<RahbarArizaEntity>> Function();

/// Xodim kartasidagi qaysi ko'rsatkich bo'yicha kunlar ochiladi.
enum StaffDaysMode { present, absent, late, delay, worked, leave }

enum _DayKind { present, late, absent, leave, dayOff, unknown }

class _DayRecord {
  final DateTime day;
  final _DayKind kind;
  final String status;
  final String? checkIn;
  final String? checkOut;
  final int? delayMinutes;
  final int workedMinutes;
  final String? smena;
  final Map<String, dynamic>? ariza;

  const _DayRecord({
    required this.day,
    required this.kind,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.delayMinutes,
    this.workedMinutes = 0,
    this.smena,
    this.ariza,
  });

  bool get came => kind == _DayKind.present || kind == _DayKind.late;
}

/// Davr hisobotidagi har bir ko'rsatkichni kunma-kun ochib beradi: qaysi
/// kuni, soat nechada kelib-ketgani, qancha kechikkani, ishlagan vaqti va
/// arizalar sababi. Backend davr hisobotida kunlik tafsilot bermagani uchun
/// davrdagi har bir kunning kundalik hisobotidan yig'iladi.
class RahbarStaffDaysSheet extends StatefulWidget {
  final int staffId;
  final String staffName;
  final DateTime from;
  final DateTime to;
  final StaffDaysMode initialMode;
  final KundalikLoader loadDay;
  final ArizalarLoader loadArizalar;

  const RahbarStaffDaysSheet({
    super.key,
    required this.staffId,
    required this.staffName,
    required this.from,
    required this.to,
    required this.initialMode,
    required this.loadDay,
    required this.loadArizalar,
  });

  static Future<void> show(
    BuildContext context, {
    required int staffId,
    required String staffName,
    required DateTime from,
    required DateTime to,
    required StaffDaysMode initialMode,
    required KundalikLoader loadDay,
    required ArizalarLoader loadArizalar,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RahbarStaffDaysSheet(
        staffId: staffId,
        staffName: staffName,
        from: from,
        to: to,
        initialMode: initialMode,
        loadDay: loadDay,
        loadArizalar: loadArizalar,
      ),
    );
  }

  @override
  State<RahbarStaffDaysSheet> createState() => _RahbarStaffDaysSheetState();
}

class _RahbarStaffDaysSheetState extends State<RahbarStaffDaysSheet> {
  static const _lateColor = Color(0xFFEA580C);
  static const _parallel = 6;

  final _dateFmt = DateFormat('dd.MM.yyyy');
  final List<_DayRecord> _records = [];
  List<RahbarArizaEntity> _arizalar = const [];
  late StaffDaysMode _mode = widget.initialMode;
  int _loaded = 0;
  int _total = 0;
  int _failed = 0;
  bool _done = false;
  bool _arizalarLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadArizalar();
  }

  // ───────────────────────── Yuklash ─────────────────────────

  List<DateTime> _rangeDays() {
    final today = DateUtils.dateOnly(DateTime.now());
    var day = DateUtils.dateOnly(widget.from);
    var end = DateUtils.dateOnly(widget.to);
    if (end.isAfter(today)) end = today;
    final out = <DateTime>[];
    while (!day.isAfter(end)) {
      out.add(day);
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return out.reversed.toList();
  }

  Future<void> _load() async {
    final days = _rangeDays();
    setState(() => _total = days.length);
    for (var i = 0; i < days.length; i += _parallel) {
      final batch = days.skip(i).take(_parallel);
      await Future.wait(batch.map(_loadOne));
      if (!mounted) return;
    }
    if (mounted) setState(() => _done = true);
  }

  Future<void> _loadOne(DateTime day) async {
    try {
      final list = await widget.loadDay(day);
      final s = list.where((e) => e.id == widget.staffId).firstOrNull;
      if (s != null) {
        if (s.ariza != null) debugPrint('[XODIM KUNLAR] $day ariza=${s.ariza}');
        _records
          ..add(_toRecord(day, s))
          ..sort((a, b) => b.day.compareTo(a.day));
      }
    } catch (e) {
      debugPrint('[XODIM KUNLAR] $day xato: $e');
      _failed++;
    }
    if (mounted) setState(() => _loaded++);
  }

  Future<void> _loadArizalar() async {
    try {
      final all = await widget.loadArizalar();
      final name = _norm(widget.staffName);
      final from = DateUtils.dateOnly(widget.from);
      final to = DateUtils.dateOnly(widget.to);
      _arizalar = all.where((a) {
        if (_norm(a.xodimName) != name) return false;
        final f = DateTime.tryParse(a.fromDate);
        final t = DateTime.tryParse(a.toDate) ?? f;
        // Sanasi noma'lum ariza ham ko'rsatiladi — yashirib qo'ymaymiz.
        if (f == null || t == null) return true;
        return !t.isBefore(from) && !f.isAfter(to);
      }).toList()..sort((a, b) => b.fromDate.compareTo(a.fromDate));
    } catch (e) {
      debugPrint('[XODIM KUNLAR] arizalar xato: $e');
    }
    if (mounted) setState(() => _arizalarLoaded = true);
  }

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  _DayRecord _toRecord(DateTime day, RahbarStaffAttendanceEntity s) {
    final checkIn = _formatTime(s.checkIn);
    final checkOut = _formatTime(s.checkOut);
    final delay = _delayToMinutes(s.delay);
    var worked = s.ishlaganDaqiqa;
    if (worked <= 0 && checkIn != null && checkOut != null) {
      final diff = _toMinutes(checkOut)! - _toMinutes(checkIn)!;
      if (diff > 0) worked = diff;
    }
    return _DayRecord(
      day: day,
      kind: _classify(s, checkIn != null, delay, s.ariza != null),
      status: s.status,
      checkIn: checkIn,
      checkOut: checkOut,
      delayMinutes: delay,
      workedMinutes: worked,
      smena: _formatTime(s.smena),
      ariza: s.ariza,
    );
  }

  static _DayKind _classify(
    RahbarStaffAttendanceEntity s,
    bool hasIn,
    int? delay,
    bool hasAriza,
  ) {
    final st = s.status.trim().toLowerCase();
    if (_isDayOff(st)) return _DayKind.dayOff;
    if (_isLeave(st) || (hasAriza && !hasIn)) return _DayKind.leave;
    if (BackendTextMapper.isAbsentStatus(st) && !hasIn) return _DayKind.absent;
    if (BackendTextMapper.isLateStatus(st) || delay != null) {
      return _DayKind.late;
    }
    if (hasIn || BackendTextMapper.isPresentStatus(st)) return _DayKind.present;
    return _DayKind.unknown;
  }

  static bool _isDayOff(String st) =>
      st.contains('dam olish') ||
      st.contains('выходн') ||
      st.contains('day off') ||
      st.contains('weekend') ||
      st.contains('дем алыш');

  static bool _isLeave(String st) =>
      st.contains('ariza') ||
      st.contains('sabab') ||
      st.contains("ta'til") ||
      st.contains('tatil') ||
      st.contains('kasal') ||
      st.contains('отпуск') ||
      st.contains('больн') ||
      st.contains('уважит') ||
      st.contains('leave') ||
      st.contains('vacation') ||
      st.contains('sick') ||
      st.contains('арыз') ||
      st.contains('өргүү');

  /// `"15"`, `"+15 daq"`, `"00:15"`, `"1:05"` → daqiqa.
  static int? _delayToMinutes(String? raw) {
    if (raw == null || !BackendTextMapper.isLate(raw)) return null;
    final t = raw.trim();
    if (t.contains(':')) {
      final p = t.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      final h = int.tryParse(p[0]) ?? 0;
      final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
      final total = h * 60 + m;
      return total > 0 ? total : null;
    }
    final v = int.tryParse(t.replaceAll(RegExp(r'[^\d]'), ''));
    return v != null && v > 0 ? v : null;
  }

  /// `"2026-10-17 11:08:12"` / `"11:08"` → `"11:08"`; bo'sh bo'lsa `null`.
  static String? _formatTime(String? raw) {
    if (raw == null) return null;
    var t = raw.trim();
    if (t.isEmpty || t == '-' || t == '--:--' || t == 'null') return null;
    final parts = t.split(RegExp(r'[ T]'));
    if (parts.length > 1) t = parts[1];
    final hm = t.split(':');
    if (hm.length < 2 || int.tryParse(hm[0]) == null) return null;
    return '${hm[0].padLeft(2, '0')}:${hm[1].padLeft(2, '0').substring(0, 2)}';
  }

  static int? _toMinutes(String hm) {
    final p = hm.split(':');
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return h == null || m == null ? null : h * 60 + m;
  }

  /// Kelgan vaqt minus kechikish = ish boshlanishi kerak bo'lgan vaqt.
  static String? _expectedStart(_DayRecord d) {
    if (d.smena != null) return d.smena;
    final m = d.delayMinutes;
    final inMin = d.checkIn != null ? _toMinutes(d.checkIn!) : null;
    if (m == null || inMin == null || inMin - m < 0) return null;
    final start = inMin - m;
    return '${(start ~/ 60).toString().padLeft(2, '0')}:'
        '${(start % 60).toString().padLeft(2, '0')}';
  }

  // ───────────────────────── Formatlash ─────────────────────────

  String _duration(int minutes) {
    if (minutes >= 60) {
      return context.tr('rahbar_hours_mins_short', {
        'hours': '${minutes ~/ 60}',
        'mins': '${minutes % 60}',
      });
    }
    return context.tr('rahbar_minutes_plain', {'mins': '$minutes'});
  }

  String _days(int n) => context.tr('ariza_card_days_count', {'days': '$n'});

  String _weekday(DateTime d) {
    const keys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return context.tr('weekday_${keys[d.weekday - 1]}');
  }

  String _formatDate(String raw) {
    final d = DateTime.tryParse(raw);
    return d != null ? _dateFmt.format(d) : raw;
  }

  Color _modeColor(StaffDaysMode m) {
    switch (m) {
      case StaffDaysMode.present:
        return context.colors.success;
      case StaffDaysMode.absent:
        return context.colors.error;
      case StaffDaysMode.late:
        return _lateColor;
      case StaffDaysMode.delay:
        return Colors.orange.shade900;
      case StaffDaysMode.worked:
        return context.colors.primary;
      case StaffDaysMode.leave:
        return context.isDarkMode
            ? Colors.purple.shade200
            : Colors.purple.shade700;
    }
  }

  IconData _modeIcon(StaffDaysMode m) {
    switch (m) {
      case StaffDaysMode.present:
        return Icons.check_circle_rounded;
      case StaffDaysMode.absent:
        return Icons.cancel_rounded;
      case StaffDaysMode.late:
        return Icons.access_time_filled_rounded;
      case StaffDaysMode.delay:
        return Icons.warning_amber_rounded;
      case StaffDaysMode.worked:
        return Icons.timer_rounded;
      case StaffDaysMode.leave:
        return Icons.assignment_rounded;
    }
  }

  String _modeTitle(StaffDaysMode m) => context.tr('rahbar_days_tab_${m.name}');

  // ───────────────────────── Ma'lumot tanlash ─────────────────────────

  List<_DayRecord> get _modeRecords {
    switch (_mode) {
      case StaffDaysMode.present:
        return _records.where((r) => r.came).toList();
      case StaffDaysMode.absent:
        return _records.where((r) => r.kind == _DayKind.absent).toList();
      case StaffDaysMode.late:
        return _records.where((r) => r.kind == _DayKind.late).toList();
      case StaffDaysMode.delay:
        return _records.where((r) => r.kind == _DayKind.late).toList()..sort(
          (a, b) => (b.delayMinutes ?? 0).compareTo(a.delayMinutes ?? 0),
        );
      case StaffDaysMode.worked:
        return _records.where((r) => r.workedMinutes > 0 || r.came).toList();
      case StaffDaysMode.leave:
        return _records.where((r) => r.kind == _DayKind.leave).toList();
    }
  }

  List<(String, String)> _summary(List<_DayRecord> list) {
    final late = _records.where((r) => r.kind == _DayKind.late).toList();
    final lateTotal = late.fold<int>(0, (s, r) => s + (r.delayMinutes ?? 0));
    final lateWithMin = late.where((r) => r.delayMinutes != null).length;
    switch (_mode) {
      case StaffDaysMode.present:
        return [
          (context.tr('rahbar_kpi_days_present_title'), _days(list.length)),
          (
            context.tr('rahbar_days_on_time'),
            _days(list.where((r) => r.kind == _DayKind.present).length),
          ),
          (context.tr('status_kechikkan'), _days(late.length)),
        ];
      case StaffDaysMode.absent:
        return [
          (context.tr('rahbar_kpi_days_absent_title'), _days(list.length)),
          (
            context.tr('rahbar_days_day_off'),
            _days(_records.where((r) => r.kind == _DayKind.dayOff).length),
          ),
          (context.tr('rahbar_days_period_days'), _days(_records.length)),
        ];
      case StaffDaysMode.late:
      case StaffDaysMode.delay:
        return [
          (context.tr('rahbar_late_days_count'), _days(late.length)),
          (context.tr('rahbar_kpi_delay_total_title'), _duration(lateTotal)),
          (
            context.tr('rahbar_late_days_average'),
            _duration(lateWithMin > 0 ? (lateTotal / lateWithMin).round() : 0),
          ),
        ];
      case StaffDaysMode.worked:
        final total = list.fold<int>(0, (s, r) => s + r.workedMinutes);
        final withTime = list.where((r) => r.workedMinutes > 0).toList();
        final longest = withTime.fold<int>(
          0,
          (m, r) => r.workedMinutes > m ? r.workedMinutes : m,
        );
        return [
          (context.tr('rahbar_days_total'), _duration(total)),
          (
            context.tr('rahbar_days_avg_per_day'),
            _duration(
              withTime.isNotEmpty ? (total / withTime.length).round() : 0,
            ),
          ),
          (context.tr('rahbar_days_longest'), _duration(longest)),
        ];
      case StaffDaysMode.leave:
        return [
          (context.tr('rahbar_days_requests'), '${_arizalar.length}'),
          (
            context.tr('rahbar_days_approved'),
            '${_arizalar.where((a) => _arizaColorKey(a) == 1).length}',
          ),
          (context.tr('rahbar_days_leave_days'), _days(list.length)),
        ];
    }
  }

  static String? _arizaField(Map<String, dynamic>? a, List<String> keys) {
    if (a == null) return null;
    for (final k in keys) {
      final v = a[k]?.toString().trim();
      if (v != null && v.isNotEmpty && v != 'null') return v;
    }
    return null;
  }

  /// 1 — tasdiqlangan, -1 — rad etilgan, 0 — kutilmoqda.
  static int _arizaColorKey(RahbarArizaEntity a) {
    final s = '${a.status} ${a.statusNomi}'.toLowerCase();
    if (s.contains('tasdiq') ||
        s.contains('approved') ||
        s.contains('одобр') ||
        s.contains('бекит')) {
      return 1;
    }
    if (s.contains('rad') ||
        s.contains('reject') ||
        s.contains('отклон') ||
        s.contains('четке')) {
      return -1;
    }
    return 0;
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final color = _modeColor(_mode);
    final list = _modeRecords;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      padding: EdgeInsets.fromLTRB(0, 12, 0, 16 + bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildHeader(color),
          ),
          const SizedBox(height: 14),
          _buildTabs(),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final (i, s) in _summary(list).indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _summaryBox(s.$1, s.$2, color),
                ],
              ],
            ),
          ),
          if (!_done) _buildProgress(color),
          const SizedBox(height: 12),
          Expanded(child: _buildList(list, color)),
          if (_done && _failed > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                context.tr('rahbar_late_days_partial', {'count': '$_failed'}),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: context.colors.error,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.tr('close'),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(_modeIcon(_mode), color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.staffName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                '${_dateFmt.format(widget.from)} — '
                '${_dateFmt.format(widget.to)}',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: StaffDaysMode.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = StaffDaysMode.values[i];
          final selected = m == _mode;
          final c = _modeColor(m);
          return GestureDetector(
            onTap: () => setState(() => _mode = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? c : c.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? c : c.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _modeIcon(m),
                    size: 16,
                    color: selected ? Colors.white : c,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _modeTitle(m),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : c,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgress(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _total > 0 ? _loaded / _total : null,
              minHeight: 4,
              backgroundColor: context.colors.surfaceStrong,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('rahbar_late_days_loading', {
              'done': '$_loaded',
              'total': '$_total',
            }),
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: context.colors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<_DayRecord> list, Color color) {
    final isLeave = _mode == StaffDaysMode.leave;
    final children = <Widget>[
      if (isLeave)
        for (final a in _arizalar) _buildArizaCard(a),
      for (final r in list) _buildDayCard(r, color),
    ];

    final stillLoading = !_done || (isLeave && !_arizalarLoaded);
    if (children.isEmpty) {
      return Center(
        child: stillLoading
            ? SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: color,
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  context.tr('rahbar_days_empty'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => children[i],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _cardShell({
    required Widget leading,
    required Widget body,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: body),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _dateBlock(DateTime day) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Text(
            '${day.day}',
            style: GoogleFonts.outfit(
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          Text(
            DateFormat('MM.yy').format(day),
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String text, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor ?? context.colors.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(_DayRecord r, Color color) {
    final lines = <Widget>[];
    Widget? trailing;

    final arrivedLeft = r.checkIn == null
        ? null
        : r.checkOut != null
        ? context.tr('rahbar_days_arrived_left', {
            'in': r.checkIn!,
            'out': r.checkOut!,
          })
        : context.tr('rahbar_days_arrived_no_out', {'in': r.checkIn!});

    switch (_mode) {
      case StaffDaysMode.present:
        if (arrivedLeft != null) {
          lines.add(_infoLine(Icons.login_rounded, arrivedLeft));
        }
        trailing = r.kind == _DayKind.late && r.delayMinutes != null
            ? _chip('+${_duration(r.delayMinutes!)}', _lateColor)
            : _chip(context.tr('rahbar_days_on_time'), context.colors.success);
      case StaffDaysMode.absent:
        trailing = _chip(context.tr('attendance_absent'), color);
      case StaffDaysMode.late:
      case StaffDaysMode.delay:
        final start = _expectedStart(r);
        lines.add(
          _infoLine(
            Icons.login_rounded,
            start != null
                ? context.tr('rahbar_late_days_arrived_of', {
                    'time': r.checkIn ?? '--:--',
                    'start': start,
                  })
                : context.tr('rahbar_late_days_arrived', {
                    'time': r.checkIn ?? '--:--',
                  }),
          ),
        );
        trailing = _chip(
          r.delayMinutes != null
              ? '+${_duration(r.delayMinutes!)}'
              : context.tr('status_kechikkan'),
          color,
        );
      case StaffDaysMode.worked:
        if (arrivedLeft != null) {
          lines.add(_infoLine(Icons.login_rounded, arrivedLeft));
        }
        trailing = _chip(
          r.workedMinutes > 0 ? _duration(r.workedMinutes) : '—',
          color,
        );
      case StaffDaysMode.leave:
        final a = r.ariza;
        final type = _arizaField(a, const ['turi_nomi', 'turi', 'type_name']);
        final reason = _arizaField(a, const [
          'izoh',
          'sabab',
          'reason',
          'comment',
        ]);
        lines.add(
          _infoLine(
            Icons.info_outline_rounded,
            type ?? r.status,
            iconColor: color,
          ),
        );
        if (reason != null) {
          lines.add(_infoLine(Icons.notes_rounded, reason, iconColor: color));
        }
    }

    return _cardShell(
      leading: _dateBlock(r.day),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _weekday(r.day),
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          for (final l in lines) ...[const SizedBox(height: 4), l],
        ],
      ),
      trailing: trailing,
    );
  }

  Widget _buildArizaCard(RahbarArizaEntity a) {
    final key = _arizaColorKey(a);
    final statusColor = key == 1
        ? context.colors.success
        : key == -1
        ? context.colors.error
        : Colors.orange.shade800;
    final reason = (a.izoh ?? '').trim();
    final leaveColor = _modeColor(StaffDaysMode.leave);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: leaveColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: leaveColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_rounded, size: 18, color: leaveColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  a.turiNomi.isNotEmpty
                      ? a.turiNomi
                      : context.tr('rahbar_days_tab_leave'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              _chip(
                a.statusNomi.isNotEmpty ? a.statusNomi : a.status,
                statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoLine(
            Icons.date_range_rounded,
            context.tr('rahbar_days_ariza_period', {
              'from': _formatDate(a.fromDate),
              'to': _formatDate(a.toDate),
              'days': '${a.kunlar}',
            }),
            iconColor: leaveColor,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('rahbar_days_reason'),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: context.colors.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason.isNotEmpty
                      ? reason
                      : context.tr('rahbar_days_no_reason'),
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    height: 1.35,
                    color: reason.isNotEmpty
                        ? context.colors.textPrimary
                        : context.colors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
