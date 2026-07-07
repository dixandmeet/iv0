import 'package:flutter/material.dart';

/// Palette visuelle de l'espace conducteur (maquette Aule Pro).
///
/// Design premium, clair et très arrondi : fond blanc légèrement vert, vert
/// professionnel doux en couleur principale, accents chauds réservés aux
/// alertes / raccourcis.
///
/// Alignée sur la charte officielle Aule Pro (dégradé turquoise → menthe du
/// logo) : voir docs/brand/README.md pour la table de couleurs complète.
abstract final class DriverHomePalette {
  // --- Fonds ---
  static const background = Color(0xFFF8FCFB); // fond général
  static const card = Colors.white;

  // --- Verts de marque ---
  static const primary = Color(0xFF1E8D82); // vert principal (sarcelle)
  static const darkGreen = Color(0xFF153C3A); // vert foncé (texte principal)
  static const gradientStart = Color(0xFF1E8D82); // carte service (haut)
  static const gradientEnd = Color(0xFF166B65); // carte service (bas)
  static const softGreen = Color(0xFFB7EADF); // avatar / pastilles
  static const lightGreen = Color(0xFFD7F6EF); // fond actif nav / badge

  // --- Textes ---
  static const textDark = Color(0xFF153C3A); // texte principal
  static const textSecondary = Color(0xFF6E8C89); // texte secondaire

  // --- Bordures & ombres ---
  static const border = Color(0xFFE1EFEC);
  static const cardShadow = Color(0x0F153C3A); // ombre douce très légère

  // --- Accents ---
  static const warning = Color(0xFFF0913A); // orange retard / incident
  static const danger = Color(0xFFD64545); // rouge alerte / déconnexion
  static const blue = Color(0xFF2F80ED); // téléphone PC / tram
  static const purple = Color(0xFF7B61FF); // GPS / marqueurs carte (tram/busway)
  static const controlAccent = Color(0xFF5C6BC0); // accent mode contrôle (indigo doux)
  static const inactiveIcon = Color(0xFF8D9691); // icône nav inactive

  static Color delayColor(int minutes) {
    if (minutes == 0) return primary;
    if (minutes < 0) return blue;
    if (minutes >= 5) return danger;
    return warning;
  }

  static String delayLabel(int minutes) {
    if (minutes == 0) return 'À l\'heure';
    if (minutes > 0) return '+$minutes min';
    return '$minutes min';
  }
}
