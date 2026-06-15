import 'package:flutter/material.dart';

/// Tokens visuels pour la navigation immersive premium (#00B050).
class PremiumNavTheme {
  PremiumNavTheme._();

  static const brand = Color(0xFF00B050);
  static const brandDark = Color(0xFF009040);
  static const brandLight = Color(0xFFE6F7ED);
  static const bg = Color(0xFFF3F5F8);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF0B1220);
  static const muted = Color(0xFF5B6677);
  static const faint = Color(0xFF9AA4B2);
  static const warn = Color(0xFFB45309);
  static const warnBg = Color(0xFFFEF3C7);
  static const overlay = Color(0xD90B1220);

  static const radiusLg = 28.0;
  static const radiusMd = 20.0;
  static const radiusSm = 16.0;

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF101828).withValues(alpha: 0.08),
      blurRadius: 28,
      offset: const Offset(0, 10),
      spreadRadius: -12,
    ),
  ];

  static List<BoxShadow> brandGlow = [
    BoxShadow(
      color: brand.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
