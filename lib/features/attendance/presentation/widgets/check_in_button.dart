import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';

/// Ultra-Responsive Butter-Smooth Slide-to-Confirm Button (Zero Lag, Zero Stuck)
class CheckInButton extends StatefulWidget {
  final bool isCheckIn;
  final VoidCallback onPressed;

  const CheckInButton({
    super.key,
    required this.isCheckIn,
    required this.onPressed,
  });

  @override
  State<CheckInButton> createState() => _CheckInButtonState();
}

class _CheckInButtonState extends State<CheckInButton>
    with TickerProviderStateMixin {
  double _dragValue = 0.0; // 0.0 to 1.0
  bool _isSubmitted = false;

  late AnimationController _resetController;
  late Animation<double> _resetAnimation;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _resetController.addListener(() {
      setState(() {
        _dragValue = _resetAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onDragStart(double localX, double maxWidth) {
    if (_isSubmitted) return;
    _resetController.stop();
    _updateDragFromX(localX, maxWidth);
  }

  void _onDragUpdate(double localX, double maxWidth) {
    if (_isSubmitted) return;
    _updateDragFromX(localX, maxWidth);
  }

  void _updateDragFromX(double localX, double maxWidth) {
    const thumbSize = 52.0;
    const padding = 5.0;
    final maxDrag = maxWidth - thumbSize - (padding * 2);

    final val = ((localX - padding - (thumbSize / 2)) / maxDrag).clamp(
      0.0,
      1.0,
    );
    setState(() {
      _dragValue = val;
    });
  }

  void _onDragEnd(double maxWidth) {
    if (_isSubmitted) return;

    if (_dragValue >= 0.75) {
      // Confirmed! Slide smoothly to end
      setState(() {
        _dragValue = 1.0;
        _isSubmitted = true;
      });

      widget.onPressed();

      // Reset after brief delay
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _dragValue = 0.0;
            _isSubmitted = false;
          });
        }
      });
    } else {
      // Smooth spring back to start
      _resetAnimation = Tween<double>(begin: _dragValue, end: 0.0).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
      );
      _resetController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color startColor = widget.isCheckIn
        ? const Color(0xFF0D6E6E)
        : const Color(0xFFF59E0B);
    final Color endColor = widget.isCheckIn
        ? const Color(0xFF033838)
        : const Color(0xFF8B1A00);

    final Color currentColor = Color.lerp(startColor, endColor, _dragValue)!;
    final String textLabel = widget.isCheckIn
        ? context.tr('checkin_slide_to_checkin')
        : context.tr('checkin_slide_to_checkout');

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double height = 62.0;
        const double padding = 5.0;
        const double thumbSize = height - (padding * 2);
        final double maxThumbOffset = width - thumbSize - (padding * 2);
        final double currentThumbOffset = _dragValue * maxThumbOffset;

        return GestureDetector(
          onHorizontalDragStart: (d) => _onDragStart(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) =>
              _onDragUpdate(d.localPosition.dx, width),
          onHorizontalDragEnd: (_) => _onDragEnd(width),
          child: Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: currentColor.withValues(
                    alpha: 0.18 + (_dragValue * 0.22),
                  ),
                  blurRadius: 14 + (_dragValue * 8),
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                children: [
                  // 1. Smooth Progress Fill with Rounded Circular End Cap
                  if (_dragValue > 0.01)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: padding + thumbSize + currentThumbOffset,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(31),
                          gradient: LinearGradient(
                            colors: [startColor, currentColor],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),

                  // 2. Track Hint Text & Animated Wave Chevrons (> > >)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 68, right: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Opacity(
                              opacity: (1.0 - (_dragValue * 2.2)).clamp(
                                0.0,
                                1.0,
                              ),
                              child: Text(
                                textLabel,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Opacity(
                            opacity: (1.0 - (_dragValue * 2.2)).clamp(0.0, 1.0),
                            child: AnimatedBuilder(
                              animation: _shimmerController,
                              builder: (context, _) {
                                final v = _shimmerController.value;
                                final op1 = (sin(v * 2 * pi) * 0.4 + 0.6).clamp(
                                  0.2,
                                  1.0,
                                );
                                final op2 =
                                    (sin((v * 2 * pi) - 1.0) * 0.4 + 0.6).clamp(
                                      0.2,
                                      1.0,
                                    );
                                final op3 =
                                    (sin((v * 2 * pi) - 2.0) * 0.4 + 0.6).clamp(
                                      0.2,
                                      1.0,
                                    );

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Opacity(
                                      opacity: op1,
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: 22,
                                        color: startColor,
                                      ),
                                    ),
                                    Opacity(
                                      opacity: op2,
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: 22,
                                        color: startColor,
                                      ),
                                    ),
                                    Opacity(
                                      opacity: op3,
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: 22,
                                        color: startColor,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Success Label inside dark track (Fades in when swiping)
                  Positioned.fill(
                    child: Center(
                      child: Opacity(
                        opacity: (_dragValue * 2.0 - 0.5).clamp(0.0, 1.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isCheckIn
                                  ? context.tr('checkin_confirmed_in')
                                  : context.tr('checkin_confirmed_out'),
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Ultra-Smooth Sliding Knob Handle (100% Equal Top and Bottom Spacing)
                  Positioned(
                    left: padding + currentThumbOffset,
                    top: padding,
                    bottom: padding,
                    width: thumbSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                          BoxShadow(
                            color: startColor.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _isSubmitted
                                ? Icons.check_rounded
                                : (widget.isCheckIn
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded),
                            key: ValueKey(
                              'icon_${_isSubmitted}_${widget.isCheckIn}',
                            ),
                            color: _isSubmitted ? Colors.green : startColor,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
