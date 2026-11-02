import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';
import 'package:skore_hodimlar/core/widgets/custom_animated_bottom_nav_bar.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_dashboard_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_payroll_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_realtime_map_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_reports_hub_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/rahbar_map_focus.dart';
import 'package:skore_hodimlar/features/tasks/presentation/pages/rahbar_tasks_page.dart';

class RahbarShellPage extends StatefulWidget {
  const RahbarShellPage({super.key});

  @override
  State<RahbarShellPage> createState() => _RahbarShellPageState();
}

class _RahbarShellPageState extends State<RahbarShellPage> {
  int _currentIndex = 0;

  /// [_pages] dagi xarita tabi.
  static const _mapTab = 2;

  void _onMapFocus() {
    if (rahbarMapFocusStaff.value != null && _currentIndex != _mapTab) {
      setState(() => _currentIndex = _mapTab);
    }
  }

  /// Ariza / kelmaganlar bildirishnomasi — ro'yxatni bosh sahifa ochadi.
  void _onOpenRequest() {
    if (rahbarOpenRequest.value != null && _currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  void dispose() {
    rahbarMapFocusStaff.removeListener(_onMapFocus);
    rahbarOpenRequest.removeListener(_onOpenRequest);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    rahbarMapFocusStaff.addListener(_onMapFocus);
    rahbarOpenRequest.addListener(_onOpenRequest);
    if (rahbarMapFocusStaff.value != null) _currentIndex = _mapTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkAndShowUpdate(context);
    });
  }

  final List<Widget> _pages = const [
    RahbarDashboardPage(),
    RahbarReportsHubPage(),
    RahbarRealtimeMapPage(),
    RahbarTasksPage(),
    RahbarPayrollPage(),
  ];

  void _onTabTapped(int idx) {
    if (_currentIndex != idx) {
      setState(() => _currentIndex = idx);
      _fetchDataForTab(idx);
    }
  }

  void _fetchDataForTab(int idx) {
    final bloc = context.read<RahbarBloc>();
    if (idx == 0) {
      bloc.add(const LoadRahbarDashboard());
    } else if (idx == 4) {
      bloc.add(const LoadRahbarPayroll());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: CustomAnimatedBottomNavBar(
        selectedIndex: _currentIndex,
        onItemTapped: _onTabTapped,
        items: [
          CustomBottomNavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: context.tr('rahbar_nav_home'),
          ),
          CustomBottomNavItem(
            icon: Icons.assessment_outlined,
            selectedIcon: Icons.assessment_rounded,
            label: context.tr('rahbar_nav_reports'),
          ),
          CustomBottomNavItem(
            icon: Icons.map_outlined,
            selectedIcon: Icons.map_rounded,
            label: context.tr('rahbar_nav_map'),
            isCenter: true,
          ),
          CustomBottomNavItem(
            icon: Icons.task_alt_outlined,
            selectedIcon: Icons.task_alt_rounded,
            label: context.tr('nav_tasks'),
          ),
          CustomBottomNavItem(
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: context.tr('rahbar_nav_payroll'),
          ),
        ],
      ),
    );
  }
}
