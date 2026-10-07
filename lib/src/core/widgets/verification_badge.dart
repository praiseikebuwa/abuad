import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final String type; // none, blue, gold, violet
  final double size;
  final bool showShadow;

  const VerificationBadge({
    super.key,
    required this.type,
    this.size = 16,
    this.showShadow = false,
  });

  static Color getBadgeColor(String rawType) {
    final clean = rawType.trim().toLowerCase();
    switch (clean) {
      case 'violet':
        return const Color(0xFF7C3AED); // Violet #7C3AED
      case 'gold':
        return const Color(0xFFD97706); // Gold #D97706
      case 'blue':
      default:
        return const Color(0xFF0284C7); // Blue #0284C7
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanType = type.trim().toLowerCase();
    if (cleanType == 'none' || cleanType.isEmpty) return const SizedBox.shrink();

    final color = getBadgeColor(cleanType);

    return Container(
      decoration: showShadow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: Icon(
        Icons.verified,
        size: size,
        color: color,
      ),
    );
  }
}
