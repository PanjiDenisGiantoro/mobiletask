import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'splash_screen.dart';
import 'app/screens/welcome_screen.dart';
import 'app/screens/login_form_screen.dart';
import 'app/screens/register_form_screen.dart';
import 'app/screens/home_screen.dart';
import 'app/screens/projects_screen.dart';
import 'app/screens/tasks_screen.dart';
import 'app/screens/admin_settings_screen.dart';
import 'app/screens/shift_settings_screen.dart';
import 'app/screens/calendar_screen.dart';
import 'app/screens/reports_screen.dart';
import 'app/screens/ph_screens.dart';

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
    GoRoute(path: '/messages', builder: (context, state) => const ChatHubScreen()),
    GoRoute(path: '/chat', builder: (context, state) => const ChatHubScreen()),
    GoRoute(path: '/admin-settings', builder: (context, state) => const AdminSettingsScreen()),
    GoRoute(path: '/shift-settings', builder: (context, state) => const ShiftSettingsScreen()),
    GoRoute(path: '/attendance', builder: (context, state) => const AttendanceScreen()),
    GoRoute(path: '/leave', builder: (context, state) => const LeaveScreen()),
    GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
    GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
    // ── Modul projecthub_pro ────────────────────────────────────────────────
    GoRoute(
      path: '/form',
      // Konfigurasi form hanya ada di memori: kalau halaman dimuat ulang (extra hilang), kembali ke Home.
      redirect: (context, state) => state.extra is PhFormConfig ? null : '/home',
      builder: (context, state) => PhFormScreen(config: state.extra as PhFormConfig),
    ),
    GoRoute(path: '/project/:id', builder: (context, state) => ProjectDetailScreen(projectId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/task/:id', builder: (context, state) => TaskDetailScreen(taskId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/tickets', builder: (context, state) => const TicketsScreen()),
    GoRoute(path: '/ticket/:id', builder: (context, state) => TicketDetailScreen(ticketId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/requests', builder: (context, state) => const RequestsScreen()),
    GoRoute(path: '/request/:id', builder: (context, state) => RequestDetailScreen(requestId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/approvals', builder: (context, state) => const ApprovalsScreen()),
    GoRoute(path: '/approval/:id', builder: (context, state) => ApprovalDetailScreen(approvalId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/thread/:key', builder: (context, state) => ChatThreadScreen(threadKey: Uri.decodeComponent(state.pathParameters['key']!))),
    GoRoute(path: '/leave/:id', builder: (context, state) => LeaveDetailScreen(requestId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/overtime', builder: (context, state) => const OvertimeScreen()),
    GoRoute(path: '/overtime/:id', builder: (context, state) => OvertimeDetailScreen(overtimeId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/reimburse', builder: (context, state) => const ReimburseScreen()),
    GoRoute(path: '/reimburse/:id', builder: (context, state) => ReimburseDetailScreen(reimburseId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/kasbon', builder: (context, state) => const KasbonScreen()),
    GoRoute(path: '/kasbon/:id', builder: (context, state) => KasbonDetailScreen(kasbonId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/payroll', builder: (context, state) => const PayrollScreen()),
    GoRoute(path: '/payroll/:id', builder: (context, state) => PayslipScreen(payrollId: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/employees', builder: (context, state) => const EmployeesScreen()),
    GoRoute(path: '/employee/:id', builder: (context, state) => EmployeeDetailScreen(employeeId: state.pathParameters['id']!)),
    GoRoute(path: '/shift-schedule', builder: (context, state) => const ShiftScheduleScreen()),
    GoRoute(path: '/holidays', builder: (context, state) => const HolidaysScreen()),
    GoRoute(path: '/faces', builder: (context, state) => const FaceEnrollmentScreen()),
    GoRoute(path: '/attendance-settings', builder: (context, state) => const AttendanceSettingsScreen()),
  ],
);
