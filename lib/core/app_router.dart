// lib/core/router/app_router.dart
//
// Routes added:
//   /onboarding        → OnboardingPage   (first launch only)
//   /lecturer-home     → LecturerHomePage
//   /admin-home        → AdminHomePage
//
// /home now points to StudentHomePage instead of the old HomePage.
// All other existing routes are preserved exactly as-is.

import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Existing imports (unchanged paths) ───────────────────────────────────────
import 'package:edutrack_mut/features/attendance/presentation/screens/pages/help.dart';
import 'package:edutrack_mut/features/attendance/presentation/screens/pages/notifications.dart';
import 'package:edutrack_mut/features/attendance/presentation/screens/pages/security.dart';
import '../../features/attendance/presentation/screens/auth/login.dart';
import '../../features/attendance/presentation/screens/auth/signup.dart';
import '../features/attendance/presentation/screens/pages/history.dart';
import '../features/attendance/presentation/screens/pages/timetable.dart';
import '../features/attendance/presentation/screens/pages/settings.dart';
import '../features/attendance/presentation/screens/pages/qr_scan.dart';

// ── New imports ───────────────────────────────────────────────────────────────
import '../../features/attendance/presentation/screens/pages/onboarding_page.dart';
import '../features/attendance/presentation/screens/pages/home/student_home_page.dart';
import '../features/attendance/presentation/screens/pages/home/lecturer_home_page.dart';
import '../features/attendance/presentation/screens/pages/home/admin_home_page.dart';
import '../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────

const _authRoutes = {'/login', '/signup', '/onboarding'};

String _dashboardForRole(String role) => switch (role) {
  'lecturer' => '/lecturer-home',
  'admin'    => '/admin-home',
  _          => '/home',            // student (default)
};

// ─────────────────────────────────────────────────────────────────────────────

final GoRouter appRouter = GoRouter(
  initialLocation: '/onboarding',

  // ── Auth / onboarding guard ───────────────────────────────────────────────
  redirect: (context, state) async {
    final prefs          = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final isLoggedIn     = await ApiService().isLoggedIn;
    final user           = await ApiService().getUser();
    final role           = user?['role'] as String? ?? 'student';
    final path           = state.matchedLocation;

    // 1. First launch — force onboarding before anything else
    if (!onboardingDone && path != '/onboarding') return '/onboarding';

    // 2. Already logged in — skip auth/onboarding screens
    if (isLoggedIn && _authRoutes.contains(path)) {
      return _dashboardForRole(role);
    }

    // 3. Not logged in — block protected routes
    if (!isLoggedIn && !_authRoutes.contains(path)) return '/login';

    return null; // no redirect needed
  },

  routes: [

    // ── Onboarding ────────────────────────────────────────────────────────────
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const OnboardingPage(),
    ),

    // ── Auth ──────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (_, __) => const SignupPage(),
    ),

    // ── Role dashboards ───────────────────────────────────────────────────────
    GoRoute(
      path: '/home',                              // student dashboard
      builder: (_, __) => const StudentHomePage(),
    ),
    GoRoute(
      path: '/lecturer-home',
      builder: (_, __) => const LecturerHomePage(),
    ),
    GoRoute(
      path: '/admin-home',
      builder: (_, __) => const AdminHomePage(),
    ),

    // ── Existing pages (unchanged) ────────────────────────────────────────────
    GoRoute(
      path: '/history',
      builder: (_, __) => const HistoryPage(),
    ),
    GoRoute(
      path: '/timetable',
      builder: (_, __) => const TimeTablePage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsPage(),
    ),
    GoRoute(
      path: '/qr_scan',
      builder: (_, __) => const QRScanPage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/security',
      builder: (_, __) => const SecurityPage(),
    ),
    GoRoute(
      path: '/help_support',
      builder: (_, __) => const HelpAndSupportPage(),
    ),
  ],
);