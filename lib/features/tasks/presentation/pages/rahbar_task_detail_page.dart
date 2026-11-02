import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/rahbar_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_refresh.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_ui.dart';
import 'package:skore_hodimlar/features/tasks/presentation/widgets/staff_picker_sheet.dart';

/// Rahbar: topshiriq tafsiloti, xodimlar holati va barcha amallar.
/// Yopilganda, biror narsa o'zgargan bo'lsa `true` qaytaradi.
class RahbarTaskDetailPage extends StatelessWidget {
  final int taskId;
  const RahbarTaskDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              RahbarTaskDetailCubit(sl<TaskRemoteDataSource>(), taskId)..load(),
        ),
        BlocProvider(create: (_) => sl<StaffPickerCubit>()),
      ],
      child: Builder(
        builder: (context) => TaskAutoRefresh(
          taskId: taskId,
          onRefresh: context.read<RahbarTaskDetailCubit>().load,
          child: const _DetailView(),
        ),
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RahbarTaskDetailCubit>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, cubit.changed);
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: Text(context.tr('task_detail_title')),
          backgroundColor: context.colors.surface,
          elevation: 0,
          actions: [
            BlocBuilder<RahbarTaskDetailCubit, RahbarTaskDetailState>(
              builder: (context, state) {
                final t = state.task;
                if (t == null || t.bekorQilingan) return const SizedBox();
                return PopupMenuButton<String>(
                  enabled: !state.busy,
                  onSelected: (v) => _onMenu(context, v, t),
                  itemBuilder: (_) => [
                    _menuItem(context, 'edit', Icons.edit_rounded, 'task_edit'),
                    _menuItem(
                      context,
                      'helpers',
                      Icons.group_add_rounded,
                      'task_add_helpers',
                    ),
                    _menuItem(
                      context,
                      'cancel',
                      Icons.block_rounded,
                      'task_cancel',
                      danger: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<RahbarTaskDetailCubit, RahbarTaskDetailState>(
          listener: (context, state) {
            if (state.message != null) TaskUi.snack(context, state.message!);
            if (state.error != null && state.task != null) {
              TaskUi.snack(context, state.error!, error: true);
            }
          },
          builder: (context, state) {
            final t = state.task;
            if (t == null) {
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
            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: cubit.load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _header(context, t),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('task_assignees', {
                          'n': '${t.xodimlar.length}',
                        }),
                        style: TaskUi.titleStyle(context, size: 15),
                      ),
                      const SizedBox(height: 8),
                      ..._sorted(t.xodimlar).map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AssigneeCard(
                            a: a,
                            onTap: t.bekorQilingan
                                ? null
                                : () => _assigneeActions(context, t, a),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.busy)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static List<TaskAssignee> _sorted(List<TaskAssignee> list) {
    const order = {
      TaskHolat.bajarilmadi: 0,
      TaskHolat.jarayonda: 1,
      TaskHolat.kechikib: 2,
      TaskHolat.ozvaqtida: 3,
      TaskHolat.otkazildi: 4,
      TaskHolat.bekor: 5,
    };
    return [...list]
      ..sort((a, b) => order[a.holat]!.compareTo(order[b.holat]!));
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context,
    String value,
    IconData icon,
    String key, {
    bool danger = false,
  }) {
    final color = danger ? context.colors.error : context.colors.textPrimary;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Text(context.tr(key), style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, RahbarTaskDetail t) {
    final c = context.colors;
    final done = t.xodimlar.where((a) => a.holat.isDone).length;
    final active = t.xodimlar
        .where(
          (a) => a.holat != TaskHolat.otkazildi && a.holat != TaskHolat.bekor,
        )
        .length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.bekorQilingan) ...[
            const TaskHolatChip(holat: TaskHolat.bekor),
            const SizedBox(height: 8),
          ],
          Text(t.title, style: TaskUi.titleStyle(context, size: 19)),
          if (t.description != null) ...[
            const SizedBox(height: 8),
            Text(
              t.description!,
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                height: 1.45,
                color: c.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.event_rounded, size: 17, color: c.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${context.tr('task_deadline')}: ',
                style: TaskUi.bodyStyle(context),
              ),
              Text(
                TaskUi.date(context, t.deadline),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('task_done_of', {'done': '$done', 'total': '$active'}),
            style: TaskUi.bodyStyle(context, size: 12.5),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: active == 0 ? 0 : done / active,
              minHeight: 6,
              backgroundColor: c.surfaceStrong,
              color: c.success,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Amallar

  Future<void> _onMenu(
    BuildContext context,
    String v,
    RahbarTaskDetail t,
  ) async {
    final cubit = context.read<RahbarTaskDetailCubit>();
    switch (v) {
      case 'edit':
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: context.colors.surface,
          shape: _sheetShape,
          builder: (_) => _EditSheet(task: t, cubit: cubit),
        );
        break;
      case 'helpers':
        final picked = await showStaffPicker(
          context,
          cubit: context.read<StaffPickerCubit>(),
          title: context.tr('task_add_helpers'),
          exclude: t.xodimlar
              .where((a) => a.holat.isOpen || a.holat.isDone)
              .map((a) => a.staffId)
              .toSet(),
        );
        if (picked == null || picked.isEmpty || !context.mounted) return;
        await cubit.addHelpers(picked.map((e) => e.id).toList(), null);
        break;
      case 'cancel':
        final ok = await _confirm(
          context,
          title: context.tr('task_cancel'),
          body: context.tr('task_cancel_confirm'),
          danger: true,
        );
        if (ok) await cubit.cancel();
        break;
    }
  }

  Future<void> _assigneeActions(
    BuildContext context,
    RahbarTaskDetail t,
    TaskAssignee a,
  ) async {
    final cubit = context.read<RahbarTaskDetailCubit>();
    final picker = context.read<StaffPickerCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: _sheetShape,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: StaffAvatar(name: a.ism),
              title: Text(a.ism, style: TaskUi.titleStyle(ctx, size: 15)),
              trailing: TaskHolatChip(holat: a.holat, dense: true),
            ),
            const Divider(height: 1),
            if (a.holat.isDone)
              _actionTile(ctx, 'return', Icons.reply_rounded, 'task_return'),
            if (a.holat.isOpen) ...[
              _actionTile(
                ctx,
                'deadline',
                Icons.more_time_rounded,
                'task_new_deadline',
              ),
              _actionTile(
                ctx,
                'transfer',
                Icons.swap_horiz_rounded,
                'task_transfer',
              ),
              _actionTile(
                ctx,
                'remove',
                Icons.person_remove_rounded,
                'task_remove_staff',
                danger: true,
              ),
            ],
            if (!a.holat.isOpen && !a.holat.isDone)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.tr('task_no_actions'),
                  style: TaskUi.bodyStyle(ctx),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'return':
        final res = await _showReasonSheet(
          context,
          title: context.tr('task_return'),
          hint: context.tr('task_return_hint'),
          required: true,
          deadlineLabel: context.tr('task_new_deadline_optional'),
        );
        if (res != null) await cubit.returnTask(a.staffId, res.text, res.date);
        break;
      case 'deadline':
        if (!context.mounted) return;
        final d = await TaskUi.pickDeadline(context, initial: a.muddat);
        if (d != null) await cubit.setDeadline(a.staffId, d);
        break;
      case 'transfer':
        final to = await showStaffPicker(
          context,
          cubit: picker,
          multi: false,
          title: context.tr('task_transfer_to'),
          exclude: t.xodimlar
              .where((x) => x.holat.isOpen || x.holat.isDone)
              .map((x) => x.staffId)
              .toSet(),
        );
        if (to == null || to.isEmpty || !context.mounted) return;
        final res = await _showReasonSheet(
          context,
          title: context.tr('task_transfer_confirm', {
            'from': a.ism,
            'to': to.first.name,
          }),
          hint: context.tr('task_transfer_hint'),
          required: false,
          deadlineLabel: context.tr('task_new_deadline_optional'),
        );
        if (res != null) {
          await cubit.transfer(a.staffId, to.first.id, res.text, res.date);
        }
        break;
      case 'remove':
        final ok = await _confirm(
          context,
          title: context.tr('task_remove_staff'),
          body: context.tr('task_remove_confirm', {'name': a.ism}),
          danger: true,
        );
        if (ok) await cubit.remove(a.staffId);
        break;
    }
  }

  static const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  );

  Widget _actionTile(
    BuildContext ctx,
    String value,
    IconData icon,
    String key, {
    bool danger = false,
  }) {
    final color = danger ? ctx.colors.error : ctx.colors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: danger ? color : ctx.colors.primary),
      title: Text(ctx.tr(key), style: TextStyle(color: color)),
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    bool danger = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('no')),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: ctx.colors.error)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('confirm')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<_Reason?> _showReasonSheet(
    BuildContext context, {
    required String title,
    required String hint,
    required bool required,
    required String deadlineLabel,
  }) {
    return showModalBottomSheet<_Reason>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: _sheetShape,
      builder: (_) => _ReasonSheet(
        title: title,
        hint: hint,
        required: required,
        deadlineLabel: deadlineLabel,
      ),
    );
  }
}

class _AssigneeCard extends StatelessWidget {
  final TaskAssignee a;
  final VoidCallback? onTap;
  const _AssigneeCard({required this.a, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overdue = a.holat == TaskHolat.bajarilmadi;
    final lines = <String>[
      if (a.holat.isOpen)
        '${context.tr('task_deadline')}: ${TaskUi.date(context, a.muddat)} · '
            '${TaskUi.remaining(context, a.muddat)}',
      if (a.holat.isDone)
        context.tr(
          a.holat == TaskHolat.kechikib ? 'task_done_late_at' : 'task_done_at',
          {'date': TaskUi.date(context, a.completedAt)},
        ),
      a.seenAt == null
          ? context.tr('task_not_seen')
          : context.tr('task_seen_at', {
              'date': TaskUi.date(context, a.seenAt),
            }),
      if (a.assignedVia == 'yordamchi') context.tr('task_via_helper'),
      if (a.assignedVia == 'otkazma') context.tr('task_via_transfer'),
      if (a.holat == TaskHolat.otkazildi && a.otkazildiKimga != null)
        context.tr('task_transferred_to', {'name': a.otkazildiKimga!.ism}),
      if (a.returnedCount > 0)
        context.tr('task_returned_count', {'n': '${a.returnedCount}'}),
    ];
    return Material(
      color: overdue ? c.errorSoft : c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: overdue ? c.error.withValues(alpha: 0.5) : c.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StaffAvatar(name: a.ism),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.ism,
                            style: TaskUi.titleStyle(context, size: 14.5),
                          ),
                        ),
                        TaskHolatChip(holat: a.holat, dense: true),
                      ],
                    ),
                    if (a.filial != null)
                      Text(
                        a.filial!,
                        style: TaskUi.bodyStyle(context, size: 12),
                      ),
                    const SizedBox(height: 4),
                    ...lines.map(
                      (l) =>
                          Text(l, style: TaskUi.bodyStyle(context, size: 12.5)),
                    ),
                    if (a.comment != null) ...[
                      const SizedBox(height: 6),
                      _quote(
                        context,
                        Icons.chat_bubble_outline_rounded,
                        a.comment!,
                      ),
                    ],
                    if (a.holat.isOpen && a.returnComment != null) ...[
                      const SizedBox(height: 6),
                      _quote(context, Icons.reply_rounded, a.returnComment!),
                    ],
                    if (a.holat == TaskHolat.otkazildi &&
                        a.transferComment != null) ...[
                      const SizedBox(height: 6),
                      _quote(
                        context,
                        Icons.swap_horiz_rounded,
                        a.transferComment!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quote(BuildContext context, IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: context.colors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Reason {
  final String text;
  final DateTime? date;
  const _Reason(this.text, this.date);
}

/// Izoh (majburiy yoki ixtiyoriy) va ixtiyoriy yangi muddat.
class _ReasonSheet extends StatefulWidget {
  final String title;
  final String hint;
  final bool required;
  final String deadlineLabel;

  const _ReasonSheet({
    required this.title,
    required this.hint,
    required this.required,
    required this.deadlineLabel,
  });

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final _text = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = _text.text.trim().length;
    final valid = !widget.required || len >= 5;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: TaskUi.titleStyle(context, size: 17)),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: 500,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.required
                  ? context.tr('task_min_5_chars')
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await TaskUi.pickDeadline(context, initial: _date);
              if (d != null && mounted) setState(() => _date = d);
            },
            icon: const Icon(Icons.event_rounded),
            label: Text(
              _date == null
                  ? widget.deadlineLabel
                  : TaskUi.date(context, _date),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: valid
                  ? () => Navigator.pop(
                      context,
                      _Reason(_text.text.trim(), _date),
                    )
                  : null,
              child: Text(context.tr('confirm')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sarlavha, tavsif va umumiy muddatni tahrirlash.
class _EditSheet extends StatefulWidget {
  final RahbarTaskDetail task;
  final RahbarTaskDetailCubit cubit;
  const _EditSheet({required this.task, required this.cubit});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _desc = TextEditingController(text: widget.task.description ?? '');
  DateTime? _deadline;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      TaskUi.snack(context, context.tr('task_err_no_title'), error: true);
      return;
    }
    final desc = _desc.text.trim();
    final titleChanged = title != widget.task.title;
    final descChanged = desc != (widget.task.description ?? '');
    if (!titleChanged && !descChanged && _deadline == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.cubit.edit(
      title: titleChanged ? title : null,
      description: descChanged ? desc : null,
      deadline: _deadline,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('task_edit'),
              style: TaskUi.titleStyle(context, size: 17),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: context.tr('task_field_title'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLength: 2000,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: context.tr('task_field_description'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await TaskUi.pickDeadline(
                  context,
                  initial: _deadline ?? widget.task.deadline,
                );
                if (d != null && mounted) setState(() => _deadline = d);
              },
              icon: const Icon(Icons.event_rounded),
              label: Text(
                '${context.tr('task_deadline')}: '
                '${TaskUi.date(context, _deadline ?? widget.task.deadline)}',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('task_edit_notify_hint'),
              style: TaskUi.bodyStyle(context, size: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
