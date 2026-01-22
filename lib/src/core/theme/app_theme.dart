import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentGold,
        surface: AppColors.surfaceLight,
        onSurface: Colors.black87,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.surfaceLight,

      // Typography
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: AppTypography.lightTextTheme,

      // AppBar
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent, // Transparent for gradients
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black87,
        iconTheme: IconThemeData(color: Colors.black87),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shadowColor: Colors.black.withOpacity(0.05),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentGold,
        surface: AppColors.surfaceDarkSecondary,
        onSurface: Colors.white,
        error: AppColors.error,
        brightness: Brightness.dark,
        background: AppColors.surfaceDark,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,

      // Typography
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: AppTypography.darkTextTheme,

      // AppBar
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
      ),

      // Cards
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        color: AppColors.surfaceDarkSecondary,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }
}
