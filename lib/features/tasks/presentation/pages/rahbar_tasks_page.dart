import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/rahbar_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/pages/rahbar_task_create_page.dart';
import 'package:skore_hodimlar/features/tasks/presentation/pages/rahbar_task_detail_page.dart';
import 'package:skore_hodimlar/features/tasks/presentation/pages/task_stats_page.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_ui.dart';

/// Rahbarning topshiriqlar ro'yxati: filtr, qidiruv, yangi topshiriq.
class RahbarTasksPage extends StatelessWidget {
  const RahbarTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RahbarTasksCubit>()..load(),
      child: const _RahbarTasksView(),
    );
  }
}

class _RahbarTasksView extends StatefulWidget {
  const _RahbarTasksView();

  @override
  State<_RahbarTasksView> createState() => _RahbarTasksViewState();
}

class _RahbarTasksViewState extends State<_RahbarTasksView> {
  final _scroll = ScrollController();
  Timer? _debounce;

  static const _filters = <String?>[
    null,
    'jarayonda',
    'bajarilmadi',
    'ozvaqtida',
    'kechikib',
    'otkazildi',
    'bekor',
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        context.read<RahbarTasksCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const RahbarTaskCreatePage()),
    );
    if (!mounted || id == null) return;
    unawaited(context.read<RahbarTasksCubit>().load());
    if (id > 0) await _openDetail(id);
  }

  Future<void> _openDetail(int id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RahbarTaskDetailPage(taskId: id)),
    );
    if (mounted && changed == true) {
      unawaited(context.read<RahbarTasksCubit>().load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(context.tr('task_title')),
        backgroundColor: context.colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: context.tr('task_stats_title'),
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TaskStatsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_task_rounded),
        label: Text(context.tr('task_new')),
      ),
      body: BlocBuilder<RahbarTasksCubit, RahbarTasksState>(
        builder: (context, state) {
          final cubit = context.read<RahbarTasksCubit>();
          return Column(
            children: [
              TaskFilialTabs(
                selected: state.filial,
                onSelected: cubit.setFilial,
                extraFilials: state.filials,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 400),
                      () => cubit.setQuery(v.trim()),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: context.tr('task_search'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = _filters[i];
                    return ChoiceChip(
                      label: Text(
                        context.tr(
                          f == null ? 'task_filter_all' : 'task_holat_$f',
                        ),
                      ),
                      selected: state.holat == f,
                      onSelected: (_) => cubit.setFilter(f),
                    );
                  },
                ),
              ),
              // Filial tanlangan, lekin ba'zi topshiriqlar filiali hali
              // yuklanmoqda — ro'yxat to'ldirilayotganini ko'rsatamiz.
              if (state.filial != null && state.filialsPending)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: cubit.load,
                  child: _body(context, state),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, RahbarTasksState state) {
    if (state.status == LoadStatus.loading ||
        state.status == LoadStatus.initial) {
      return const TaskListSkeleton(itemHeight: 118);
    }
    if (state.status == LoadStatus.error && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          TaskEmptyView(
            icon: Icons.cloud_off_rounded,
            title: context.tr('task_err_load'),
            subtitle: state.error,
          ),
        ],
      );
    }
    final visible = state.visibleItems;
    if (state.items.isNotEmpty && visible.isEmpty && state.filialsPending) {
      return const TaskListSkeleton(itemHeight: 118);
    }
    if (state.items.isNotEmpty && visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          TaskEmptyView(
            icon: Icons.store_mall_directory_rounded,
            title: context.tr('task_filial_empty'),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          TaskEmptyView(
            icon: Icons.assignment_outlined,
            title: context.tr('task_empty_rahbar'),
            subtitle: context.tr('task_pull_to_refresh'),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: visible.length + (state.loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i >= visible.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final t = visible[i];
        return _RahbarTaskCard(
          task: t,
          filials: state.taskFilials[t.id],
          onTap: () => _openDetail(t.id),
        );
      },
    );
  }
}

class _RahbarTaskCard extends StatelessWidget {
  final RahbarTaskSummary task;

  /// Ijrochilar biriktirilgan filiallar (hali yuklanmagan bo'lsa `null`).
  final Set<String>? filials;
  final VoidCallback onTap;
  const _RahbarTaskCard({
    required this.task,
    required this.onTap,
    this.filials,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasOverdue = task.bajarilmadi > 0 && !task.bekorQilingan;
    final active = task.jami - task.otkazildi;
    final progress = active <= 0 ? 0.0 : task.bajarildi / active;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasOverdue ? c.error.withValues(alpha: 0.5) : c.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TaskUi.titleStyle(context, size: 15.5),
                    ),
                  ),
                  if (task.bekorQilingan)
                    const TaskHolatChip(holat: TaskHolat.bekor, dense: true),
                ],
              ),
              if (filials != null && filials!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.store_mall_directory_rounded,
                      size: 14,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        distinctFilials(filials!).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TaskUi.bodyStyle(context, size: 12.5),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.event_rounded, size: 15, color: c.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    TaskUi.date(context, task.deadline),
                    style: TaskUi.bodyStyle(context, size: 13),
                  ),
                  const Spacer(),
                  Text(
                    context.tr('task_done_of', {
                      'done': '${task.bajarildi}',
                      'total': '$active',
                    }),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: c.surfaceStrong,
                  color: hasOverdue ? c.error : c.success,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _count(context, TaskHolat.jarayonda, task.jarayonda),
                  _count(context, TaskHolat.bajarilmadi, task.bajarilmadi),
                  _count(context, TaskHolat.ozvaqtida, task.ozvaqtida),
                  _count(context, TaskHolat.kechikib, task.kechikib),
                  _count(context, TaskHolat.otkazildi, task.otkazildi),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _count(BuildContext context, TaskHolat h, int n) {
    if (n == 0) return const SizedBox.shrink();
    final color = TaskUi.color(context, h);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(TaskUi.icon(h), size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          '${context.tr(h.translationKey)}: $n',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
