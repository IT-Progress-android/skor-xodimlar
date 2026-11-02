import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';

class AnimatedRotatingRing extends StatefulWidget {
  final Widget child;
  final double size;
  final double borderWidth;

  /// Defaults to the brand teal sweep of the current theme.
  final List<Color>? gradientColors;
  final Duration duration;

  const AnimatedRotatingRing({
    super.key,
    required this.child,
    this.size = 110,
    this.borderWidth = 3.5,
    this.gradientColors,
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
    final c = context.colors;
    final gradientColors =
        widget.gradientColors ??
        [
          c.primary,
          const Color(0xFF139797),
          const Color(0xFF26BBAA),
          const Color(0xFF084B4B),
          c.primary,
        ];
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
              colors: gradientColors,
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.25),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
            padding: const EdgeInsets.all(2),
            child: widget.child,
          ),
        );
      },
    );
  }
}
