import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_ui.dart';

/// Xodimning "Topshiriqlar" bo'limi: faol va bajarilgan topshiriqlar.
class StaffTasksPage extends StatelessWidget {
  const StaffTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<StaffTasksCubit>()..load(),
      child: const _StaffTasksView(),
    );
  }
}

class _StaffTasksView extends StatefulWidget {
  const _StaffTasksView();

  @override
  State<_StaffTasksView> createState() => _StaffTasksViewState();
}

class _StaffTasksViewState extends State<_StaffTasksView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        context.read<StaffTasksCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(StaffTask t) async {
    await context.push('/tasks/${t.id}');
    if (mounted) await context.read<StaffTasksCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(context.tr('task_title')),
        backgroundColor: context.colors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<StaffTasksCubit, StaffTasksState>(
        builder: (context, state) {
          final cubit = context.read<StaffTasksCubit>();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'faol',
                        label: Text(context.tr('task_tab_active')),
                        icon: const Icon(Icons.pending_actions_rounded),
                      ),
                      ButtonSegment(
                        value: 'bajarilgan',
                        label: Text(context.tr('task_tab_done')),
                        icon: const Icon(Icons.task_alt_rounded),
                      ),
                    ],
                    selected: {state.tab},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => cubit.load(tab: s.first),
                  ),
                ),
              ),
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

  Widget _body(BuildContext context, StaffTasksState state) {
    if (state.status == LoadStatus.loading ||
        state.status == LoadStatus.initial) {
      return const TaskListSkeleton();
    }
    if (state.status == LoadStatus.error && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          TaskEmptyView(
            icon: Icons.cloud_off_rounded,
            title: context.tr('task_err_load'),
            subtitle: state.error,
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          TaskEmptyView(
            icon: state.tab == 'faol'
                ? Icons.celebration_rounded
                : Icons.inbox_rounded,
            title: context.tr(
              state.tab == 'faol' ? 'task_empty_active' : 'task_empty_done',
            ),
            subtitle: context.tr('task_pull_to_refresh'),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: state.items.length + (state.loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i >= state.items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final t = state.items[i];
        return StaffTaskCard(task: t, onTap: () => _open(t));
      },
    );
  }
}

class StaffTaskCard extends StatelessWidget {
  final StaffTask task;
  final VoidCallback onTap;
  const StaffTaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final overdue = task.holat == TaskHolat.bajarilmadi;
    final returned = task.holat.isOpen && task.returnComment != null;
    final c = context.colors;
    return Material(
      color: overdue ? c.errorSoft : c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: overdue ? c.error.withValues(alpha: 0.5) : c.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TaskUi.titleStyle(context, size: 15.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TaskHolatChip(holat: task.holat, dense: true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event_rounded, size: 15, color: c.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    TaskUi.date(context, task.muddat),
                    style: TaskUi.bodyStyle(context, size: 13),
                  ),
                  if (task.holat.isOpen) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        TaskUi.remaining(context, task.muddat),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: overdue ? c.error : c.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (returned) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 15, color: c.warning),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        context.tr('task_returned_note', {
                          'comment': task.returnComment!,
                        }),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: c.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
}
