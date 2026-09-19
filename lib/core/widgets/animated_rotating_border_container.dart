import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedRotatingBorderContainer extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final List<Color> gradientColors;
  final Duration duration;
  final EdgeInsetsGeometry? margin;

  const AnimatedRotatingBorderContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.borderWidth = 2.0,
    this.gradientColors = const [
      Color(0xFF0D6E6E),
      Color(0xFF139797),
      Color(0xFF26BBAA),
      Color(0xFF084B4B),
      Color(0xFF0D6E6E),
    ],
    this.duration = const Duration(seconds: 4),
    this.margin,
  });

  @override
  State<AnimatedRotatingBorderContainer> createState() =>
      _AnimatedRotatingBorderContainerState();
}

class _AnimatedRotatingBorderContainerState
    extends State<AnimatedRotatingBorderContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: widget.margin ?? const EdgeInsets.only(bottom: 14),
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              colors: widget.gradientColors,
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                widget.borderRadius - widget.borderWidth,
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
