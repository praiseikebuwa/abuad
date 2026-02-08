import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme get lightTextTheme => GoogleFonts.spaceGroteskTextTheme(
    const TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: -1.0,
        fontSize: 57,
        height: 1.12, // Material 3 spec
        color: Colors.black87,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        fontSize: 45,
        height: 1.16,
        color: Colors.black87,
      ),
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        height: 1.25,
        color: Colors.black87,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1.27,
        color: Colors.black87,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        letterSpacing: 0.15,
        color: Colors.black87,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.25,
        color: Colors.black87,
      ),
    ),
  );

  static TextTheme get darkTextTheme => GoogleFonts.spaceGroteskTextTheme(
    const TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: -1.0,
        fontSize: 57,
        height: 1.12,
        color: Colors.white,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        fontSize: 45,
        height: 1.16,
        color: Colors.white,
      ),
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        height: 1.25,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1.27,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        letterSpacing: 0.15,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.25,
        color: Colors.white,
      ),
    ),
  );
}
