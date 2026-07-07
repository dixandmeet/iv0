import 'package:flutter/material.dart';

/// Palette « turquoise menthe » des écrans d'authentification Aule Pro,
/// alignée sur la charte officielle de la marque (voir docs/brand/README.md).
///
/// Distincte de [DriverHomePalette] (utilisée après connexion) : les écrans
/// de connexion/inscription forment une séquence à part (accueil du grand
/// public de l'app), avec son propre ton plus doux et « vitré ». Les deux
/// partagent désormais les mêmes teintes de marque (sarcelle/petrol).
abstract final class AuthPalette {
  static const sage = Color(0xFF76DCC8);
  static const forest = Color(0xFF1E8D82);
  static const forestDeep = Color(0xFF166B65);
  static const background = Color(0xFFD7F6EF);
  static const ink = Color(0xFF153C3A);

  static const success = Color(0xFF2ECC71);
  static const danger = Color(0xFFD64545);
  static const warning = Color(0xFFB9781A);

  static const fieldFill = Color(0xFFF4F8F7);
  static const fieldHint = Color(0xFF6E8C89);
}
