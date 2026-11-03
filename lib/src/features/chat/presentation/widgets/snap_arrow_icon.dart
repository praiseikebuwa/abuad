import 'package:flutter/material.dart';

/// The classic Snapchat-style arrow icon used to represent sent/delivered/opened Snaps.
/// Points directly right (east) with an arrowhead profile.
class SnapArrowIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isFilled;

  const SnapArrowIcon({
    super.key,
    this.size = 14,
    this.color = const Color(0xFFF22543),
    this.isFilled = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SnapArrowPainter(color: color, isFilled: isFilled),
    );
  }
}

class _SnapArrowPainter extends CustomPainter {
  final Color color;
  final bool isFilled;

  _SnapArrowPainter({required this.color, required this.isFilled});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Arrowhead geometry pointing right
    final path = Path()
      ..moveTo(w * 0.05, h * 0.08)
      ..lineTo(w * 0.95, h * 0.50)
      ..lineTo(w * 0.05, h * 0.92)
      ..lineTo(w * 0.28, h * 0.50)
      ..close();

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke;

    if (!isFilled) {
      paint.strokeWidth = w * 0.16;
      paint.strokeJoin = StrokeJoin.round;
      paint.strokeCap = StrokeCap.round;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SnapArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isFilled != isFilled;
}
