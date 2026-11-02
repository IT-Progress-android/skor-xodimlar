import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/attendance/presentation/widgets/check_in_button.dart';
import 'package:skore_hodimlar/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_refresh.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_ui.dart';

/// Xodim uchun topshiriq tafsiloti va "Bajardim" slayderi.
class StaffTaskDetailPage extends StatelessWidget {
  final int taskId;
  const StaffTaskDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          StaffTaskDetailCubit(sl<TaskRemoteDataSource>(), taskId)..load(),
      child: Builder(
        builder: (context) => TaskAutoRefresh(
          taskId: taskId,
          onRefresh: context.read<StaffTaskDetailCubit>().load,
          child: const _DetailView(),
        ),
      ),
    );
  }
}

class _DetailView extends StatefulWidget {
  const _DetailView();

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(context.tr('task_detail_title')),
        backgroundColor: context.colors.surface,
        elevation: 0,
      ),
      body: BlocConsumer<StaffTaskDetailCubit, StaffTaskDetailState>(
        listener: (context, state) {
          if (state.justCompleted) {
            _comment.clear();
            final late = state.task?.holat == TaskHolat.kechikib;
            TaskUi.snack(
              context,
              context.tr(late ? 'task_done_late_msg' : 'task_done_msg'),
            );
          } else if (state.error != null && state.task != null) {
            TaskUi.snack(context, state.error!, error: true);
          }
        },
        builder: (context, state) {
          final cubit = context.read<StaffTaskDetailCubit>();
          if (state.gone) {
            return TaskEmptyView(
              icon: Icons.block_rounded,
              title: context.tr('task_gone_title'),
              subtitle: context.tr('task_gone_desc'),
            );
          }
          final task = state.task;
          if (task == null) {
            if (state.status == LoadStatus.error) {
              return RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    TaskEmptyView(
                      icon: Icons.cloud_off_rounded,
                      title: context.tr('task_err_load'),
                      subtitle: state.error,
                    ),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _header(context, task),
                if (task.holat.isOpen && task.returnComment != null) ...[
                  const SizedBox(height: 12),
                  _returnedBanner(context, task),
                ],
                if (task.description != null) ...[
                  const SizedBox(height: 12),
                  _section(
                    context,
                    context.tr('task_description'),
                    Text(
                      task.description!,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        height: 1.45,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (task.holat.isOpen)
                  _doneForm(context, state)
                else if (task.holat.isDone)
                  _doneInfo(context, task),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, StaffTask task) {
    final c = context.colors;
    final overdue = task.holat == TaskHolat.bajarilmadi;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overdue ? c.errorSoft : c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: overdue ? c.error.withValues(alpha: 0.5) : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskHolatChip(holat: task.holat),
          const SizedBox(height: 10),
          Text(task.title, style: TaskUi.titleStyle(context, size: 19)),
          const SizedBox(height: 14),
          _infoRow(
            context,
            Icons.event_rounded,
            context.tr('task_deadline'),
            TaskUi.date(context, task.muddat),
            trailing: task.holat.isOpen
                ? TaskUi.remaining(context, task.muddat)
                : null,
            trailingColor: overdue ? c.error : c.primary,
          ),
          if (task.berdi != null)
            _infoRow(
              context,
              Icons.person_rounded,
              context.tr('task_given_by'),
              task.berdi!,
            ),
          if (task.berilganVaqt != null)
            _infoRow(
              context,
              Icons.schedule_send_rounded,
              context.tr('task_given_at'),
              TaskUi.date(context, task.berilganVaqt),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    String? trailing,
    Color? trailingColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: context.colors.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ', style: TaskUi.bodyStyle(context)),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: trailingColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _returnedBanner(BuildContext context, StaffTask task) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.warningSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.reply_rounded, color: c.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('task_returned_title'),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.returnComment!,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    height: 1.4,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TaskUi.titleStyle(context, size: 14.5)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _doneForm(BuildContext context, StaffTaskDetailState state) {
    final cubit = context.read<StaffTaskDetailCubit>();
    return _section(
      context,
      context.tr('task_mark_done_title'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _comment,
            maxLength: 500,
            minLines: 2,
            maxLines: 5,
            enabled: !state.submitting,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: context.tr('task_comment_hint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('task_done_irreversible'),
            style: TaskUi.bodyStyle(context, size: 12.5),
          ),
          const SizedBox(height: 12),
          if (state.submitting)
            const SizedBox(
              height: 62,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            CheckInButton(
              isCheckIn: true,
              label: context.tr('task_slide_done'),
              confirmedLabel: context.tr('task_confirmed_done'),
              thumbIcon: Icons.arrow_forward_rounded,
              onPressed: () {
                FocusScope.of(context).unfocus();
                cubit.markDone(_comment.text.trim());
              },
            ),
        ],
      ),
    );
  }

  Widget _doneInfo(BuildContext context, StaffTask task) {
    final late = task.holat == TaskHolat.kechikib;
    final color = TaskUi.color(context, task.holat);
    return _section(
      context,
      context.tr('task_done_info_title'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(TaskUi.icon(task.holat), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(late ? 'task_done_late_at' : 'task_done_at', {
                    'date': TaskUi.date(context, task.completedAt),
                  }),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (task.comment != null) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('task_your_comment'),
              style: TaskUi.bodyStyle(context, size: 12.5),
            ),
            const SizedBox(height: 2),
            Text(
              task.comment!,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
