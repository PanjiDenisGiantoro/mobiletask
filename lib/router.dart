import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'splash_screen.dart';
import 'stitch_frontend_interface_application/welcome_screen.dart';
import 'stitch_frontend_interface_application/login_form_screen.dart';
import 'stitch_frontend_interface_application/register_form_screen.dart';
import 'stitch_frontend_interface_application/home_screen.dart';
import 'stitch_frontend_interface_application/projects_screen.dart';
import 'stitch_frontend_interface_application/tasks_screen.dart';
import 'stitch_frontend_interface_application/messages_screen.dart';
import 'stitch_frontend_interface_application/admin_settings_screen.dart';
import 'stitch_frontend_interface_application/shift_settings_screen.dart';
import 'stitch_frontend_interface_application/hris_screens.dart';
import 'stitch_frontend_interface_application/calendar_screen.dart';
import 'stitch_frontend_interface_application/reports_screen.dart';

/// Transisi fade, dipakai untuk splash → welcome (dan setiap kali kembali
/// ke welcome, misalnya sesudah logout) — meniru transisi asli di
/// [SplashScreen] sebelum migrasi ke go_router.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 500),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Transisi slide-up + fade + scale, meniru transisi asli welcome → login
/// dan welcome → register sebelum migrasi ke go_router.
CustomTransitionPage<void> _slideUpPage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 900),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutExpo);
      final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved);
      final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: curved, child: ScaleTransition(scale: scale, child: child)),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/welcome',
      pageBuilder: (context, state) => _fadePage(state, const WelcomeScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _slideUpPage(state, const LoginFormScreen()),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => _slideUpPage(state, const RegisterFormScreen()),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/projects', builder: (context, state) => const ProjectsScreen()),
    GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
    GoRoute(path: '/messages', builder: (context, state) => const MessagesScreen()),
    GoRoute(path: '/admin-settings', builder: (context, state) => const AdminSettingsScreen()),
    GoRoute(path: '/shift-settings', builder: (context, state) => const ShiftSettingsScreen()),
    GoRoute(path: '/attendance', builder: (context, state) => const AttendanceScreen()),
    GoRoute(path: '/leave', builder: (context, state) => const LeaveScreen()),
    GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
    GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
  ],
);
