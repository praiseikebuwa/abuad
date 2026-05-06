import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primaryBlue = primaryInk;
  static const Color secondaryBlue = secondaryTeal;
  static const Color accentGold = accentAmber;
  static const Color accentGoldLight = accentAmberLight;
  static const Color primaryInk = Color(0xFF0B1B3A);
  static const Color secondaryTeal = Color(0xFF1F5F5B);
  static const Color accentAmber = Color(0xFFFFB84D);
  static const Color accentAmberLight = Color(0xFFFFD79A);

  // Semantics
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF9A825);
  static const Color info = Color(0xFF0288D1);

  // Borders
  static const Color borderLight = Color(0xFFE2E8F0); // grey[200] roughly
  static const Color borderDark = Colors.white12;

  // Surfaces
  static const Color surfaceLight = Color(0xFFF9F6F1); // Updated warm off-white
  static const Color surfaceLightAlt = Color(0xFFFDFBF7);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0F1115);
  static const Color surfaceDarkSecondary = Color(0xFF171B22);
  static const Color surfaceDarkElevated = Color(0xFF1F2530);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF5B6475);

  // Gradients
  static const LinearGradient blueGradient = inkTealGradient;
  static const LinearGradient goldGradient = amberGradient;
  static const LinearGradient inkTealGradient = LinearGradient(
    colors: [primaryInk, secondaryTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [accentAmber, accentAmberLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [
      Color(0xFF0B1B3A), // primaryInk
      Color(0xFF1F5F5B), // secondaryTeal
      Color(0xFF2D3E5E), // A lighter navy
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Colors.white12,
      Colors.white10,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Gradient? primaryGradient;

  // Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];
}
