import 'package:flutter/material.dart';

/// Semantic color tokens for the whole app, available in a light and a dark
/// variant. Registered on [ThemeData.extensions] by `AppTheme`, so reading it
/// through `context.colors` subscribes the widget to theme changes and the
/// values animate together with the rest of the theme when the user switches.
///
/// Widgets should always pick a token by *meaning* (surface, textSecondary,
/// successSoft...) instead of hardcoding `Colors.white` or hex literals —
/// otherwise the widget will not follow dark mode.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Brand color: buttons, active states, links, icons.
  final Color primary;

  /// Content (text/icons) drawn on top of [primary] or other saturated fills.
  final Color onPrimary;

  /// Brand primary tinted for low-emphasis fills (icon badges, selected rows).
  final Color primarySoft;
  final Color accent;

  /// Scaffold / page background.
  final Color background;

  /// Cards, sheets, dialogs, app bars, inputs.
  final Color surface;

  /// Subtle fill layered on top of [surface] (list tiles, chips, inner boxes).
  final Color surfaceVariant;

  /// Slightly stronger fill than [surfaceVariant] (skeletons, pressed states,
  /// progress tracks).
  final Color surfaceStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  /// Hairline separators.
  final Color divider;

  /// Outlines of cards, inputs and chips.
  final Color border;

  final Color error;
  final Color errorSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color info;
  final Color infoSoft;

  /// Base color for [BoxShadow]s — already carries its alpha.
  final Color shadow;

  /// Shimmer skeleton colors.
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.divider,
    required this.border,
    required this.error,
    required this.errorSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.shadow,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const light = AppPalette(
    primary: Color(0xFF0D6E6E),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0x1A0D6E6E),
    accent: Color(0xFFF5A623),
    background: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF8FAFC),
    surfaceStrong: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B7280),
    textHint: Color(0xFF9CA3AF),
    divider: Color(0xFFE5E7EB),
    border: Color(0xFFE2E8F0),
    error: Color(0xFFDC2626),
    errorSoft: Color(0xFFFEF2F2),
    success: Color(0xFF16A34A),
    successSoft: Color(0xFFF0FDF4),
    warning: Color(0xFFF59E0B),
    warningSoft: Color(0xFFFFFBEB),
    info: Color(0xFF2563EB),
    infoSoft: Color(0xFFEFF6FF),
    shadow: Color(0x14000000),
    shimmerBase: Color(0xFFE5E7EB),
    shimmerHighlight: Color(0xFFF3F4F6),
  );

  static const dark = AppPalette(
    // Lighter teal: keeps ≥3:1 contrast for white labels on filled buttons
    // and ≥5:1 as text/icon color on the dark surfaces.
    primary: Color(0xFF2A9D98),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0x292A9D98),
    accent: Color(0xFFF5B041),
    background: Color(0xFF0F1216),
    surface: Color(0xFF1A1E24),
    surfaceVariant: Color(0xFF222730),
    surfaceStrong: Color(0xFF2A303A),
    textPrimary: Color(0xFFF1F3F5),
    textSecondary: Color(0xFFA3AAB5),
    textHint: Color(0xFF717985),
    divider: Color(0xFF2A2F37),
    border: Color(0xFF323843),
    error: Color(0xFFF87171),
    errorSoft: Color(0x29F87171),
    success: Color(0xFF4ADE80),
    successSoft: Color(0x244ADE80),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0x24FBBF24),
    info: Color(0xFF60A5FA),
    infoSoft: Color(0x2960A5FA),
    shadow: Color(0x66000000),
    shimmerBase: Color(0xFF232830),
    shimmerHighlight: Color(0xFF2E343E),
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? surfaceStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? divider,
    Color? border,
    Color? error,
    Color? errorSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? info,
    Color? infoSoft,
    Color? shadow,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      divider: divider ?? this.divider,
      border: border ?? this.border,
      error: error ?? this.error,
      errorSoft: errorSoft ?? this.errorSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      shadow: shadow ?? this.shadow,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primarySoft: l(primarySoft, other.primarySoft),
      accent: l(accent, other.accent),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceVariant: l(surfaceVariant, other.surfaceVariant),
      surfaceStrong: l(surfaceStrong, other.surfaceStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textHint: l(textHint, other.textHint),
      divider: l(divider, other.divider),
      border: l(border, other.border),
      error: l(error, other.error),
      errorSoft: l(errorSoft, other.errorSoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      shadow: l(shadow, other.shadow),
      shimmerBase: l(shimmerBase, other.shimmerBase),
      shimmerHighlight: l(shimmerHighlight, other.shimmerHighlight),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Current theme's color tokens. Rebuilds the caller on theme change.
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
