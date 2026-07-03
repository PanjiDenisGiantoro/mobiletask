import 'package:flutter/material.dart';

class AppColors {
  static const primary900 = Color(0xFF0D1B6E);
  static const primary800 = Color(0xFF1A237E);
  static const primary700 = Color(0xFF283593);
  static const primary600 = Color(0xFF3949AB);
  static const primary400 = Color(0xFF5C6BC0);
  static const primary200 = Color(0xFF9FA8DA);
  static const primary50  = Color(0xFFE8EAF6);

  static const accent400  = Color(0xFF26C6DA);
  static const accent200  = Color(0xFF80DEEA);

  static const success    = Color(0xFF43A047);
  static const warning    = Color(0xFFFB8C00);
  static const error      = Color(0xFFE53935);
  static const info       = Color(0xFF1E88E5);

  static const successBg  = Color(0xFFE8F5E9);
  static const warningBg  = Color(0xFFFFF3E0);
  static const errorBg    = Color(0xFFFFEBEE);

  static const grey900    = Color(0xFF212121);
  static const grey700    = Color(0xFF616161);
  static const grey500    = Color(0xFF9E9E9E);
  static const grey400    = Color(0xFFBDBDBD);
  static const grey100    = Color(0xFFF5F5F5);
  static const white      = Color(0xFFFFFFFF);

  static const heroStart  = Color(0xFF6D5DF6);
  static const heroMid    = Color(0xFF8B6DF7);
  static const heroEnd    = Color(0xFFB18CFF);

  /// Latar layar utama (lavender terang) dipakai di semua tab.
  static const bg         = Color(0xFFF7F5FF);
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
      color: Color(0x14212121),
      blurRadius: 12,
      offset: Offset(0, 4),
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
    scaffoldBackgroundColor: AppColors.grey100,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary700,
      foregroundColor: AppColors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
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
