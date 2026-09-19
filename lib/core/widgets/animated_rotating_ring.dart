import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedRotatingRing extends StatefulWidget {
  final Widget child;
  final double size;
  final double borderWidth;
  final List<Color> gradientColors;
  final Duration duration;

  const AnimatedRotatingRing({
    super.key,
    required this.child,
    this.size = 110,
    this.borderWidth = 3.5,
    this.gradientColors = const [
      Color(0xFF0D6E6E),
      Color(0xFF139797),
      Color(0xFF26BBAA),
      Color(0xFF084B4B),
      Color(0xFF0D6E6E),
    ],
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<AnimatedRotatingRing> createState() => _AnimatedRotatingRingState();
}

class _AnimatedRotatingRingState extends State<AnimatedRotatingRing>
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
          width: widget.size,
          height: widget.size,
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: widget.gradientColors,
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withValues(alpha: 0.25),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2),
            child: widget.child,
          ),
        );
      },
    );
  }
}
