import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primaryGreen = Color(0xFF2E7D32);
  static const lightGreen = Color(0xFF4CAF50);
  static const darkGreen = Color(0xFF1B5E20);
  static const accentGreen = Color(0xFF81C784);
  static const backgroundLight = Color(0xFFF5F9F5);
  static const cardLight = Colors.white;
  static const backgroundDark = Color(0xFF121212);
  static const cardDark = Color(0xFF1E1E1E);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
}

class AppTheme {
  static TextTheme _textTheme(ThemeData base, Locale locale) {
    if (locale.languageCode == 'ar') {
      return GoogleFonts.cairoTextTheme(base.textTheme);
    }
    return GoogleFonts.interTextTheme(base.textTheme);
  }

  static ThemeData light(Locale locale) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryGreen,
        secondary: AppColors.lightGreen,
        surface: AppColors.cardLight,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.cardLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
    );
    return base.copyWith(textTheme: _textTheme(base, locale));
  }

  static ThemeData dark(Locale locale) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.lightGreen,
        brightness: Brightness.dark,
        primary: AppColors.lightGreen,
        secondary: AppColors.accentGreen,
        surface: AppColors.cardDark,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.cardDark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.cardDark,
        foregroundColor: Colors.white,
      ),
    );
    return base.copyWith(textTheme: _textTheme(base, locale));
  }
}
