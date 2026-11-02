import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/task_stats_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/pages/rahbar_task_detail_page.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_ui.dart';
import 'package:skore_hodimlar/features/tasks/presentation/widgets/task_stats_widgets.dart';

/// Rahbar: bitta xodimning ko'rsatkichlari va topshiriqlari
/// (bajarilmagan, o'tkazilgan, kechikkan va h.k. filtr bilan).
class StaffTaskHistoryPage extends StatelessWidget {
  final int staffId;
  final String name;
  final TaskPeriod period;
  final DateTime sana;
  final String holat;

  const StaffTaskHistoryPage({
    super.key,
    required this.staffId,
    required this.name,
    required this.period,
    required this.sana,
    this.holat = 'hammasi',
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StaffHistoryCubit(
        sl<TaskRemoteDataSource>(),
        staffId,
        period: period,
        sana: sana,
        holat: holat,
      )..load(),
      child: _HistoryView(name: name),
    );
  }
}

class _HistoryView extends StatefulWidget {
  final String name;
  const _HistoryView({required this.name});

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  final _scroll = ScrollController();

  static const _filters = [
    'hammasi',
    'bajarilmadi',
    'otkazildi',
    'kechikib',
    'qaytarilgan',
    'ozvaqtida',
    'jarayonda',
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        context.read<StaffHistoryCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(widget.name),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: BlocBuilder<StaffHistoryCubit, StaffHistoryState>(
        builder: (context, state) {
          final cubit = context.read<StaffHistoryCubit>();
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                TaskPeriodBar(
                  period: state.period,
                  sana: state.sana,
                  range: null,
                  onPeriod: cubit.setPeriod,
                  onShift: cubit.shift,
                ),
                const SizedBox(height: 8),
                if (state.status == LoadStatus.loading)
                  const LinearProgressIndicator(minHeight: 2),
                if (state.status == LoadStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: TaskEmptyView(
                      icon: Icons.cloud_off_rounded,
                      title: context.tr('task_err_load'),
                      subtitle: state.error,
                    ),
                  )
                else ...[
                  TaskCountersCard(c: state.counters),
                  const SizedBox(height: 12),
                  TaskDynamicsChart(
                    points: state.dynamics,
                    period: state.period,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final f = _filters[i];
                        return ChoiceChip(
                          label: Text(
                            context.tr(
                              f == 'hammasi'
                                  ? 'task_filter_all'
                                  : f == 'qaytarilgan'
                                  ? 'task_filter_returned'
                                  : 'task_holat_$f',
                            ),
                          ),
                          selected: state.holat == f,
                          onSelected: (_) => cubit.setHolat(f),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (state.items.isEmpty && state.status == LoadStatus.loaded)
                    TaskEmptyView(
                      icon: Icons.inbox_rounded,
                      title: context.tr('task_history_empty'),
                    ),
                  ...state.items.map(
                    (it) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HistoryTile(item: it),
                    ),
                  ),
                  if (state.loadingMore)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final StaffTaskHistoryItem item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = <String>[
      '${context.tr('task_deadline')}: ${TaskUi.date(context, item.muddat)}',
      if (item.holat.isDone)
        context.tr(
          item.holat == TaskHolat.kechikib
              ? 'task_done_late_at'
              : 'task_done_at',
          {'date': TaskUi.date(context, item.completedAt)},
        ),
      if (item.otkazildiKimga != null)
        context.tr('task_transferred_to', {'name': item.otkazildiKimga!.ism}),
      if (item.returnedCount > 0)
        context.tr('task_returned_count', {'n': '${item.returnedCount}'}),
    ];
    final extra = item.transferComment ?? item.returnComment ?? item.comment;
    return Material(
      color: item.holat == TaskHolat.bajarilmadi ? c.errorSoft : c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RahbarTaskDetailPage(taskId: item.taskId),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.holat == TaskHolat.bajarilmadi
                  ? c.error.withValues(alpha: 0.5)
                  : c.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TaskUi.titleStyle(context, size: 14.5),
                    ),
                  ),
                  TaskHolatChip(holat: item.holat, dense: true),
                ],
              ),
              const SizedBox(height: 4),
              ...lines.map(
                (l) => Text(l, style: TaskUi.bodyStyle(context, size: 12.5)),
              ),
              if (extra != null) ...[
                const SizedBox(height: 4),
                Text(
                  '“$extra”',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
