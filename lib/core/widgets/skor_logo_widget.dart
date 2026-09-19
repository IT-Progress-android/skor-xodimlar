import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

/// Official Native Lottie Chronometer Brand Logo Widget for Skor Xodimlar:
/// Plays 'assets/animations/Chronometer.json' with exact original 60fps Lottie vector animation!
class SkorLogoWidget extends StatelessWidget {
  final double size;
  final bool showText;
  final bool animateParticles;

  const SkorLogoWidget({
    super.key,
    this.size = 140,
    this.showText = true,
    this.animateParticles = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Lottie.asset(
            'assets/animations/Chronometer.json',
            fit: BoxFit.contain,
            animate: animateParticles,
            repeat: true,
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 6),
          Text(
            'SKOR',
            style: GoogleFonts.outfit(
              fontSize: (size * 0.24).clamp(12.0, 32.0),
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0D6E6E),
              height: 0.95,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            'XODIMLAR',
            style: GoogleFonts.outfit(
              fontSize: (size * 0.18).clamp(10.0, 24.0),
              fontWeight: FontWeight.w800,
              color: const Color(0xFFF5A623),
              height: 1.0,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
