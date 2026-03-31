// lib/core/router/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Existing imports ──────────────────────────────────────────────────────────
import 'package:edutrack_mut/features/attendance/presentation/screens/pages/help.dart';
import 'package:edutrack_mut/features/attendance/presentation/screens/pages/notifications.dart';
import 'package:edutrack_mut/features/attendance/presentation/screens/pages/security.dart';
import '../features/attendance/presentation/screens/auth/login.dart';
import '../features/attendance/presentation/screens/auth/signup.dart';
import '../features/attendance/presentation/screens/pages/history.dart';
import '../features/attendance/presentation/screens/pages/settings.dart';
import '../features/attendance/presentation/screens/pages/qr_scan.dart';
import '../features/attendance/presentation/screens/pages/analytics.dart';

// ── Home pages ────────────────────────────────────────────────────────────────
import '../features/attendance/presentation/screens/pages/onboarding_page.dart';
import '../features/attendance/presentation/screens/pages/home/student_home_page.dart';
import '../features/attendance/presentation/screens/pages/home/lecturer_home_page.dart';
import '../features/attendance/presentation/screens/pages/home/admin_home_page.dart';

// ── Timetable pages (role-specific) ──────────────────────────────────────────
import '../features/attendance/presentation/screens/student/student_timetable_page.dart';
import '../features/attendance/presentation/screens/lecturer/lecturer_timetable_page.dart';

// ── ApiService ────────────────────────────────────────────────────────────────
import './services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────

const _authRoutes = {'/login', '/signup', '/onboarding'};

String _dashboardForRole(String role) => switch (role) {
  'lecturer' => '/lecturer-home',
  'admin'    => '/admin-home',
  _          => '/home',
};

// Maps /timetable to the correct role-specific page.
// Admin has no timetable — redirect them to their dashboard.
String _timetableForRole(String role) => switch (role) {
  'lecturer' => '/lecturer-timetable',
  'admin'    => '/admin-home',
  _          => '/student-timetable',
};

// ─────────────────────────────────────────────────────────────────────────────

final GoRouter appRouter = GoRouter(
  initialLocation: '/onboarding',

  redirect: (context, state) async {
    final prefs          = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final isLoggedIn     = await ApiService().isLoggedIn;
    final user           = await ApiService().getUser();
    final role           = user?['role'] as String? ?? 'student';
    final path           = state.matchedLocation;

    // 1. First launch — force onboarding
    if (!onboardingDone && path != '/onboarding') return '/onboarding';

    // 2. Already logged in — skip auth/onboarding screens
    if (isLoggedIn && _authRoutes.contains(path)) {
      return _dashboardForRole(role);
    }

    // 3. Not logged in — block protected routes
    if (!isLoggedIn && !_authRoutes.contains(path)) return '/login';

    // 4. /timetable is a shared alias — redirect to role-specific page
    if (path == '/timetable') return _timetableForRole(role);

    return null;
  },

  routes: [
    // ── Auth ────────────────────────────────────────────────────────────────
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
    GoRoute(path: '/login',      builder: (_, __) => const LoginPage()),
    GoRoute(path: '/signup',     builder: (_, __) => const SignupPage()),

    // ── Dashboards ──────────────────────────────────────────────────────────
    GoRoute(path: '/home',          builder: (_, __) => const StudentHomePage()),
    GoRoute(path: '/lecturer-home', builder: (_, __) => const LecturerHomePage()),
    GoRoute(path: '/admin-home',    builder: (_, __) => const AdminHomePage()),

    // ── Shared alias — redirect handled in redirect() above ─────────────────
    // Kept so existing context.go('/timetable') calls still work everywhere.
    GoRoute(
      path: '/timetable',
      redirect: (context, state) async {
        final user = await ApiService().getUser();
        final role = user?['role'] as String? ?? 'student';
        return _timetableForRole(role);
      },
    ),

    // ── Role-specific timetable pages ────────────────────────────────────────
    GoRoute(
      path: '/student-timetable',
      builder: (_, __) => const StudentTimetablePage(),
    ),
    GoRoute(
      path: '/lecturer-timetable',
      builder: (_, __) => const LecturerTimetablePage(),
    ),

    // ── Shared pages ─────────────────────────────────────────────────────────
    GoRoute(path: '/history',       builder: (_, __) => const HistoryPage()),
    GoRoute(path: '/settings',      builder: (_, __) => const SettingsPage()),
    GoRoute(path: '/qr_scan',       builder: (_, __) => const QRScanPage()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
    GoRoute(path: '/security',      builder: (_, __) => const SecurityPage()),
    GoRoute(path: '/help_support',  builder: (_, __) => const HelpAndSupportPage()),
    GoRoute(path: '/analytics',     builder: (_, __) => const AnalyticsPage()),
  ],
);