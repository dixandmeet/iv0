import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

class LineBadge extends StatelessWidget {
  final String label;
  final double height;
  final double fontSize;

  const LineBadge({
    super.key,
    required this.label,
    this.height = 24,
    this.fontSize = 12,
  });

  static Color colorFor(String lineLabel) {
    switch (lineLabel.toUpperCase()) {
      case '1':
        return const Color(0xFF16A34A);
      case 'C6':
        return const Color(0xFF8B258F);
      case '23':
        return const Color(0xFF007BC4);
      case '75':
        return const Color(0xFFF29400);
      case '80':
        return const Color(0xFFFBC02D);
      case 'C1':
        return const Color(0xFFE30613);
      case '12':
        return const Color(0xFF4FAADB);
      case '96':
        return const Color(0xFF8EC63F);
      case 'C2':
        return const Color(0xFF00A650);
      case '30':
        return const Color(0xFFE5007D);
      case 'C20':
        return const Color(0xFF003A70);
      case 'E1':
        return const Color(0xFF009BA4);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color get _badgeColor {
    switch (label.toUpperCase()) {
      case '1':
        return const Color(0xFF16A34A); // Green
      case 'C6':
        return const Color(0xFF8B258F); // Purple
      case '23':
        return const Color(0xFF007BC4); // Blue
      case '75':
        return const Color(0xFFF29400); // Orange
      case '80':
        return const Color(0xFFFBC02D); // Yellow (amber for white text visibility)
      case 'C1':
        return const Color(0xFFE30613); // Red
      case '12':
        return const Color(0xFF4FAADB); // Light Blue
      case '96':
        return const Color(0xFF8EC63F); // Light Green
      case 'C2':
        return const Color(0xFF00A650); // Darker Green
      case '30':
        return const Color(0xFFE5007D); // Pink
      case 'C20':
        return const Color(0xFF003A70); // Dark Indigo
      case 'E1':
        return const Color(0xFF009BA4); // Teal
      default:
        return const Color(0xFF6B7280); // Neutral grey
    }
  }

  bool get _isNumeric {
    final numericRegex = RegExp(r'^[0-9]+$');
    return numericRegex.hasMatch(label);
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor;
    final textWidget = Text(
      label,
      style: hankenGrotesk(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      textAlign: TextAlign.center,
    );

    if (_isNumeric) {
      // Circle shape for purely numeric lines
      return Container(
        width: height,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: textWidget,
      );
    } else {
      // Pill shape for alphanumeric (e.g., C6, E1)
      return Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            textWidget,
          ],
        ),
      );
    }
  }
}
