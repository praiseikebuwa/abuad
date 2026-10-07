import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
String formatCount(int count) {
  if (count <= 0) return '';
  if (count >= 1000000) {
    double m = count / 1000000;
    return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}M';
  } else if (count >= 1000) {
    double k = count / 1000;
    return '${k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}k';
  }
  return '$count';
}

class AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final int count;
  final VoidCallback onTap;

  final bool showCount;
  final double iconSize;
  final Color? activeColor;
  final Color? inactiveColor;

  const AnimatedLikeButton({
    super.key,
    required this.isLiked,
    required this.count,
    required this.onTap,
    this.showCount = true,
    this.iconSize = 18,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final countText = formatCount(widget.count);

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  widget.isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  key: ValueKey(widget.isLiked),
                  size: widget.iconSize,
                  color: widget.isLiked
                      ? (widget.activeColor ?? Colors.red)
                      : (widget.inactiveColor ?? Colors.grey[600]),
                ),
              ),
            ),
            if (widget.showCount && countText.isNotEmpty) ...[
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  countText,
                  key: ValueKey(countText),
                  style: TextStyle(
                    color: widget.isLiked
                        ? (widget.activeColor ?? Colors.red)
                        : (widget.inactiveColor ?? Colors.grey[600]),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
