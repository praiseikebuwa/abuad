import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF0D47A1); // Deep University Blue
  static const Color secondaryBlue = Color(0xFF1976D2);
  static const Color accentGold = Color(0xFFFFD700); // Premium Gold
  static const Color accentGoldLight = Color(0xFFFFE57F);

  // Semantics
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFB74D);
  static const Color info = Color(0xFF29B6F6);

  // Surfaces
  static const Color surfaceLight = Color(0xFFF8F9FE);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceDarkSecondary = Color(0xFF1E1E1E);

  // Gradients
  static const LinearGradient blueGradient = LinearGradient(
    colors: [primaryBlue, secondaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [accentGold, accentGoldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}
