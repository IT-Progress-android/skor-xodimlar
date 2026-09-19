import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';

class RahbarPayrollPage extends StatefulWidget {
  const RahbarPayrollPage({super.key});

  @override
  State<RahbarPayrollPage> createState() => _RahbarPayrollPageState();
}

class _RahbarPayrollPageState extends State<RahbarPayrollPage> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<RahbarBloc>();
    if (bloc.state is! RahbarPayrollLoaded && bloc.state is! RahbarLoading) {
      bloc.add(const LoadRahbarPayroll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0', 'uz_UZ');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('rahbar_payroll_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D6E6E),
            fontSize: 20,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<RahbarBloc>().add(const LoadRahbarPayroll()),
        color: const Color(0xFF0D6E6E),
        child: BlocBuilder<RahbarBloc, RahbarState>(
          buildWhen: (prev, curr) =>
              curr is RahbarLoading ||
              curr is RahbarPayrollLoaded ||
              curr is RahbarError,
          builder: (context, state) {
            if (state is RahbarLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D6E6E)),
              );
            } else if (state is RahbarPayrollLoaded) {
              if (state.list.isEmpty) {
                return RahbarEmptyStateWidget(
                  icon: Icons.account_balance_wallet_rounded,
                  title: context.tr('rahbar_payroll_empty_title'),
                  subtitle: context.tr('rahbar_payroll_empty_desc'),
                  onRefresh: () =>
                      context.read<RahbarBloc>().add(const LoadRahbarPayroll()),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.list.length,
                itemBuilder: (context, index) {
                  final item = state.list[index];
                  final formattedMaosh = currencyFormatter.format(item.maosh);

                  return AnimatedRotatingBorderContainer(
                    margin: const EdgeInsets.only(bottom: 12),
                    borderRadius: 16,
                    borderWidth: 2.0,
                    gradientColors: const [
                      Color(0xFF0D6E6E),
                      Color(0xFF139797),
                      Color(0xFF26BBAA),
                      Color(0xFF0D6E6E),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                context.tr('rahbar_payroll_sum', {
                                  'amount': formattedMaosh,
                                }),
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: const Color(0xFF0D6E6E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.bolim} · ${item.lavozim}',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('rahbar_payroll_days_present', {
                                  'days': '${item.kelganKun}',
                                }),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                context.tr('rahbar_payroll_hours_worked', {
                                  'hours': item.jamiIshlanganSoat
                                      .toStringAsFixed(1),
                                }),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            } else if (state is RahbarError) {
              return RahbarEmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: context.tr('error_occurred_title'),
                subtitle: state.message,
                onRefresh: () =>
                    context.read<RahbarBloc>().add(const LoadRahbarPayroll()),
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D6E6E)),
            );
          },
        ),
      ),
    );
  }
}
