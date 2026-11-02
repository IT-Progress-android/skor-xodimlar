import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_cubit.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/services/language_sync_service.dart';
import 'package:skore_hodimlar/features/auth/domain/entities/staff_entity.dart';
import 'package:skore_hodimlar/features/auth/presentation/bloc/auth_bloc.dart';

class SelectOrganizationPage extends StatefulWidget {
  final List<StaffEntity> staffList;
  const SelectOrganizationPage({super.key, required this.staffList});

  @override
  State<SelectOrganizationPage> createState() => _SelectOrganizationPageState();
}

class _SelectOrganizationPageState extends State<SelectOrganizationPage> {
  StaffEntity? _selectedStaff;

  @override
  void initState() {
    super.initState();
    if (widget.staffList.isNotEmpty) {
      _selectedStaff = widget.staffList.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surfaceVariant,
      appBar: AppBar(
        title: Text(
          context.tr('select_org_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: context.colors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colors.surface,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            FcmService.syncUserRole();
            FcmService.registerTokenOnBackend(
              phone: state.phone,
              staffId: state.staff.id,
            );
            LanguageSyncService.reconcileWithBackend(
              context.read<LanguageCubit>(),
            );
            context.go('/');
          }
        },
        builder: (context, state) {
          if (state is! AuthMultiple) {
            return Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            );
          }

          final list = widget.staffList;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final staff = list[index];
                    final isSelected = _selectedStaff?.id == staff.id;
                    final displayName =
                        (staff.tashkilot != null && staff.tashkilot!.isNotEmpty)
                        ? staff.tashkilot!
                        : staff.name;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? context.colors.primary
                              : context.colors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isSelected ? 0.06 : 0.03,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            setState(() {
                              _selectedStaff = staff;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF0D6E6E,
                                    ).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.business_rounded,
                                    color: context.colors.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: context.colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (staff.lavozim != null &&
                                          staff.lavozim!.isNotEmpty)
                                        Text(
                                          staff.lavozim!,
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFD97706),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      if (staff.name != displayName &&
                                          staff.name.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2.0,
                                          ),
                                          child: Text(
                                            staff.name,
                                            style: GoogleFonts.outfit(
                                              color:
                                                  context.colors.textSecondary,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? context.colors.primary
                                          : context.colors.textHint,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: context.colors.primary,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _selectedStaff == null
                        ? null
                        : () {
                            context.read<AuthBloc>().add(
                              StaffSelected(_selectedStaff!),
                            );
                          },
                    child: Text(
                      context.tr('login_continue'),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
}
