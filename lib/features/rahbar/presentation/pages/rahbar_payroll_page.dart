import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/dio_retry_helper.dart';
import 'package:skore_hodimlar/core/utils/money_input_formatter.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/core/widgets/pull_to_refresh.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';

/// Summa minglar nuqta bilan: `1.290.000` (kiritish maydonlari bilan bir xil).
String _fmt(double v) =>
    '${v < 0 ? '−' : ''}${formatMoneyDigits(v.abs().round().toString())}';

class RahbarPayrollPage extends StatefulWidget {
  const RahbarPayrollPage({super.key});

  @override
  State<RahbarPayrollPage> createState() => _RahbarPayrollPageState();
}

class _RahbarPayrollPageState extends State<RahbarPayrollPage> {
  static const _periods = ['hafta', 'oy', 'yil'];

  String _davr = 'oy';

  /// Tanlangan davr ichidagi istalgan kun; strelkalar uni suradi.
  DateTime _anchor = DateTime.now();

  /// Tanlangan filial tabi: `null` — hammasi, [_noFilial] — filialsizlar.
  String? _filial;
  static const _noFilial = '__none__';

  /// Tashkilotning joriy jarima sozlamasi — "Jarima" summalari shunga
  /// qarab darhol qayta hisoblanadi (sozlama o'zgarsa, ro'yxat ham).
  PayrollSettings? _settings;

  Future<void> _loadSettings() async {
    try {
      final s = await sl<RahbarRemoteDataSource>().getPayrollSettings();
      if (mounted) setState(() => _settings = s);
    } catch (_) {}
  }

  void _reloadAll() {
    _load();
    _loadSettings();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    final bloc = context.read<RahbarBloc>();
    final state = bloc.state;
    if (state is RahbarPayrollLoaded) {
      _davr = state.report.davr;
    } else if (state is! RahbarLoading) {
      _load();
    }
  }

  RahbarPayrollReport _withFines(RahbarPayrollReport r) {
    final s = _settings;
    if (s == null) return r;
    return RahbarPayrollReport(
      davr: r.davr,
      from: r.from,
      to: r.to,
      items: [for (final e in r.items) e.withFineFrom(s)],
    );
  }

  void _load() {
    context.read<RahbarBloc>().add(
      LoadRahbarPayroll(
        davr: _davr,
        sana: _anchor.toIso8601String().substring(0, 10),
      ),
    );
  }

  void _shift(int dir) {
    setState(() {
      _anchor = switch (_davr) {
        'hafta' => _anchor.add(Duration(days: 7 * dir)),
        'yil' => DateTime(_anchor.year + dir, _anchor.month, 1),
        _ => DateTime(_anchor.year, _anchor.month + dir, 1),
      };
    });
    _load();
  }

  bool get _canGoForward {
    final now = DateTime.now();
    return switch (_davr) {
      'hafta' => _anchor.add(const Duration(days: 7)).isBefore(now),
      'yil' => _anchor.year < now.year,
      _ =>
        _anchor.year < now.year ||
            (_anchor.year == now.year && _anchor.month < now.month),
    };
  }

