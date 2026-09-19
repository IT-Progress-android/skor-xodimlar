import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';
import 'package:skore_hodimlar/features/applications/presentation/bloc/ariza_bloc.dart';

class NewApplicationPage extends StatefulWidget {
  const NewApplicationPage({super.key});
  @override
  State<NewApplicationPage> createState() => _NewApplicationPageState();
}

class _NewApplicationPageState extends State<NewApplicationPage> {
  String? phone;
  int? staffId;
  ArizaTuriEntity? selectedTuri;
  DateTime? fromDate;
  DateTime? toDate;
  final _izohController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPhoneAndTypes();
  }

  Future<void> _loadPhoneAndTypes() async {
    final prefs = sl<SharedPreferences>();
    phone = prefs.getString('phone') ?? prefs.getString('staff_phone');
    staffId = prefs.getInt('staff_id');
    if (phone != null && mounted) {
      context.read<ArizaBloc>().add(LoadArizaTurlari(phone!, staffId: staffId));
    }
  }

  void _submit() {
    if (selectedTuri == null || fromDate == null || phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('ariza_form_missing_fields')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final effectiveToDate = toDate ?? fromDate!;

    if (effectiveToDate.isBefore(fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('ariza_form_invalid_date_range')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final formattedFrom = DateFormat('yyyy-MM-dd').format(fromDate!);
    final formattedTo = DateFormat('yyyy-MM-dd').format(effectiveToDate);

    context.read<ArizaBloc>().add(
      SubmitAriza(
        phone: phone!,
        staffId: staffId,
        fromDate: formattedFrom,
        toDate: formattedTo,
        turi: selectedTuri!.kalit,
        izoh: _izohController.text.trim(),
      ),
    );
  }

  int get _kunlar {
    if (fromDate == null) return 0;
    final effectiveToDate = toDate ?? fromDate!;
    return effectiveToDate.difference(fromDate!).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final earliestDate = DateTime.now().subtract(const Duration(days: 30));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr('ariza_new'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocConsumer<ArizaBloc, ArizaState>(
        listener: (context, state) {
          if (state is ArizaSubmitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('ariza_form_submitted_success')),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop(true);
          } else if (state is ArizaError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          List<ArizaTuriEntity> turlari = [];
          if (state is ArizaTurlariLoaded) {
            turlari = state.list;
            if (turlari.isNotEmpty && selectedTuri == null) {
              selectedTuri = turlari.first;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Box per PDF rules
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('ariza_form_date_range_info'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Ariza Turi Dropdown
                Text(
                  context.tr('ariza_form_type_label'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ArizaTuriEntity>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  initialValue: selectedTuri,
                  hint: Text(context.tr('ariza_form_type_hint')),
                  items: turlari
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e.nomi,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => selectedTuri = val),
                ),
                const SizedBox(height: 20),

                // Date Selectors
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('ariza_form_start_date_label'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: fromDate ?? DateTime.now(),
                                firstDate: earliestDate,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                builder: (context, child) => Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.primary,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (date != null) {
                                setState(() {
                                  fromDate = date;
                                  if (toDate != null &&
                                      toDate!.isBefore(date)) {
                                    toDate = date;
                                  }
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fromDate != null
                                          ? DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(fromDate!)
                                          : context.tr('ariza_form_pick_date'),
                                      style: TextStyle(
                                        fontWeight: fromDate != null
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: fromDate != null
                                            ? AppColors.textPrimary
                                            : AppColors.textHint,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('ariza_form_end_date_label'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate:
                                    toDate ?? (fromDate ?? DateTime.now()),
                                firstDate: fromDate ?? earliestDate,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                builder: (context, child) => Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.primary,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (date != null) setState(() => toDate = date);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.event_rounded,
                                    size: 18,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      toDate != null
                                          ? DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(toDate!)
                                          : (fromDate != null
                                                ? DateFormat(
                                                    'yyyy-MM-dd',
                                                  ).format(fromDate!)
                                                : context.tr(
                                                    'ariza_form_optional',
                                                  )),
                                      style: TextStyle(
                                        fontWeight: toDate != null
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: toDate != null
                                            ? AppColors.textPrimary
                                            : AppColors.textHint,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_kunlar > 0) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        context.tr('ariza_form_duration', {'days': '$_kunlar'}),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Izoh textarea
                Text(
                  context.tr('ariza_form_reason_label'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _izohController,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText: context.tr('ariza_form_reason_hint'),
                    hintStyle: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (state is ArizaLoading) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    child: (state is ArizaLoading)
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            context.tr('ariza_form_submit'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
