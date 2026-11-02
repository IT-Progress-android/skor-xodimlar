import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/rahbar_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_ui.dart';

/// Xodim(lar)ni qidirib tanlash oynasi. [multi] = false bo'lsa bitta
/// xodim tanlanadi va oyna darhol yopiladi.
Future<List<PickableStaff>?> showStaffPicker(
  BuildContext context, {
  required StaffPickerCubit cubit,
  bool multi = true,
  Set<int> initial = const {},
  Set<int> exclude = const {},
  String? title,
}) {
  cubit.load();
  return showModalBottomSheet<List<PickableStaff>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _StaffPickerSheet(
        multi: multi,
        initial: initial,
        exclude: exclude,
        title: title,
      ),
    ),
  );
}

class _StaffPickerSheet extends StatefulWidget {
  final bool multi;
  final Set<int> initial;
  final Set<int> exclude;
  final String? title;

  const _StaffPickerSheet({
    required this.multi,
    required this.initial,
    required this.exclude,
    this.title,
  });

  @override
  State<_StaffPickerSheet> createState() => _StaffPickerSheetState();
}

class _StaffPickerSheetState extends State<_StaffPickerSheet> {
  late final Set<int> _selected = {...widget.initial};
  String _q = '';

  /// Tanlangan filial; `null` — barcha filiallar.
  String? _filial;

  List<PickableStaff> _filter(List<PickableStaff> all) {
    final q = _q.trim().toLowerCase();
    return all
        .where((s) => !widget.exclude.contains(s.id))
        .where((s) => _filial == null || s.filial?.trim() == _filial)
        .where(
          (s) =>
              q.isEmpty ||
              s.name.toLowerCase().contains(q) ||
              (s.subtitle ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: BlocBuilder<StaffPickerCubit, StaffPickerState>(
        builder: (context, state) {
          final list = _filter(state.staff);
          final filials = distinctFilials(state.staff.map((s) => s.filial));
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title ?? context.tr('task_pick_staff'),
                        style: TaskUi.titleStyle(context, size: 17),
                      ),
                    ),
                    if (widget.multi && list.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() {
                          final ids = list.map((e) => e.id);
                          if (ids.every(_selected.contains)) {
                            _selected.removeAll(ids);
                          } else {
                            _selected.addAll(ids);
                          }
                        }),
                        child: Text(context.tr('task_select_all')),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: context.tr('task_search_staff'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TaskFilialTabs(
                  selected: _filial,
                  onSelected: (f) => setState(() => _filial = f),
                  extraFilials: filials,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _list(context, state, list)),
              if (widget.multi)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _selected.isEmpty
                            ? null
                            : () => Navigator.pop(
                                context,
                                state.staff
                                    .where((s) => _selected.contains(s.id))
                                    .toList(),
                              ),
                        child: Text(
                          context.tr('task_pick_confirm', {
                            'n': '${_selected.length}',
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _list(
    BuildContext context,
    StaffPickerState state,
    List<PickableStaff> list,
  ) {
    if (state.status == LoadStatus.loading ||
        state.status == LoadStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == LoadStatus.error) {
      return RefreshIndicator(
        onRefresh: () => context.read<StaffPickerCubit>().load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 40),
            TaskEmptyView(
              icon: Icons.cloud_off_rounded,
              title: context.tr('task_err_load'),
              subtitle: state.error,
            ),
          ],
        ),
      );
    }
    if (list.isEmpty) {
      return TaskEmptyView(
        icon: Icons.person_search_rounded,
        title: context.tr('task_no_staff_found'),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final s = list[i];
        final selected = _selected.contains(s.id);
        void toggle() {
          if (!widget.multi) {
            Navigator.pop(context, [s]);
            return;
          }
          setState(
            () => selected ? _selected.remove(s.id) : _selected.add(s.id),
          );
        }

        return ListTile(
          onTap: toggle,
          leading: StaffAvatar(name: s.name, photo: s.photo),
          title: Text(
            s.name,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          subtitle: s.subtitle == null
              ? null
              : Text(s.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: widget.multi
              ? Checkbox(value: selected, onChanged: (_) => toggle())
              : const Icon(Icons.chevron_right_rounded),
        );
      },
    );
  }
}

class StaffAvatar extends StatelessWidget {
  final String name;
  final String? photo;
  final double radius;

  const StaffAvatar({
    super.key,
    required this.name,
    this.photo,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: context.colors.primarySoft,
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
          color: context.colors.primary,
        ),
      ),
    );
    if (photo == null) return fallback;
    return CachedNetworkImage(
      imageUrl: photo!,
      imageBuilder: (_, img) =>
          CircleAvatar(radius: radius, backgroundImage: img),
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}
