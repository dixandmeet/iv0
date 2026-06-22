import 'package:flutter/material.dart';

/// Police Hanken Grotesk désormais **bundlée** dans les assets
/// (voir `assets/fonts/HankenGrotesk-Variable.ttf` + `pubspec.yaml`).
///
/// On n'utilise plus `GoogleFonts.hankenGrotesk(...)`, qui télécharge la police
/// via le réseau au runtime (latence + risque de timeout en mode hors-ligne).
/// Ce helper centralisé reproduit la même signature pour rester un
/// remplacement direct, mais pointe vers la famille embarquée.
const String kHankenGroteskFamily = 'Hanken Grotesk';

/// Équivalent local de `GoogleFonts.hankenGrotesk(...)` : renvoie un [TextStyle]
/// utilisant la famille bundlée, sans aucun fetch réseau.
TextStyle hankenGrotesk({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  List<FontVariation>? fontVariations,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  return (textStyle ?? const TextStyle()).copyWith(
    fontFamily: kHankenGroteskFamily,
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    fontVariations: fontVariations,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}

/// Équivalent local de `GoogleFonts.hankenGroteskTextTheme([base])`.
TextTheme hankenGroteskTextTheme([TextTheme? textTheme]) {
  final base = textTheme ?? ThemeData.light().textTheme;
  return base.apply(fontFamily: kHankenGroteskFamily);
}
