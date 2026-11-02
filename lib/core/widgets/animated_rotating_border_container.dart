import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';

class AnimatedRotatingBorderContainer extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;

  /// Defaults to the brand teal sweep of the current theme.
  final List<Color>? gradientColors;
  final Duration duration;
  final EdgeInsetsGeometry? margin;

  const AnimatedRotatingBorderContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.borderWidth = 2.0,
    this.gradientColors,
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
          margin: widget.margin ?? const EdgeInsets.only(bottom: 14),
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              colors: gradientColors,
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
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
