import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';

/// PIN uzunligi.
const pinLength = 4;

/// PIN terish paneli: nuqtalar va raqamli klaviatura. 4 ta raqam terilganda
/// [onCompleted] chaqiriladi; u `false` qaytarsa — nuqtalar silkinib,
/// tozalanadi (noto'g'ri PIN).
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;

  /// Xato xabari (qizil) — berilsa [subtitle] o'rniga ko'rsatiladi.
  final String? error;
  final Future<bool> Function(String pin) onCompleted;

  /// Chap pastki tugma (masalan barmoq izi). `null` — bo'sh joy.
  final Widget? leading;

  /// Klaviatura ostidagi qo'shimcha (masalan "PIN-kodni unutdingizmi?").
  final Widget? footer;

  const PinPad({
    super.key,
    required this.title,
    this.subtitle,
    this.error,
    required this.onCompleted,
    this.leading,
    this.footer,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _press(String d) async {
    if (_busy || _pin.length >= pinLength) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _pin += d);
    if (_pin.length < pinLength) return;
    _busy = true;
    // Oxirgi nuqta to'lganini ko'rsin.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final ok = await widget.onCompleted(_pin);
    if (!mounted) return;
    if (!ok) {
      unawaited(HapticFeedback.heavyImpact());
      await _shake.forward(from: 0);
    }
    if (mounted) setState(() => _pin = '');
    _busy = false;
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = widget.error != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              widget.error ?? widget.subtitle ?? '',
              key: ValueKey(widget.error ?? widget.subtitle),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: hasError ? c.error : c.textSecondary,
                fontWeight: hasError ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              math.sin(_shake.value * math.pi * 5) * 14 * (1 - _shake.value),
              0,
            ),
            child: child,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < pinLength; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: i < _pin.length ? 18 : 16,
                  height: i < _pin.length ? 18 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? (hasError ? c.error : c.primary)
                        : Colors.transparent,
                    border: Border.all(
                      color: hasError ? c.error : c.primary,
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _slot(widget.leading ?? const SizedBox.shrink()),
            _key('0'),
            _slot(
              IconButton(
                iconSize: 28,
                onPressed: _pin.isEmpty ? null : _backspace,
                icon: Icon(Icons.backspace_outlined, color: c.textSecondary),
              ),
            ),
          ],
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: 12),
          widget.footer!,
        ],
      ],
    );
  }

  Widget _slot(Widget child) =>
      SizedBox(width: 96, height: 84, child: Center(child: child));

  Widget _key(String d) {
    final c = context.colors;
    return _slot(
      Material(
        color: c.surfaceVariant,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _press(d),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(
                d,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