  String _periodLabel() {
    final d = DateFormat('dd.MM');
    switch (_davr) {
      case 'hafta':
        final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${d.format(start)} – ${d.format(end)}';
      case 'yil':
        return '${_anchor.year}';
      default:
        return DateFormat('MM.yyyy').format(_anchor);
    }
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
          context.tr('rahbar_payroll_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.colors.primary,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('rahbar_payroll_settings_tooltip'),
            icon: Icon(Icons.tune_rounded, color: context.colors.primary),
            onPressed: () =>
                _FineSettingsSheet.show(context, onSaved: _reloadAll),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => refreshWithMinDelay(_reloadAll),
              color: context.colors.primary,
              child: BlocBuilder<RahbarBloc, RahbarState>(
                buildWhen: (prev, curr) =>
                    curr is RahbarLoading ||
                    curr is RahbarPayrollLoaded ||
                    curr is RahbarError,
                builder: (context, state) {
                  if (state is RahbarPayrollLoaded) {
                    return _buildList(_withFines(state.report));
                  } else if (state is RahbarError) {
                    return RahbarEmptyStateWidget(
                      icon: Icons.error_outline_rounded,
                      title: context.tr('error_occurred_title'),
                      subtitle: state.message,
                      onRefresh: _load,
                    );
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      color: context.colors.primary,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodBar() {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                for (final p in _periods)
                  ButtonSegment(
                    value: p,
                    label: Text(context.tr('rahbar_payroll_period_$p')),
                  ),
              ],
              selected: {_davr},
              showSelectedIcon: false,
              onSelectionChanged: (v) {
                setState(() {
                  _davr = v.first;
                  _anchor = DateTime.now();
                });
                _load();
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _shift(-1),
              ),
              Text(
                _periodLabel(),
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _canGoForward ? () => _shift(1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(RahbarPayrollReport all) {
    if (all.items.isEmpty) {
      return RahbarEmptyStateWidget(
        icon: Icons.account_balance_wallet_rounded,
        title: context.tr('rahbar_payroll_empty_title'),
        subtitle: context.tr('rahbar_payroll_empty_desc'),
        onRefresh: _load,
      );
    }

    // Filial tablari: nom bo'yicha, filialsizlar oxirida.
    final groups = <String, ({String name, int count})>{};
    for (final e in all.items) {
      final key = e.filialKey ?? _noFilial;
      final name = key == _noFilial
          ? context.tr('rahbar_payroll_filial_none')
          : e.filialName?.trim().isNotEmpty == true
          ? e.filialName!.trim()
          : '#${e.filialId}';
      final g = groups[key];
      groups[key] = (name: g?.name ?? name, count: (g?.count ?? 0) + 1);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == _noFilial) return 1;
        if (b == _noFilial) return -1;
        return groups[a]!.name.toLowerCase().compareTo(
          groups[b]!.name.toLowerCase(),
        );
      });
    final selected = groups.containsKey(_filial) ? _filial : null;
    final report = selected == null
        ? all
        : RahbarPayrollReport(
            davr: all.davr,
            from: all.from,
            to: all.to,
            items: [
              for (final e in all.items)
                if ((e.filialKey ?? _noFilial) == selected) e,
            ],
          );

    final list = _buildItems(report);
    // Bitta filial bo'lsa tab kerak emas.
    if (keys.length < 2) return list;
    return Column(
      children: [
        _FilialTabs(
          tabs: [
            (
              key: null,
              name: context.tr('rahbar_payroll_filial_all'),
              count: all.items.length,
            ),
            for (final k in keys)
              (key: k, name: groups[k]!.name, count: groups[k]!.count),
          ],
          selected: selected,
          onSelected: (k) => setState(() => _filial = k),
        ),
        Expanded(child: list),
      ],
    );
  }

  Widget _buildItems(RahbarPayrollReport report) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: report.items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildSummary(report);
        final item = report.items[index - 1];
        return _PayrollCard(
          item: item,
          onTap: () => _StaffStatsSheet.show(
            context,
            item,
            davr: _davr,
            sana: _anchor.toIso8601String().substring(0, 10),
            onSaved: _load,
          ),
        );
      },
    );
  }

  Widget _buildSummary(RahbarPayrollReport report) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('rahbar_payroll_total', {
                'amount': _fmt(report.jamiTolanadi),
              }),
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (report.jamiJarima > 0)
            Text(
              context.tr('rahbar_payroll_fine', {
                'amount': _fmt(report.jamiJarima),
              }),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.error,
              ),
            ),
        ],
      ),
    );
  }
}

