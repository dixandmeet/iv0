import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens de design Aule — thème clair et sombre.
class AuleColors {
  const AuleColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.faint,
    required this.line,
    required this.lineSoft,
    required this.brand,
    required this.brandWeak,
    required this.brandLine,
    required this.ok,
    required this.okBg,
    required this.warn,
    required this.mapBg,
    required this.mapRoad,
    required this.mapRoad2,
    required this.mapWater,
    required this.mapBlock,
    required this.chip,
    required this.chipLine,
    required this.navBg,
    required this.shadow,
    required this.brandShadow,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color text;
  final Color muted;
  final Color faint;
  final Color line;
  final Color lineSoft;
  final Color brand;
  final Color brandWeak;
  final Color brandLine;
  final Color ok;
  final Color okBg;
  final Color warn;
  final Color mapBg;
  final Color mapRoad;
  final Color mapRoad2;
  final Color mapWater;
  final Color mapBlock;
  final Color chip;
  final Color chipLine;
  final Color navBg;
  final Color shadow;
  final Color brandShadow;
  final bool isDark;

  static const light = AuleColors(
    bg: Color(0xFFF3F5F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF2F4F8),
    text: Color(0xFF0B1220),
    muted: Color(0xFF5B6677),
    faint: Color(0xFF9AA4B2),
    line: Color(0xFFE7EAF0),
    lineSoft: Color(0xFFF0F2F6),
    brand: Color(0xFF1B66F5),
    brandWeak: Color(0xFFEAF1FE),
    brandLine: Color(0xFFCFE0FD),
    ok: Color(0xFF15803D),
    okBg: Color(0xFFDCF2E4),
    warn: Color(0xFFB45309),
    mapBg: Color(0xFFE5E9F0),
    mapRoad: Color(0xFFFFFFFF),
    mapRoad2: Color(0xFFD9DEE8),
    mapWater: Color(0xFFD5E0EE),
    mapBlock: Color(0xFFDBE0E9),
    chip: Color(0xDBFFFFFF),
    chipLine: Color(0x0F0B1220),
    navBg: Color(0xE6FFFFFF),
    shadow: Color(0x2E101828),
    brandShadow: Color(0x801B66F5),
    isDark: false,
  );

  static const dark = AuleColors(
    bg: Color(0xFF0A0D13),
    surface: Color(0xFF141A23),
    surface2: Color(0xFF1B232F),
    text: Color(0xFFEFF3F9),
    muted: Color(0xFF9BA7B7),
    faint: Color(0xFF6B7889),
    line: Color(0x17FFFFFF),
    lineSoft: Color(0x0DFFFFFF),
    brand: Color(0xFF5B8DEF),
    brandWeak: Color(0x295B8DEF),
    brandLine: Color(0x4D5B8DEF),
    ok: Color(0xFF34D399),
    okBg: Color(0x2E34D399),
    warn: Color(0xFFFBBF24),
    mapBg: Color(0xFF0E141C),
    mapRoad: Color(0xFF1C242F),
    mapRoad2: Color(0xFF19212C),
    mapWater: Color(0xFF0C1822),
    mapBlock: Color(0xFF161E28),
    chip: Color(0xD1141A23),
    chipLine: Color(0x1AFFFFFF),
    navBg: Color(0xE00E131A),
    shadow: Color(0xB3000000),
    brandShadow: Color(0x80000000),
    isDark: true,
  );
}

/// Couleurs des lignes du réseau Naolib (Nantes).
class AuleLineColors {
  AuleLineColors._();

  static const Map<String, Color> byCode = {
    '1': Color(0xFF16A34A),
    '2': Color(0xFFE11D48),
    '4': Color(0xFF9333EA),
    '5': Color(0xFF0EA5A4),
    '12': Color(0xFF7C3AED),
    '26': Color(0xFF2563EB),
    'C6': Color(0xFFF59E0B),
    'NN': Color(0xFF0EA5A4),
  };

  static Color forLine(String code) =>
      byCode[code] ?? const Color(0xFF5B6677);
}

enum AuleLineMode { tram, bus, busway }

AuleLineMode auleModeFromLabel(String label) {
  switch (label.toLowerCase()) {
    case 'tramway':
    case 'tram':
      return AuleLineMode.tram;
    case 'chronobus':
    case 'busway':
      return AuleLineMode.busway;
    default:
      return AuleLineMode.bus;
  }
}

class AuleTokens {
  AuleTokens._();

  static const double rCard = 22;
  static const double rCardSm = 18;
  static const double rSearch = 17;
  static const double rBadge = 9;
  static const double mapHeaderHeight = 282;
  static const double minTouch = 44;

  static List<BoxShadow> cardShadow(Color shadow) => [
        BoxShadow(
          color: shadow,
          blurRadius: 28,
          offset: const Offset(0, 10),
          spreadRadius: -18,
        ),
      ];

  static List<BoxShadow> searchShadow(Color shadow) => [
        BoxShadow(
          color: shadow,
          blurRadius: 30,
          offset: const Offset(0, 14),
          spreadRadius: -14,
        ),
      ];
}

class AuleTheme extends InheritedWidget {
  const AuleTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  final AuleColors colors;

  static AuleColors of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuleTheme>()!.colors;
  }

  @override
  bool updateShouldNotify(AuleTheme oldWidget) =>
      colors != oldWidget.colors;
}

TextTheme auleTextTheme(AuleColors c) {
  final base = GoogleFonts.hankenGroteskTextTheme();
  return base.apply(
    bodyColor: c.text,
    displayColor: c.text,
  ).copyWith(
    displayLarge: GoogleFonts.hankenGrotesk(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.4,
      color: c.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    headlineMedium: GoogleFonts.hankenGrotesk(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: c.text,
    ),
    titleMedium: GoogleFonts.hankenGrotesk(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: c.text,
    ),
    bodyMedium: GoogleFonts.hankenGrotesk(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: c.muted,
    ),
    labelSmall: GoogleFonts.hankenGrotesk(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: c.muted,
    ),
  );
}

ThemeData buildAuleTheme({required bool isDark}) {
  final c = isDark ? AuleColors.dark : AuleColors.light;
  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.bg,
    fontFamily: GoogleFonts.hankenGrotesk().fontFamily,
    textTheme: auleTextTheme(c),
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    useMaterial3: false,
  );
}

/// Horloge temps réel — tick chaque seconde pour les ETA.
class AuleClock extends ChangeNotifier {
  AuleClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  late final Timer _timer;
  final DateTime start = DateTime.now();

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
