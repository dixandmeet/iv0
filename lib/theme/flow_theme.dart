import 'package:flutter/material.dart';

/// Système visuel FLOW — « le Waze des transports en commun ».
///
/// Palette monochrome chaude (jamais bleutée), accent bleu électrique,
/// sémantique vert / orange / rouge avec variantes « soft » pour les fonds.
class FlowColors {
  FlowColors._();

  // Neutres chauds
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1A1916); // texte / icônes
  static const Color g2 = Color(0xFF8A877F); // gris secondaire
  static const Color gWeak = Color(0xFFB6B2A9); // gris faible
  static const Color fill = Color(0xFFF4F2EC);
  static const Color fill2 = Color(0xFFECEAE4);
  static const Color line = Color(0xFFE6E3DB);

  // Accent
  static const Color blue = Color(0xFF2F6BFF);
  static const Color blueSoft = Color(0xFFE7EEFF);

  // Sémantique
  static const Color green = Color(0xFF2F9E5F);
  static const Color greenSoft = Color(0xFFE4F3EA);
  static const Color orange = Color(0xFFE0892B);
  static const Color orangeSoft = Color(0xFFFBEEDD);
  static const Color red = Color(0xFFD6453E);
  static const Color redSoft = Color(0xFFFBE6E5);

  // Carte sombre (guidage)
  static const Color darkBg = Color(0xFF2A2824);
  static const Color darkRoad = Color(0xFF3A3833);
  static const Color darkWater = Color(0xFF201E1B);
}

/// Rayons, espacements et ombres de référence.
class FlowTokens {
  FlowTokens._();

  static const double margin = 16;
  static const double rCard = 16;
  static const double rCardXl = 28; // cartes premium (Citymapper-like)
  static const double rSheet = 20;
  static const double rBtn = 14;
  static const double rTile = 12;
  static const double btnHeight = 48;

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: FlowColors.ink.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: FlowColors.ink.withValues(alpha: 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get capsule => [
        BoxShadow(
          color: FlowColors.ink.withValues(alpha: 0.16),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get up => [
        BoxShadow(
          color: FlowColors.ink.withValues(alpha: 0.12),
          blurRadius: 30,
          offset: const Offset(0, -10),
        ),
      ];

  static List<BoxShadow> fab(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Styles typographiques signature.
class FlowText {
  FlowText._();

  /// Petit label de section : 10–11px majuscules, letterSpacing 1, gris faible.
  static const TextStyle kicker = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
    color: FlowColors.gWeak,
    height: 1.1,
  );

  /// Grand nombre clé en gras serré.
  static const TextStyle bigNumber = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    color: FlowColors.ink,
    height: 1.0,
  );

  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: FlowColors.ink,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: FlowColors.ink,
  );

  static const TextStyle rowTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: FlowColors.ink,
  );

  static const TextStyle rowSub = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: FlowColors.g2,
  );
}

/// Niveau d'affluence d'un véhicule.
enum CrowdLevel { low, mid, high }

/// Couleur sémantique d'un temps d'attente (départ transport en commun) :
/// 0-5 min vert (imminent/proche), 6-15 min orange (moyen), +15 min gris.
Color flowWaitColor(int minutes) => minutes <= 5
    ? FlowColors.green
    : (minutes <= 15 ? FlowColors.orange : FlowColors.gWeak);

/// Construit le ThemeData FLOW.
///
/// Material ne sert plus que de plomberie technique (Navigator, Overlay,
/// EditableText…) : aucun composant Material n'est rendu visuellement.
/// Tous les composants visibles sont les primitives FLOW
/// (voir `widgets/flow_primitives.dart`).
ThemeData buildFlowTheme() {
  return ThemeData(
    brightness: Brightness.light,
    // Couleurs techniques minimales (curseur, sélection, progress).
    colorScheme: const ColorScheme.light(
      primary: FlowColors.blue,
      onPrimary: Colors.white,
      surface: FlowColors.white,
      onSurface: FlowColors.ink,
      error: FlowColors.red,
      onError: Colors.white,
      outline: FlowColors.line,
    ),
    scaffoldBackgroundColor: FlowColors.white,
    fontFamily: 'Manrope',
    textTheme: const TextTheme().apply(
      bodyColor: FlowColors.ink,
      displayColor: FlowColors.ink,
    ),
    // Suppression totale du feedback Material (ripple/highlight) :
    // le feedback tactile FLOW est porté par FlowTappable.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: FlowColors.blue,
      selectionColor: FlowColors.blue.withValues(alpha: 0.25),
      selectionHandleColor: FlowColors.blue,
    ),
    dividerTheme: const DividerThemeData(
      color: FlowColors.line,
      thickness: 1,
      space: 1,
    ),
  );
}
