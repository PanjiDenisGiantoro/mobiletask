import 'package:flutter/material.dart';

class AppColors {
  // Palet biru SaaS modern Flovig yang seragam di seluruh halaman.
  static const primary900 = Color(0xFF0F172A);
  static const primary800 = Color(0xFF1E3A8A);
  static const primary700 = Color(0xFF1D4ED8);
  static const primary600 = Color(0xFF2563EB);
  static const primary400 = Color(0xFF60A5FA);
  static const primary200 = Color(0xFFBFDBFE);
  static const primary50  = Color(0xFFEFF6FF);

  static const accent400  = Color(0xFF0EA5E9);
  static const accent200  = Color(0xFFBAE6FD);

  static const success    = Color(0xFF16A34A);
  static const warning    = Color(0xFFF59E0B);
  static const error      = Color(0xFFDC2626);
  static const info       = Color(0xFF2563EB);

  static const successBg  = Color(0xFFECFDF5);
  static const warningBg  = Color(0xFFFEF3C7);
  static const errorBg    = Color(0xFFFEE2E2);

  static const grey900    = Color(0xFF0F172A);
  static const grey700    = Color(0xFF475569);
  static const grey500    = Color(0xFF64748B);
  static const grey400    = Color(0xFF94A3B8);
  static const grey100    = Color(0xFFF1F5F9);
  static const white      = Color(0xFFFFFFFF);
  static const border     = Color(0xFFE2E8F0);

  /// Gradasi hero & AppBar seragam (biru royal Flovig).
  static const heroStart  = Color(0xFF1D4ED8);
  static const heroMid    = Color(0xFF2563EB);
  static const heroEnd    = Color(0xFF3B82F6);

  /// Latar layar utama seragam (Slate 50) dipakai di semua halaman.
  static const bg         = Color(0xFFF8FAFC);

  /// Latar gelap untuk layar onboarding, senada dengan wordmark logo.
  static const onboardingBg    = Color(0xFF071A30);
  static const onboardingTrack = Color(0xFF163654);

  /// Palet Dark Mode (Slate Dark).
  static const darkBg              = Color(0xFF0B1120);
  static const darkSurface         = Color(0xFF111827);
  static const darkSurfaceElevated = Color(0xFF1E293B);
  static const darkBorder          = Color(0xFF283548);
  static const darkTextPrimary     = Color(0xFFF1F5F9);
  static const darkTextSecondary   = Color(0xFFCBD5E1);
  static const darkTextMuted       = Color(0xFF94A3B8);
  static const darkSuccessBg       = Color(0xFF052E16);
  static const darkWarningBg       = Color(0xFF451A03);
  static const darkErrorBg         = Color(0xFF450A0A);
}

class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double small  = 8;
  static const double medium = 12;
  static const double large  = 16;
  static const double xl     = 24;
  static const double full   = 100;
}

class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary600,
      primary: AppColors.primary600,
      surface: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.heroStart,
      foregroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.primary600,
      unselectedItemColor: AppColors.grey400,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
  );
}

ThemeData buildDarkAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary600,
      brightness: Brightness.dark,
      primary: AppColors.primary400,
      surface: AppColors.darkSurface,
    ),
    scaffoldBackgroundColor: AppColors.darkBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primary400,
      unselectedItemColor: AppColors.darkTextMuted,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.darkBorder),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceElevated,
      hintStyle: const TextStyle(color: AppColors.darkTextMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.primary400, width: 1.5),
      ),
    ),
  );
}

/// Helper warna adaptif Light/Dark mode melalui `context.colors`.
class AppAdaptiveColors {
  final bool isDark;
  const AppAdaptiveColors(this.isDark);

  Color get bg => isDark ? AppColors.darkBg : AppColors.bg;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.white;
  Color get surfaceAlt =>
      isDark ? AppColors.darkSurfaceElevated : AppColors.grey100;
  Color get border => isDark ? AppColors.darkBorder : AppColors.border;
  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.grey900;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.grey700;
  Color get textMuted => isDark ? AppColors.darkTextMuted : AppColors.grey500;
  Color get textFaint => isDark ? AppColors.darkTextMuted : AppColors.grey400;
  Color get primary => isDark ? AppColors.primary400 : AppColors.primary600;
  Color get primarySoft =>
      isDark ? AppColors.primary900.withValues(alpha: 0.65) : AppColors.primary50;
  Color get errorBg => isDark ? AppColors.darkErrorBg : AppColors.errorBg;
  Color get successBg => isDark ? AppColors.darkSuccessBg : AppColors.successBg;
  Color get warningBg => isDark ? AppColors.darkWarningBg : AppColors.warningBg;
  List<BoxShadow> get cardShadow => isDark ? const [] : AppShadows.card;
}

extension AppThemeContextX on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  AppAdaptiveColors get colors => AppAdaptiveColors(isDarkMode);
}
