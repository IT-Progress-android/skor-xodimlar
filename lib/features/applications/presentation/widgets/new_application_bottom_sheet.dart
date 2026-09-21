import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/get_ariza_types_usecase.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/submit_ariza_usecase.dart';

class NewApplicationBottomSheet extends StatefulWidget {
  const NewApplicationBottomSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const NewApplicationBottomSheet(),
      ),
    );
  }

  @override
  State<NewApplicationBottomSheet> createState() =>
      _NewApplicationBottomSheetState();
}

class _NewApplicationBottomSheetState extends State<NewApplicationBottomSheet> {
  String? phone;
  int? staffId;
  ArizaTuriEntity? selectedTuri;
  List<ArizaTuriEntity> _turlari = [];
  bool _isLoadingTypes = true;
  DateTime? fromDate;
  DateTime? toDate;
  final _izohController = TextEditingController();
  bool _isSubmitting = false;
  String? _submitErrorMessage;

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
      final usecase = sl<GetArizaTypesUseCase>();
      final res = await usecase(phone!, staffId: staffId);
      if (!mounted) return;
      res.fold(
        (failure) {
          setState(() {
            _isLoadingTypes = false;
          });
        },
        (list) {
          setState(() {
            _turlari = list;
            if (list.isNotEmpty) {
              selectedTuri = list.first;
            }
            _isLoadingTypes = false;
          });
        },
      );
    } else {
      if (mounted) {
        setState(() {
          _isLoadingTypes = false;
        });
      }
    }
  }

  Future<void> _submit() async {
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

    setState(() {
      _isSubmitting = true;
      _submitErrorMessage = null;
    });

    final useCase = sl<SubmitArizaUseCase>();
    final result = await useCase(
      SubmitArizaParams(
        phone: phone!,
        staffId: staffId,
        fromDate: formattedFrom,
        toDate: formattedTo,
        turi: selectedTuri!.kalit,
        izoh: _izohController.text.trim(),
      ),
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    result.fold(
      (failure) {
        setState(() {
          _submitErrorMessage = failure.message;
        });
      },
      (ariza) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ariza_sheet_submitted_success')),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      },
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('ariza_sheet_title'),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D6E6E),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Error Message Box if submit failed
            if (_submitErrorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _submitErrorMessage!,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Info Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6E6E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF0D6E6E).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF0D6E6E),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('ariza_sheet_date_range_info'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Ariza Turi Field
            Text(
              context.tr('ariza_form_type_label'),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Custom Ultra-Clean Ariza Turi Selection Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF0D6E6E).withValues(alpha: 0.3),
                ),
              ),
              child: _isLoadingTypes
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Color(0xFF0D6E6E),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<ArizaTuriEntity>(
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        value: selectedTuri,
                        hint: Text(
                          context.tr('ariza_form_type_hint'),
                          style: GoogleFonts.outfit(color: AppColors.textHint),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF0D6E6E),
                        ),
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        items: _turlari.map((item) {
                          return DropdownMenuItem<ArizaTuriEntity>(
                            value: item,
                              child: Text(
                                BackendTextMapper.translateArizaTuriNomi(
                                  item.nomi,
                                ),
                                style: GoogleFonts.outfit(
                                color: const Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedTuri = val;
                              _submitErrorMessage = null;
                            });
                          }
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 18),

            // Date Picker Cards (Side-by-Side)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('ariza_form_start_date_label'),
                        style: GoogleFonts.outfit(
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
                                  primary: Color(0xFF0D6E6E),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (date != null) {
                            setState(() {
                              fromDate = date;
                              _submitErrorMessage = null;
                              if (toDate != null && toDate!.isBefore(date)) {
                                toDate = date;
                              }
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: fromDate != null
                                  ? const Color(0xFF0D6E6E)
                                  : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: Color(0xFF0D6E6E),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fromDate != null
                                      ? DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(fromDate!)
                                      : context.tr('ariza_form_pick_date'),
                                  style: GoogleFonts.outfit(
                                    color: fromDate != null
                                        ? AppColors.textPrimary
                                        : AppColors.textHint,
                                    fontWeight: fromDate != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
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
                        style: GoogleFonts.outfit(
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
                            initialDate: toDate ?? fromDate ?? DateTime.now(),
                            firstDate: fromDate ?? earliestDate,
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            builder: (context, child) => Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF0D6E6E),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (date != null) {
                            setState(() {
                              toDate = date;
                              _submitErrorMessage = null;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: toDate != null
                                  ? const Color(0xFF0D6E6E)
                                  : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                size: 16,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  toDate != null
                                      ? DateFormat('yyyy-MM-dd').format(toDate!)
                                      : (fromDate != null
                                            ? DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(fromDate!)
                                            : context.tr(
                                                'ariza_form_optional',
                                              )),
                                  style: GoogleFonts.outfit(
                                    color: (toDate != null || fromDate != null)
                                        ? AppColors.textPrimary
                                        : AppColors.textHint,
                                    fontWeight:
                                        (toDate != null || fromDate != null)
                                        ? FontWeight.bold
                                        : FontWeight.normal,
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
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D6E6E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.tr('ariza_form_duration', {'days': '$_kunlar'}),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0D6E6E),
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),

            // Izoh Input
            Text(
              context.tr('ariza_sheet_reason_label'),
              style: GoogleFonts.outfit(
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
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: context.tr('ariza_sheet_reason_hint'),
                hintStyle: GoogleFonts.outfit(
                  color: AppColors.textHint,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF0D6E6E),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6E6E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        context.tr('ariza_sheet_submit'),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
