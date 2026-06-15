import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../aule/aule_icons.dart';

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor = isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final borderCol = isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Greetings
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bonjour 👋',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Où allez-vous aujourd'hui ?",
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right Side: Active Real-time status card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuleIcons.bus(
                  size: 16,
                  color: const Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Temps réel actif',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '12 véhicules détectés',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
