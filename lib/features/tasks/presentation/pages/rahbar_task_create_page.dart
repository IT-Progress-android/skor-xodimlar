import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/rahbar_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_ui.dart';
import 'package:skore_hodimlar/features/tasks/presentation/widgets/staff_picker_sheet.dart';

/// Yangi topshiriq: sarlavha, tavsif, muddat va xodimlar.
/// Muvaffaqiyatda yangi topshiriq `id` si bilan yopiladi.
class RahbarTaskCreatePage extends StatefulWidget {
  const RahbarTaskCreatePage({super.key});

  @override
  State<RahbarTaskCreatePage> createState() => _RahbarTaskCreatePageState();
}

class _RahbarTaskCreatePageState extends State<RahbarTaskCreatePage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _picker = sl<StaffPickerCubit>();
  DateTime? _deadline;
  List<PickableStaff> _staff = [];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _picker.close();
    super.dispose();
  }

  Future<void> _pickStaff() async {
    final res = await showStaffPicker(
      context,
      cubit: _picker,
      initial: _staff.map((e) => e.id).toSet(),
    );
    if (res != null && mounted) setState(() => _staff = res);
  }

  Future<void> _pickDeadline() async {
    final d = await TaskUi.pickDeadline(context, initial: _deadline);
    if (d != null && mounted) setState(() => _deadline = d);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_deadline == null) {
      TaskUi.snack(context, context.tr('task_err_no_deadline'), error: true);
      return;
    }
    if (_deadline!.isBefore(DateTime.now().add(TaskUi.minLead))) {
      TaskUi.snack(context, context.tr('task_err_min_deadline'), error: true);
      return;
    }
    if (_staff.isEmpty) {
      TaskUi.snack(context, context.tr('task_err_no_staff'), error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await sl<TaskRemoteDataSource>().createTask(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        staffIds: _staff.map((e) => e.id).toList(),
        deadline: _deadline!,
      );
      if (!mounted) return;
      TaskUi.snack(context, context.tr('task_msg_created'));
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      TaskUi.snack(context, taskErrorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(context.tr('task_new')),
        backgroundColor: c.surface,
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec(context, 'task_field_title'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.tr('task_err_no_title')
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _desc,
              maxLength: 2000,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec(context, 'task_field_description'),
            ),
            const SizedBox(height: 8),
            _tile(
              context,
              icon: Icons.event_rounded,
              title: context.tr('task_deadline'),
              value: _deadline == null
                  ? context.tr('task_pick_deadline')
                  : TaskUi.date(context, _deadline),
              hint: context.tr('task_min_deadline_hint'),
              onTap: _pickDeadline,
            ),
            const SizedBox(height: 12),
            _tile(
              context,
              icon: Icons.group_add_rounded,
              title: context.tr('task_field_staff'),
              value: _staff.isEmpty
                  ? context.tr('task_pick_staff')
                  : context.tr('task_n_staff', {'n': '${_staff.length}'}),
              onTap: _pickStaff,
            ),
            if (_staff.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _staff
                    .map(
                      (s) => InputChip(
                        avatar: StaffAvatar(
                          name: s.name,
                          photo: s.photo,
                          radius: 12,
                        ),
                        label: Text(s.name),
                        onDeleted: () =>
                            setState(() => _staff = [..._staff]..remove(s)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(context.tr('task_send')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(BuildContext context, String key) => InputDecoration(
    labelText: context.tr(key),
    filled: true,
    fillColor: context.colors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    String? hint,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _saving ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: c.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TaskUi.bodyStyle(context, size: 12.5)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(hint, style: TaskUi.bodyStyle(context, size: 11.5)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
