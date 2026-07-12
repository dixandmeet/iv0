import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette reprise du design Aule Pro (Claude Design « Aule Pro MVP »).
class AppColors {
  static const accent = Color(0xFF33BFA3);
  static const accentDark = Color(0xFF04211C);
  static const blue = Color(0xFF8FA6FF);
  static const boat = Color(0xFF7DD6E0);
  static const amber = Color(0xFFF5C451);
  static const red = Color(0xFFFF7A6E);
  // Fond légèrement vert et relevé, comme sur la maquette de référence.
  // Il reste suffisamment sombre pour conserver le contraste des cartes.
  static const bg = Color(0xFF090C0B);
  static const bgSoft = Color(0xFF0D1412);
  static const bgGlow = Color(0xFF08211D);
  static const cardBorder = Color(0x1AFFFFFF);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.spaceGroteskTextTheme(
      base.textTheme,
    ).apply(bodyColor: Colors.white, displayColor: Colors.white);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        surface: AppColors.bg,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
