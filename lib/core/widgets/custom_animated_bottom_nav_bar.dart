import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';

class CustomBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isCenter;

  const CustomBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isCenter = false,
  });
}

class CustomAnimatedBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final List<CustomBottomNavItem> items;

  const CustomAnimatedBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.items,
  });

  @override
  State<CustomAnimatedBottomNavBar> createState() =>
      _CustomAnimatedBottomNavBarState();
}

class _CustomAnimatedBottomNavBarState extends State<CustomAnimatedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _fromIndex;
  late double _toIndex;

  // Fluid spring-like curve that glides fast and settles with a gentle liquid cushion
  static const Cubic _liquidCurve = Cubic(0.22, 1.16, 0.36, 1.0);

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex.toDouble();
    _toIndex = widget.selectedIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
  }

  @override
  void didUpdateWidget(covariant CustomAnimatedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final currentAnimatedPos = _currentAnimatedIndex;
      _fromIndex = currentAnimatedPos;
      _toIndex = widget.selectedIndex.toDouble();
      _controller
        ..reset()
        ..forward();
    }
  }

  double get _currentAnimatedIndex {
    if (!_controller.isAnimating) {
      return _toIndex;
    }
    final curved = _liquidCurve.transform(_controller.value);
    return lerpDouble(_fromIndex, _toIndex, curved) ?? _toIndex;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _measureLabelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.items.length;
    final c = context.colors;
    final isDark = context.isDarkMode;

    // Narrow phones (≤360dp) get tighter side margins so 5 tabs still fit.
    final isCompact = MediaQuery.sizeOf(context).width <= 360;
    final sidePadding = isCompact ? 8.0 : 14.0;

    return RepaintBoundary(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: sidePadding,
            right: sidePadding,
            bottom: 10,
            top: 4,
          ),
          child: SizedBox(
            height: 70,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final avgItemWidth = totalWidth / itemCount;

                // Pre-calculate desired droplet width for each tab based on its text length
                final maxAllowedLensWidth = math.min(
                  totalWidth * 0.38,
                  avgItemWidth + 42.0,
                );
                final desiredLensWidths = List<double>.generate(itemCount, (i) {
                  final textW = _measureLabelWidth(
                    context,
                    widget.items[i].label,
                  );
                  // Add 28px horizontal padding (14px each side) so the rounded glass wraps the text cleanly
                  return (textW + 28.0).clamp(60.0, maxAllowedLensWidth);
                });

                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      // Soft airy Skor teal-tinted elevation shadow for Light Mode
                      BoxShadow(
                        color: context.colors.primary.withValues(alpha: 0.13),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                      // Crisp subtle ambient contact shadow
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.05,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: CustomPaint(
                      foregroundPainter: _LightOuterGlassCapsuleRimPainter(
                        primary: c.primary,
                        isDark: isDark,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(35),
                          // Crystal Pearl / Ice-Teal Frosted Glass (no BackdropFilter needed -> 120fps over YandexMap)
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDark
                                ? [
                                    c.surface.withValues(alpha: 0.96),
                                    const Color(
                                      0xFF182A2B,
                                    ).withValues(alpha: 0.94),
                                    const Color(
                                      0xFF132527,
                                    ).withValues(alpha: 0.97),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.96),
                                    const Color(
                                      0xFFF2FBFB,
                                    ).withValues(alpha: 0.94),
                                    const Color(
                                      0xFFE6F5F5,
                                    ).withValues(alpha: 0.96),
                                  ],
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final pos = _currentAnimatedIndex.clamp(
                              0.0,
                              (itemCount - 1).toDouble(),
                            );

                            // Calculate dynamic slot widths so the active tab's slot widens
                            // to match its text-adaptive lens, pushing neighboring tabs gently aside
                            final extraWanted = List<double>.generate(
                              itemCount,
                              (i) {
                                final activeFactor = (1.0 - (pos - i).abs())
                                    .clamp(0.0, 1.0);
                                final targetSlotWidth = math.max(
                                  avgItemWidth,
                                  desiredLensWidths[i] + 6.0,
                                );
                                return activeFactor *
                                    (targetSlotWidth - avgItemWidth);
                              },
                            );
                            final totalExtra = extraWanted.fold<double>(
                              0.0,
                              (sum, v) => sum + v,
                            );
                            final baseSlotWidth =
                                (totalWidth - totalExtra) / itemCount;
                            final slotWidths = List<double>.generate(
                              itemCount,
                              (i) => baseSlotWidth + extraWanted[i],
                            );

                            final slotCenters = List<double>.filled(
                              itemCount,
                              0.0,
                            );
                            double runningLeft = 0.0;
                            for (int i = 0; i < itemCount; i++) {
                              slotCenters[i] = runningLeft + slotWidths[i] / 2;
                              runningLeft += slotWidths[i];
                            }

                            final floorIdx = pos.floor().clamp(
                              0,
                              itemCount - 1,
                            );
                            final ceilIdx = pos.ceil().clamp(0, itemCount - 1);
                            final frac = pos - floorIdx;

                            final centerX =
                                lerpDouble(
                                  slotCenters[floorIdx],
                                  slotCenters[ceilIdx],
                                  frac,
                                ) ??
                                slotCenters[floorIdx];
                            final baseLensWidth =
                                lerpDouble(
                                  desiredLensWidths[floorIdx],
                                  desiredLensWidths[ceilIdx],
                                  frac,
                                ) ??
                                desiredLensWidths[floorIdx];

                            // Jelly/liquid stretch during travel
                            final travelDelta = (_toIndex - _fromIndex)
                                .abs()
                                .clamp(0.0, 2.5);
                            final stretchPhase = _controller.isAnimating
                                ? math.sin(_controller.value * math.pi)
                                : 0.0;
                            final extraWidth =
                                stretchPhase * (12.0 + travelDelta * 4.0);
                            final squashHeight = stretchPhase * 3.0;

                            final lensWidth = baseLensWidth + extraWidth;
                            final lensHeight = 58.0 - squashHeight;

                            final left = (centerX - lensWidth / 2).clamp(
                              4.0,
                              totalWidth - lensWidth - 4.0,
                            );

                            return Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.centerLeft,
                              children: [
                                // 1. Top pure-white specular glass reflection strip
                                Positioned(
                                  top: 1,
                                  left: 24,
                                  right: 24,
                                  height: 1.5,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(
                                            alpha: isDark ? 0.18 : 1.0,
                                          ),
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // 2. Text-Adaptive Sliding "Liquid Glass" Lens / Droplet Indicator
                                Positioned(
                                  left: left,
                                  top: (70.0 - lensHeight) / 2,
                                  width: lensWidth,
                                  height: lensHeight,
                                  child: _LightLiquidDropletLens(
                                    stretchFactor: stretchPhase,
                                  ),
                                ),

                                // 3. Interactive Tab Items Row with adaptive slot widths
                                Row(
                                  children: List.generate(itemCount, (index) {
                                    final isSelected =
                                        widget.selectedIndex == index;
                                    final item = widget.items[index];

                                    return SizedBox(
                                      width: slotWidths[index],
                                      height: 70,
                                      child: GestureDetector(
                                        onTap: () {
                                          if (widget.selectedIndex != index) {
                                            HapticFeedback.selectionClick();
                                          }
                                          widget.onItemTapped(index);
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: _LightLiquidTabItemWidget(
                                          item: item,
                                          isSelected: isSelected,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Light & Dark Mode 3D Convex Liquid Glass Droplet that stretches horizontally
/// to wrap the active tab's text label cleanly.
class _LightLiquidDropletLens extends StatelessWidget {
  final double stretchFactor;

  const _LightLiquidDropletLens({required this.stretchFactor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDarkMode;
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        // Soft inner Skor Teal-Aqua liquid bloom behind the active icon & text
        Center(
          child: Container(
            width: 52,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF139797).withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 3,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0xFF26BBAA).withValues(alpha: 0.24),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),

        // Convex Crystal Water-Drop Capsule body
        CustomPaint(
          painter: _LightLiquidDropletRimPainter(
            stretchFactor: stretchFactor,
            primary: c.primary,
            isDark: isDark,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.14),
                        c.primary.withValues(alpha: 0.30),
                        c.primary.withValues(alpha: 0.20),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.92),
                        const Color(0xFFD6F5F3).withValues(alpha: 0.82),
                        const Color(0xFFB3EAE6).withValues(alpha: 0.78),
                      ],
              ),
            ),
            child: Stack(
              children: [
                // Top curved water-droplet gloss highlight (creates 3D convex lens effect)
                Positioned(
                  top: 3,
                  left: 12,
                  right: 12,
                  height: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.22 : 0.95),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LightLiquidTabItemWidget extends StatelessWidget {
  final CustomBottomNavItem item;
  final bool isSelected;

  const _LightLiquidTabItemWidget({
    required this.item,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Active color: Deep Skor Brand Teal (#0D6E6E) with luminous emerald clarity
    final activeColor = context.colors.primary;
    // Inactive color: Clean slate grey matching the Light Mode cards
    final inactiveIconColor = context.colors.textSecondary;
    final inactiveTextColor = context.colors.textSecondary;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: isSelected ? 1.0 : 0.0,
        end: isSelected ? 1.0 : 0.0,
      ),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final scale = 1.0 + (0.12 * t);
        final translateY = -1.5 * t;
        final iconColor = Color.lerp(inactiveIconColor, activeColor, t)!;
        final textColor = Color.lerp(inactiveTextColor, activeColor, t)!;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: 34,
                  height: 30,
                  child: Center(
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      size: 23,
                      color: iconColor,
                      shadows: t > 0.2
                          ? [
                              Shadow(
                                color: const Color(
                                  0xFF139797,
                                ).withValues(alpha: 0.35 * t),
                                blurRadius: 10 * t,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              // Shrink long labels ("Бухгалтерия", "Bosh sahifa") to fit
              // narrow tabs instead of cutting them off with an ellipsis.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.1,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paints the outer Light Mode crystal capsule's specular glass bevel border.
class _LightOuterGlassCapsuleRimPainter extends CustomPainter {
  final Color primary;
  final bool isDark;

  _LightOuterGlassCapsuleRimPainter({
    required this.primary,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.6),
      const Radius.circular(35),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.4, 0.75, 1.0],
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.16 : 1.0),
          const Color(0xFF139797).withValues(alpha: 0.22),
          primary.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: isDark ? 0.10 : 0.85),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _LightOuterGlassCapsuleRimPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.isDark != isDark;
}

/// Paints the 3D optical water-drop glass refraction rim around the sliding droplet lens in Light Mode.
class _LightLiquidDropletRimPainter extends CustomPainter {
  final double stretchFactor;
  final Color primary;
  final bool isDark;

  _LightLiquidDropletRimPainter({
    required this.stretchFactor,
    required this.primary,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      const Radius.circular(22),
    );

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.35, 0.7, 1.0],
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.30 : 1.0),
          const Color(0xFF26BBAA).withValues(alpha: 0.45),
          primary.withValues(alpha: 0.30),
          const Color(0xFF139797).withValues(alpha: 0.55),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _LightLiquidDropletRimPainter oldDelegate) =>
      oldDelegate.stretchFactor != stretchFactor ||
      oldDelegate.primary != primary ||
      oldDelegate.isDark != isDark;
}
