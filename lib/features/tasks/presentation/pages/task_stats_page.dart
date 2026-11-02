import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/task_stats_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/pages/staff_task_history_page.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_ui.dart';
import 'package:skore_hodimlar/features/tasks/presentation/widgets/staff_picker_sheet.dart';
import 'package:skore_hodimlar/features/tasks/presentation/widgets/task_stats_widgets.dart';

/// Rahbar: topshiriqlar statistikasi (kun / hafta / oy / yil).
class TaskStatsPage extends StatelessWidget {
  const TaskStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TaskStatsCubit>()..load(),
      child: const _StatsView(),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView();

  /// Server umumiy hisobda foizlarni bermasa ("—" chiqmasin), ularni
  /// xodimlar foizidan hisoblaymiz; sonlar serverdagicha qoladi.
  static TaskCounters _withPercents(TaskCounters j, List<TaskStaffStat> all) {
    if (j.bajarishFoizi != null) return j;
    final c = TaskCounters.combine(all.map((s) => s.counters));
    return TaskCounters(
      berilgan: j.berilgan,
      ozvaqtida: j.ozvaqtida,
      kechikib: j.kechikib,
      bajarilmadi: j.bajarilmadi,
      otkazilgan: j.otkazilgan,
      jarayonda: j.jarayonda,
      qaytarilgan: j.qaytarilgan,
      bajarishFoizi: c.bajarishFoizi,
      ozvaqtidaFoizi: c.ozvaqtidaFoizi,
      uddalamadiFoizi: c.uddalamadiFoizi,
    );
  }

  static const _filters = ['hammasi', 'uddalamaganlar', 'kechikkanlar'];
  static const _sorts = [
    'bajarish_foizi',
    'ozvaqtida_foizi',
    'uddalamadi_foizi',
    'berilgan',
    'ism',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(context.tr('task_stats_title')),
        backgroundColor: context.colors.surface,
        elevation: 0,
        actions: [
          BlocBuilder<TaskStatsCubit, TaskStatsState>(
            builder: (context, state) => PopupMenuButton<String>(
              tooltip: context.tr('task_sort'),
              icon: const Icon(Icons.sort_rounded),
              initialValue: state.saralash,
              onSelected: context.read<TaskStatsCubit>().setSort,
              itemBuilder: (_) => _sorts
                  .map(
                    (s) => PopupMenuItem(
                      value: s,
                      child: Text(context.tr('task_sort_$s')),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      body: BlocBuilder<TaskStatsCubit, TaskStatsState>(
        builder: (context, state) {
          final cubit = context.read<TaskStatsCubit>();
          final r = state.result;
          // Filial bo'yicha filtr ilovada: ro'yxat va umumiy karta shu
          // filial xodimlaridan qayta hisoblanadi.
          final filials = r == null
              ? const <String>[]
              : distinctFilials(r.xodimlar.map((s) => s.filial));
          final filial = filials.contains(state.filial) ? state.filial : null;
          final staff = r == null
              ? const <TaskStaffStat>[]
              : filial == null
              ? r.xodimlar
              : r.xodimlar.where((s) => s.filial?.trim() == filial).toList();
          final jami = r == null
              ? const TaskCounters()
              : filial == null
              ? _withPercents(r.jami, r.xodimlar)
              : TaskCounters.combine(staff.map((s) => s.counters));
          return Column(
            children: [
              TaskFilialTabs(
                selected: filial,
                onSelected: cubit.setFilial,
                extraFilials: filials,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: cubit.load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      TaskPeriodBar(
                        period: state.period,
                        sana: state.sana,
                        range: r?.davr,
                        onPeriod: cubit.setPeriod,
                        onShift: cubit.shift,
                      ),
                      const SizedBox(height: 8),
                      if (state.status == LoadStatus.loading && r == null)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (state.status == LoadStatus.error && r == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: TaskEmptyView(
                            icon: Icons.cloud_off_rounded,
                            title: context.tr('task_err_load'),
                            subtitle: state.error,
                          ),
                        )
                      else if (r != null &&
                          r.jami.berilgan == 0 &&
                          r.xodimlar.isEmpty) ...[
                        const SizedBox(height: 40),
                        TaskEmptyView(
                          icon: Icons.bar_chart_rounded,
                          title: context.tr('task_empty_rahbar'),
                          subtitle: context.tr('task_pull_to_refresh'),
                        ),
                      ] else if (r != null) ...[
                        if (state.status == LoadStatus.loading)
                          const LinearProgressIndicator(minHeight: 2),
                        TaskCountersCard(c: jami),
                        const SizedBox(height: 12),
                        TaskDynamicsChart(
                          points: state.dynamics,
                          period: state.period,
                        ),
                        // Dinamika serverdan barcha filiallar bo'yicha keladi.
                        if (filial != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              context.tr('task_dynamics_all_filials'),
                              style: TaskUi.bodyStyle(context, size: 12),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('task_stats_by_staff'),
                          style: TaskUi.titleStyle(context, size: 15),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _filters
                              .map(
                                (f) => ChoiceChip(
                                  label: Text(
                                    context.tr('task_stats_filter_$f'),
                                  ),
                                  selected: state.filtr == f,
                                  onSelected: (_) => cubit.setFilter(f),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        if (staff.isEmpty)
                          TaskEmptyView(
                            icon: Icons.groups_rounded,
                            title: context.tr(
                              'task_stats_empty_${state.period.name}',
                            ),
                          )
                        else
                          ...staff.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StaffStatTile(
                                s: s,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StaffTaskHistoryPage(
                                      staffId: s.staffId,
                                      name: s.ism,
                                      period: state.period,
                                      sana: state.sana,
                                      holat: state.filtr == 'uddalamaganlar'
                                          ? 'bajarilmadi'
                                          : state.filtr == 'kechikkanlar'
                                          ? 'kechikib'
                                          : 'hammasi',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StaffStatTile extends StatelessWidget {
  final TaskStaffStat s;
  final VoidCallback onTap;
  const _StaffStatTile({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final k = s.counters;
    final failed = k.bajarilmadi + k.otkazilgan;
    final pct = k.bajarishFoizi;
    final pctColor = pct == null
        ? c.textSecondary
        : pct >= 90
        ? c.success
        : pct >= 70
        ? c.warning
        : c.error;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              StaffAvatar(name: s.ism),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.ism, style: TaskUi.titleStyle(context, size: 14.5)),
                    if (s.filial != null)
                      Text(
                        s.filial!,
                        style: TaskUi.bodyStyle(context, size: 12),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('task_stat_line', {
                        'given': '${k.berilgan}',
                        'ontime': '${k.ozvaqtida}',
                        'late': '${k.kechikib}',
                      }),
                      style: TaskUi.bodyStyle(context, size: 12.5),
                    ),
                    if (failed > 0)
                      Text(
                        context.tr('task_stat_failed_line', {
                          'missed': '${k.bajarilmadi}',
                          'transferred': '${k.otkazilgan}',
                        }),
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.error,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    pct == null ? '—' : '${pct.round()}%',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: pctColor,
                    ),
                  ),
                  Text(
                    context.tr('task_stat_done_short'),
                    style: TaskUi.bodyStyle(context, size: 10.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