/// Filiallar bo'yicha gorizontal tab qatori (soni bilan).
class _FilialTabs extends StatelessWidget {
  final List<({String? key, String name, int count})> tabs;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _FilialTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = tabs[i];
          final active = t.key == selected;
          return Material(
            color: active ? c.primary : c.background,
            shape: StadiumBorder(
              side: BorderSide(color: active ? c.primary : c.border),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onSelected(t.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Text(
                      t.name,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : c.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withValues(alpha: 0.25)
                            : c.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${t.count}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : c.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PayrollCard extends StatelessWidget {
  final RahbarPayrollItemEntity item;
  final VoidCallback onTap;

  const _PayrollCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final small = GoogleFonts.outfit(
      fontSize: 12.5,
      color: context.colors.textSecondary,
    );
    final bold = GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: context.colors.textPrimary,
    );

    return AnimatedRotatingBorderContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 16,
      borderWidth: 2.0,
      gradientColors: [
        context.colors.primary,
        const Color(0xFF139797),
        const Color(0xFF26BBAA),
        context.colors.primary,
      ],
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  // Stavka yo'q — hisoblanmagan, "0 so'm" chalg'itmasin.
                  if (item.stavka <= 0 && item.maosh == 0)
                    Text(
                      context.tr('rahbar_payroll_set_rate'),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: context.colors.warning,
                      ),
                    )
                  else
                    Text(
                      context.tr('rahbar_payroll_sum', {
                        'amount': _fmt(item.maosh),
                      }),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: context.colors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${item.bolim} · ${item.lavozim}', style: small),
              const SizedBox(height: 4),
              Text(_ruleText(context), style: small),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('rahbar_payroll_days_present', {
                      'days': '${item.kelganKun}',
                    }),
                    style: bold,
                  ),
                  Text(
                    context.tr('rahbar_payroll_hours_worked', {
                      'hours': item.jamiIshlanganSoat.toStringAsFixed(1),
                    }),
                    style: bold.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (item.qoshimchaSoat > 0 ||
                  item.kechikishSoni > 0 ||
                  !item.jarimaYoqilgan) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (item.qoshimchaSoat > 0)
                      Text(
                        '${context.tr('rahbar_payroll_overtime', {'hours': item.qoshimchaSoat.toStringAsFixed(1)})} · '
                        '${item.qoshimchaTolanadi ? context.tr('rahbar_payroll_overtime_paid', {'amount': _fmt(item.qoshimchaSumma)}) : context.tr('rahbar_payroll_overtime_unpaid')}',
                        style: small.copyWith(color: context.colors.success),
                      ),
                    if (item.kechikishSoni > 0)
                      Text(
                        context.tr('rahbar_payroll_late', {
                          'count': '${item.kechikishSoni}',
                          'min': '${item.kechikishDaqiqa}',
                        }),
                        style: small.copyWith(color: context.colors.warning),
                      ),
                    if (!item.jarimaYoqilgan)
                      Text(context.tr('rahbar_payroll_fine_off'), style: small)
                    else if (item.jarima > 0)
                      Text(
                        context.tr('rahbar_payroll_fine', {
                          'amount': _fmt(item.jarima),
                        }),
                        style: small.copyWith(color: context.colors.error),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _ruleText(BuildContext context) {
    final type = context.tr('rahbar_payroll_type_${item.tolovTuri}');
    if (item.stavka <= 0) {
      return '$type · ${context.tr('rahbar_payroll_rule_none')}';
    }
    return '$type · ${context.tr('rahbar_payroll_rule_${item.tolovTuri}', {'amount': _fmt(item.stavka)})}';
  }
}

/// Xodimni bosganda: davr bo'yicha to'liq statistika — qancha oladi,
/// qancha kechikkan, jarima qanday hisoblangan.
class _StaffStatsSheet extends StatelessWidget {
  final RahbarPayrollItemEntity item;
  final String davr;
  final String sana;

  /// "Maoshni sozlash" — sahifa kontekstida ochiladi (bu sheet yopilgach).
  final VoidCallback onEdit;

  const _StaffStatsSheet({
    required this.item,
    required this.davr,
    required this.sana,
    required this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    RahbarPayrollItemEntity item, {
    required String davr,
    required String sana,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StaffStatsSheet(
        item: item,
        davr: davr,
        sana: sana,
        onEdit: () => _StaffPayRuleSheet.show(
          context,
          item,
          davr: davr,
          sana: sana,
          onSaved: onSaved,
        ),
      ),
    );
  }

  static String _duration(BuildContext context, int min) => min >= 60
      ? context.tr('rahbar_stop_duration_hm', {
          'h': '${min ~/ 60}',
          'm': '${min % 60}',
        })
      : context.tr('rahbar_stop_duration_m', {'m': '$min'});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = sl<RahbarRemoteDataSource>().getPayrollSettings();
    final head = GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: c.textSecondary,
      letterSpacing: 0.3,
    );

    Widget row(String label, String value, {Color? color, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(fontSize: 14, color: c.textPrimary),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? c.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    Widget card(List<Widget> children) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(children: children),
    );

    String sum(double v) =>
        context.tr('rahbar_payroll_sum', {'amount': _fmt(v)});
    final noRate = item.stavka <= 0;
    final asosiy = (item.hisoblangan - item.qoshimchaSumma).clamp(
      0,
      double.infinity,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            item.name,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          Text(
            [
              if (item.filialName?.isNotEmpty == true) item.filialName!,
              if (item.bolim.isNotEmpty) item.bolim,
              if (item.lavozim.isNotEmpty) item.lavozim,
            ].join(' · '),
            style: GoogleFonts.outfit(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 14),

          // Asosiy natija: qancha oladi.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('rahbar_stats_payable_title'),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  noRate && item.maosh == 0
                      ? context.tr('rahbar_payroll_set_rate')
                      : sum(item.maosh),
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  noRate
                      ? context.tr('rahbar_payroll_rule_none')
                      : '${context.tr('rahbar_payroll_type_${item.tolovTuri}')} · '
                            '${context.tr('rahbar_payroll_rule_${item.tolovTuri}', {'amount': _fmt(item.stavka)})}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(context.tr('rahbar_stats_attendance'), style: head),
          card([
            row(
              context.tr('rahbar_stats_days'),
              context.tr('rahbar_stats_days_value', {'n': '${item.kelganKun}'}),
            ),
            if (item.arizaKun > 0)
              row(
                context.tr('rahbar_stats_ariza_days'),
                context.tr('rahbar_stats_days_value', {
                  'n': '${item.arizaKun}',
                }),
              ),
            row(
              context.tr('rahbar_stats_hours'),
              context.tr('rahbar_stats_hours_value', {
                'h': item.jamiIshlanganSoat.toStringAsFixed(1),
              }),
            ),
            if (item.qoshimchaSoat > 0)
              row(
                context.tr('rahbar_stats_overtime_hours'),
                context.tr('rahbar_stats_hours_value', {
                  'h': item.qoshimchaSoat.toStringAsFixed(1),
                }),
                color: c.success,
              ),
            row(
              context.tr('rahbar_stats_late_count'),
              context.tr('rahbar_stats_times_value', {
                'n': '${item.kechikishSoni}',
              }),
              color: item.kechikishSoni > 0 ? c.warning : null,
            ),
            row(
              context.tr('rahbar_stats_late_total'),
              item.kechikishDaqiqa > 0
                  ? _duration(context, item.kechikishDaqiqa)
                  : '—',
              color: item.kechikishDaqiqa > 0 ? c.warning : null,
            ),
          ]),

          Text(context.tr('rahbar_stats_money'), style: head),
          card([
            row(context.tr('rahbar_stats_base'), sum(asosiy.toDouble())),
            if (item.qoshimchaSumma > 0)
              row(
                context.tr('rahbar_stats_overtime_pay'),
                '+${sum(item.qoshimchaSumma)}',
                color: c.success,
              ),
            FutureBuilder<PayrollSettings>(
              future: settings,
              builder: (context, snap) {
                final s = snap.data;
                final rate = item.jarimaSummaShaxsiy ?? s?.jarimaSumma ?? 0;
                String? basis;
                if (s != null && item.jarima > 0 && rate > 0) {
                  basis = s.jarimaRejimi == 'har_daqiqa'
                      ? context.tr('rahbar_stats_fine_basis_min', {
                          'n': '${item.kechikishDaqiqa}',
                          'amount': _fmt(rate),
                        })
                      : context.tr('rahbar_stats_fine_basis_late', {
                          'n': '${item.kechikishSoni}',
                          'amount': _fmt(rate),
                        });
                }
                final off = !item.jarimaYoqilgan || s?.jarimaYoqilgan == false;
                return Column(
                  children: [
                    row(
                      context.tr('rahbar_stats_fine'),
                      off
                          ? context.tr('rahbar_payroll_fine_off')
                          : item.jarima > 0
                          ? '−${sum(item.jarima)}'
                          : '—',
                      color: item.jarima > 0 ? c.error : null,
                    ),
                    if (basis != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$basis${item.jarimaSummaShaxsiy != null ? ' · ${context.tr('rahbar_stats_fine_own')}' : ''}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const Divider(height: 18),
            row(
              context.tr('rahbar_stats_payable'),
              sum(item.maosh),
              bold: true,
              color: c.primary,
            ),
          ]),

          if (item.qoshimchaSoat > 0) ...[
            _OvertimeDaysList(
              future: sl<RahbarRemoteDataSource>().getOvertimeDays(
                xodimId: item.id,
                davr: davr,
                sana: sana,
              ),
            ),
            const SizedBox(height: 14),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.tune_rounded),
              label: Text(context.tr('rahbar_stats_edit')),
              onPressed: () {
                Navigator.of(context).pop();
                onEdit();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Xodimning to'lov turi, stavkasi va jarima kaliti. "Barcha xodimlarga"
/// belgilansa — hammaga bir xil qo'llanadi.
class _StaffPayRuleSheet extends StatefulWidget {
  final RahbarPayrollItemEntity item;
  final String davr;
  final String sana;
  final VoidCallback onSaved;

  const _StaffPayRuleSheet({
    required this.item,
    required this.davr,
    required this.sana,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context,
    RahbarPayrollItemEntity item, {
    required String davr,
    required String sana,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StaffPayRuleSheet(
        item: item,
        davr: davr,
        sana: sana,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<_StaffPayRuleSheet> createState() => _StaffPayRuleSheetState();
}

class _StaffPayRuleSheetState extends State<_StaffPayRuleSheet> {
  static const _types = ['soatbay', 'kunbay', 'oylik'];

  late String _type = _types.contains(widget.item.tolovTuri)
      ? widget.item.tolovTuri
      : 'oylik';
  late final _rate = TextEditingController(
    text: formatMoneyInput(widget.item.stavka),
  );
  late bool _fine = widget.item.jarimaYoqilgan;
  late final _ownFine = TextEditingController(
    text: formatMoneyInput(widget.item.jarimaSummaShaxsiy),
  );
  late bool _overtimePaid = widget.item.qoshimchaTolanadi;
  late final _overtimeRate = TextEditingController(
    text: formatMoneyInput(widget.item.qoshimchaStavka),
  );
  late final Future<List<OvertimeDay>> _overtimeDays =
      widget.item.qoshimchaSoat > 0
      ? sl<RahbarRemoteDataSource>()
            .getOvertimeDays(
              xodimId: widget.item.id,
              davr: widget.davr,
              sana: widget.sana,
            )
            .catchError((_) => const <OvertimeDay>[])
      : Future.value(const <OvertimeDay>[]);
  bool _all = false;
  bool _saving = false;

  /// Xodimda hali qoida yo'q — rahbar u qachondan hisoblanishini tanlaydi.
  bool get _isFirstRule => widget.item.stavka <= 0;

  /// `bugun` | `oy_boshi`.
  String _firstStart = 'bugun';

  @override
  void dispose() {
    _rate.dispose();
    _ownFine.dispose();
    _overtimeRate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final from = await sl<RahbarRemoteDataSource>().saveStaffPayRule(
        xodimIds: [widget.item.id],
        hammasi: _all,
        tolovTuri: _type,
        stavka: parseMoneyInput(_rate.text) ?? 0,
        jarimaYoqilgan: _fine,
        jarimaSummaShaxsiy: _fine ? parseMoneyInput(_ownFine.text) ?? 0 : null,
        qoshimchaTolanadi: _overtimePaid,
        qoshimchaStavka: _overtimePaid
            ? parseMoneyInput(_overtimeRate.text) ?? 0
            : null,
        birinchiQoidaBoshlanishi: _isFirstRule || _all ? _firstStart : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_ruleSavedMessage(context, from))),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.tr('rahbar_payroll_save_failed', {
              'error': DioRetryHelper.formatErrorMessage(e),
            }),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('rahbar_payroll_edit_title'),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            Text(
              widget.item.name,
              style: GoogleFonts.outfit(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  for (final t in _types)
                    ButtonSegment(
                      value: t,
                      label: Text(context.tr('rahbar_payroll_type_$t')),
                    ),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rate,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsDotFormatter()],
              decoration: InputDecoration(
                labelText: context.tr('rahbar_payroll_rate_label_$_type'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _fine,
              onChanged: (v) => setState(() => _fine = v),
              title: Text(context.tr('rahbar_payroll_fine_switch')),
              subtitle: Text(context.tr('rahbar_payroll_fine_switch_desc')),
            ),
            if (_fine)
              TextField(
                controller: _ownFine,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsDotFormatter()],
                decoration: InputDecoration(
                  labelText: context.tr('rahbar_payroll_own_fine'),
                  helperText: context.tr('rahbar_payroll_own_fine_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _overtimePaid,
              onChanged: (v) => setState(() => _overtimePaid = v),
              title: Text(context.tr('rahbar_payroll_overtime_switch')),
              subtitle: Text(context.tr('rahbar_payroll_overtime_switch_desc')),
            ),
            if (_overtimePaid)
              TextField(
                controller: _overtimeRate,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsDotFormatter()],
                decoration: InputDecoration(
                  labelText: context.tr('rahbar_payroll_overtime_rate'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            _OvertimeDaysList(future: _overtimeDays),
            if (_isFirstRule || _all) ...[
              const SizedBox(height: 12),
              Text(
                context.tr(
                  _all
                      ? 'rahbar_payroll_start_label_new'
                      : 'rahbar_payroll_start_label',
                ),
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'bugun',
                      label: Text(context.tr('rahbar_payroll_start_today')),
                    ),
                    ButtonSegment(
                      value: 'oy_boshi',
                      label: Text(context.tr('rahbar_payroll_start_month')),
                    ),
                  ],
                  selected: {_firstStart},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) =>
                      setState(() => _firstStart = v.first),
                ),
              ),
            ],
            if (widget.item.stavka > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  context.tr('rahbar_payroll_rule_from_next_month'),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _all,
              onChanged: (v) => setState(() => _all = v ?? false),
              title: Text(context.tr('rahbar_payroll_apply_all')),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('rahbar_payroll_save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tanlangan davrda xodim qaysi kunlari qancha qo'shimcha ishlagani.
class _OvertimeDaysList extends StatelessWidget {
  final Future<List<OvertimeDay>> future;

  const _OvertimeDaysList({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OvertimeDay>>(
      future: future,
      builder: (context, snap) {
        final days = snap.data ?? const <OvertimeDay>[];
        if (days.isEmpty) return const SizedBox.shrink();
        final style = GoogleFonts.outfit(
          fontSize: 13,
          color: context.colors.textPrimary,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('rahbar_payroll_overtime_days'),
                style: style.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            d.sana,
                            if (d.from != null) '${d.from} – ${d.to ?? '…'}',
                          ].join('  '),
                          style: style,
                        ),
                      ),
                      Text(
                        context.tr('rahbar_payroll_hours_short', {
                          'hours': d.soat.toStringAsFixed(1),
                        }),
                        style: style.copyWith(color: context.colors.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Tashkilot bo'yicha kechikish jarimasi: rejim va summa (imtiyozli vaqt
/// yo'q — 1 daqiqa kechikish ham hisoblanadi).
class _FineSettingsSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const _FineSettingsSheet({required this.onSaved});

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          SingleChildScrollView(child: _FineSettingsSheet(onSaved: onSaved)),
    );
  }

  @override
  State<_FineSettingsSheet> createState() => _FineSettingsSheetState();
}

class _FineSettingsSheetState extends State<_FineSettingsSheet> {
  final _amount = TextEditingController();
  String _mode = 'har_kechikish';
  bool _enabled = true;
  List<ArizaTurPay> _arizaTurlari = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final s = await sl<RahbarRemoteDataSource>().getPayrollSettings();
      _mode = s.jarimaRejimi;
      _enabled = s.jarimaYoqilgan;
      _arizaTurlari = s.arizaTurlari;
      _amount.text = formatMoneyInput(s.jarimaSumma);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final from = await sl<RahbarRemoteDataSource>().savePayrollSettings(
        PayrollSettings(
          jarimaRejimi: _mode,
          jarimaSumma: parseMoneyInput(_amount.text) ?? 0,
          jarimaYoqilgan: _enabled,
          arizaTurlari: _arizaTurlari,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_savedMessage(context, from))),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.tr('rahbar_payroll_save_failed', {
              'error': DioRetryHelper.formatErrorMessage(e),
            }),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, [String? helper]) => InputDecoration(
      labelText: label,
      helperText: helper,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _loading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('rahbar_payroll_settings_title'),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('rahbar_payroll_fine_global_switch')),
                  subtitle: Text(
                    context.tr(
                      _enabled
                          ? 'rahbar_payroll_fine_global_on'
                          : 'rahbar_payroll_fine_global_off',
                    ),
                  ),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                if (_enabled) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'har_kechikish',
                          label: Text(
                            context.tr('rahbar_payroll_fine_mode_per_late'),
                          ),
                        ),
                        ButtonSegment(
                          value: 'har_daqiqa',
                          label: Text(
                            context.tr('rahbar_payroll_fine_mode_per_minute'),
                          ),
                        ),
                      ],
                      selected: {_mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) =>
                          setState(() => _mode = v.first),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsDotFormatter()],
                    decoration: deco(context.tr('rahbar_payroll_fine_amount')),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${context.tr('rahbar_payroll_no_grace')}\n'
                    '${context.tr('rahbar_payroll_fine_scope')}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                if (_arizaTurlari.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.tr('rahbar_payroll_ariza_title'),
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  for (var i = 0; i < _arizaTurlari.length; i++)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_arizaTurlari[i].nomi),
                      subtitle: Text(
                        context.tr(
                          _arizaTurlari[i].haqTolanadi
                              ? 'rahbar_payroll_ariza_paid'
                              : 'rahbar_payroll_ariza_unpaid',
                        ),
                      ),
                      value: _arizaTurlari[i].haqTolanadi,
                      onChanged: (v) => setState(() {
                        _arizaTurlari = [
                          for (var j = 0; j < _arizaTurlari.length; j++)
                            j == i
                                ? _arizaTurlari[j].copyWith(haqTolanadi: v)
                                : _arizaTurlari[j],
                        ];
                      }),
                    ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('rahbar_payroll_save')),
                  ),
                ),
              ],
            ),
    );
  }
}

String? _dmy(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

/// "Saqlandi" yoki "Saqlandi. 01.11.2026 dan amal qiladi".
String _savedMessage(BuildContext context, String? from) {
  final d = _dmy(from);
  if (d == null) return context.tr('rahbar_payroll_saved');
  return context.tr('rahbar_payroll_saved_from', {'date': d});
}

/// Xodim qoidasi: jarima va stavka har xil sanada kuchga kirishi mumkin.
String _ruleSavedMessage(
  BuildContext context,
  ({String? amal, String? jarima}) from,
) {
  final rate = _dmy(from.amal);
  final fine = _dmy(from.jarima);
  if (rate != null && fine != null && rate != fine) {
    return context.tr('rahbar_payroll_saved_split', {
      'fine': fine,
      'rate': rate,
    });
  }
  return _savedMessage(context, from.amal ?? from.jarima);
}
