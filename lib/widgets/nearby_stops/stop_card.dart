import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/stop_data.dart';
import '../aule/aule_icons.dart';
import 'line_badge.dart';

class StopCard extends StatelessWidget {
  final StopData stop;
  final bool isSelected;
  final VoidCallback onTap;

  const StopCard({
    super.key,
    required this.stop,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Check dark mode
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Harmonious Colors
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor = isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol = isSelected
        ? const Color(0xFF1B66F5)
        : (isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0));
    final double borderThickness = isSelected ? 2.0 : 1.0;

    // Bus Icon container background
    final busIconBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEAF1FE);
    const busIconColor = Color(0xFF1B66F5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol, width: borderThickness),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF1B66F5).withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. LEFT SECTION (Icon + Distance)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: busIconBg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AuleIcons.bus(size: 20, color: busIconColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${stop.distance} m',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // 2. CENTER SECTION (Title + Subtitle + Badges)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stop.name,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '• ${stop.walkTime} min à pied  • ${stop.lines.length} lignes',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mutedTextColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: stop.lines.map((l) => LineBadge(label: l)).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 3. RIGHT SECTION (Chevron)
                Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: mutedTextColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
