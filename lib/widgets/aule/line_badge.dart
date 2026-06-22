import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../theme/aule_theme.dart';

/// Badge de ligne — couleur = ligne, forme = mode.
class LineBadge extends StatelessWidget {
  final String label;
  final AuleLineMode mode;
  final double size;
  final double fontSize;
  final Color? color;

  const LineBadge({
    super.key,
    required this.label,
    required this.mode,
    this.size = 32,
    this.fontSize = 12,
    this.color,
  });

  factory LineBadge.large({
    required String label,
    required AuleLineMode mode,
    Color? color,
  }) =>
      LineBadge(label: label, mode: mode, size: 38, fontSize: 14, color: color);

  factory LineBadge.medium({
    required String label,
    required AuleLineMode mode,
    Color? color,
  }) =>
      LineBadge(label: label, mode: mode, size: 34, fontSize: 13, color: color);

  factory LineBadge.small({
    required String label,
    required AuleLineMode mode,
    Color? color,
  }) =>
      LineBadge(label: label, mode: mode, size: 28, fontSize: 12, color: color);

  BorderRadius get _radius {
    switch (mode) {
      case AuleLineMode.tram:
        return BorderRadius.circular(AuleTokens.rBadge);
      case AuleLineMode.bus:
        return BorderRadius.circular(size / 2);
      case AuleLineMode.busway:
        return BorderRadius.circular(999);
    }
  }

  double get _width {
    final extra = label.length >= 3
        ? 14.0
        : label.length >= 2
            ? 8.0
            : 0.0;
    if (mode == AuleLineMode.busway) return size + 8 + extra * 0.5;
    return size + extra;
  }

  double get _fontSize {
    if (label.length >= 3 && fontSize > 12) return fontSize - 1;
    return fontSize;
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AuleLineColors.forLine(label);
    return Container(
      width: _width,
      height: size,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.6),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: hankenGrotesk(
          color: Colors.white,
          fontSize: _fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          height: 1,
        ),
      ),
    );
  }
}
