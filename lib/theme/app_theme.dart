import 'package:flutter/material.dart';

class AppColors {
  static const orange = Color(0xFFFFA31A);
  static const gray = Color(0xFF808080);
  static const surface = Color(0xFF292929);
  static const background = Color(0xFF1B1B1B);
  static const white = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.orange,
      onPrimary: AppColors.background,
      secondary: AppColors.gray,
      onSecondary: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.white,
      error: Color(0xFFCF6679),
      onError: AppColors.background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        centerTitle: true,
      ),
      dividerColor: AppColors.surface,
      iconTheme: const IconThemeData(color: AppColors.white),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.orange,
        unselectedItemColor: AppColors.gray,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.gray.withValues(alpha: 0.35)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.orange, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.gray),
        hintStyle: const TextStyle(color: AppColors.gray),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.gray.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.white.withValues(alpha: 0.6),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.white),
      ),
    );
  }
}
