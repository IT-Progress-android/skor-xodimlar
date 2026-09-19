import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/custom_animated_bottom_nav_bar.dart';
import 'package:skore_hodimlar/features/applications/presentation/pages/applications_page.dart';
import 'package:skore_hodimlar/features/applications/presentation/pages/new_application_page.dart';
import 'package:skore_hodimlar/features/attendance/presentation/pages/attendance_history_page.dart';
import 'package:skore_hodimlar/features/attendance/presentation/pages/check_in_page.dart';
import 'package:skore_hodimlar/features/attendance/presentation/pages/home_page.dart';
import 'package:skore_hodimlar/features/auth/domain/entities/staff_entity.dart';
import 'package:skore_hodimlar/features/auth/presentation/pages/login_page.dart';
import 'package:skore_hodimlar/features/auth/presentation/pages/select_organization_page.dart';
import 'package:skore_hodimlar/features/auth/presentation/pages/splash_page.dart';
import 'package:skore_hodimlar/features/lookup/presentation/pages/add_staff_page.dart';
import 'package:skore_hodimlar/features/notifications/presentation/pages/notifications_page.dart';
import 'package:skore_hodimlar/features/profile/presentation/pages/profile_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_shell_page.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/select-org',
        builder: (context, state) {
          final staffList = state.extra as List<StaffEntity>? ?? [];
          return SelectOrganizationPage(staffList: staffList);
        },
      ),
      GoRoute(
        path: '/check-in',
        builder: (context, state) {
          final isCheckIn = state.extra as bool? ?? true;
          return CheckInPage(isCheckIn: isCheckIn);
        },
      ),
      GoRoute(
        path: '/add-staff',
        builder: (context, state) => const AddStaffPage(),
      ),
      GoRoute(
        path: '/rahbar',
        builder: (context, state) => const RahbarShellPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return ScaffoldWithNavBar(child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/history',
            builder: (context, state) => const AttendanceHistoryPage(),
          ),
          GoRoute(
            path: '/applications',
            builder: (context, state) => const ApplicationsPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const NewApplicationPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
}

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    int calculateSelectedIndex(BuildContext context) {
      final String location = GoRouterState.of(context).uri.path;
      if (location.startsWith('/history')) {
        return 1;
      }
      if (location.startsWith('/applications')) {
        return 2;
      }
      if (location.startsWith('/profile')) {
        return 3;
      }
      return 0;
    }

    void onItemTapped(int index, BuildContext context) {
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/history');
          break;
        case 2:
          context.go('/applications');
          break;
        case 3:
          context.go('/profile');
          break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: child,
          bottomNavigationBar: CustomAnimatedBottomNavBar(
            selectedIndex: calculateSelectedIndex(context),
            onItemTapped: (idx) => onItemTapped(idx, context),
            items: [
              CustomBottomNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: context.tr('nav_home'),
              ),
              CustomBottomNavItem(
                icon: Icons.history_outlined,
                selectedIcon: Icons.history_rounded,
                label: context.tr('nav_history'),
              ),
              CustomBottomNavItem(
                icon: Icons.assignment_outlined,
                selectedIcon: Icons.assignment_rounded,
                label: context.tr('nav_applications'),
              ),
              CustomBottomNavItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: context.tr('nav_profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}
