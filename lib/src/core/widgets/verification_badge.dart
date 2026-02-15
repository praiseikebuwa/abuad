import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final String type; // none, blue, gold
  final double size;
  final bool showShadow;

  const VerificationBadge({
    super.key,
    required this.type,
    this.size = 16,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'none') return const SizedBox.shrink();

    final isGold = type == 'gold';

    return Container(
      decoration: showShadow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isGold ? Colors.orange : Colors.blue).withOpacity(
                    0.3,
                  ),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: Icon(
        Icons.verified,
        size: size,
        color: isGold ? Colors.orange : Colors.blue,
      ),
    );
  }
}
