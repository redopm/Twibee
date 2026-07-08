import 'package:flutter/material.dart';

/// ChatWave App Theme - Orange & White
/// Use these constants across all screens for consistency.
class AppColors {
  static const Color orange = Color(0xFFFF6B00);
  static const Color orangeLight = Color(0xFFFF8C42);
  static const Color orangePale = Color(0xFFFFF2E0);
  static const Color white = Color(0xFFFFFFFF);
  static const Color dark = Color(0xFF1A1A1A);
  static const Color grey = Color(0xFF666666);
  static const Color grey2 = Color(0xFF999999);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color border = Color(0xFFE0E0E0);
  static const Color green = AppColors.orange;
  static const Color red = Color(0xFFF24040);
  static const Color blue = Color(0xFF3399FF);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFD100), orange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.dark,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.dark,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 13,
    color: AppColors.grey,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.grey2,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.grey2,
    letterSpacing: 0.5,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.orange,
      scaffoldBackgroundColor: AppColors.white,
      fontFamily: 'Inter',
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        primary: AppColors.orange,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.dark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        toolbarHeight: 60,
      ),
      dividerColor: AppColors.border,
      cardColor: AppColors.white,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      primaryColor: AppColors.orange,
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamily: 'Inter',
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        primary: AppColors.orange,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E1E),
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        toolbarHeight: 60,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Color(0xFF1E1E1E),
        textColor: Colors.white,
      ),
      dividerColor: const Color(0xFF2C2C2C),
      cardColor: const Color(0xFF1E1E1E),
    );
  }
}

