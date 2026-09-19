import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/no_internet_view.dart';
import 'package:skore_hodimlar/core/widgets/notification_bell_button.dart';
import 'package:skore_hodimlar/core/widgets/skor_logo_widget.dart';
import 'package:skore_hodimlar/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:skore_hodimlar/features/attendance/presentation/widgets/attendance_card.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _periods = ['day', 'week', 'month', 'year'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData(0);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData(_tabController.index);
      }
    });
  }

  void _loadData(int index) {
    final prefs = sl<SharedPreferences>();
    final phone = prefs.getString('phone') ?? prefs.getString('staff_phone');
    if (phone != null && phone.isNotEmpty) {
      context.read<AttendanceBloc>().add(
        LoadPeriodAttendance(phone, _periods[index]),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: Tooltip(
              message: context.tr('refresh'),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _loadData(_tabController.index),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: SkorLogoWidget(
                    size: 34,
                    showText: false,
                    animateParticles: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          context.tr('attendance_history_title'),
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D6E6E),
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: const [NotificationBellButton()],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D6E6E),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF0D6E6E),
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: context.tr('today')),
            Tab(text: context.tr('attendance_tab_week')),
            Tab(text: context.tr('attendance_tab_month')),
            Tab(text: context.tr('attendance_tab_year')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(4, (index) => _buildList()),
      ),
    );
  }

  Widget _buildList() {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        if (state is AttendanceLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0D6E6E)),
          );
        } else if (state is PeriodAttendanceLoaded) {
          if (state.reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('attendance_history_empty_title'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('attendance_history_empty_desc'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 24,
              left: 16,
              right: 16,
            ),
            itemCount: state.reports.length,
            itemBuilder: (context, index) {
              return AttendanceCard(report: state.reports[index]);
            },
          );
        } else if (state is AttendanceError) {
          final isNetwork =
              state.message.toLowerCase().contains('internet') ||
              state.message.toLowerCase().contains('tarmoq');
          return NoInternetView(
            title: isNetwork
                ? context.tr('no_internet_title')
                : context.tr('error_occurred_title'),
            message: state.message,
            onRetry: () => _loadData(_tabController.index),
          );
        }
        return const SizedBox();
      },
    );
  }
}
