import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NearbyStopsSection extends StatelessWidget {
  final String sortBy;
  final VoidCallback onSortToggle;

  const NearbyStopsSection({
    super.key,
    required this.sortBy,
    required this.onSortToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor = isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final sortBtnBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final sortBorder = isDark ? const Color(0x17FFFFFF) : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Arrêts à proximité',
                  style: hankenGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Autour de moi • 500 m',
                  style: hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
          ),

          // Right side: Sort Capsule
          GestureDetector(
            onTap: onSortToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sortBtnBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sortBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trier par : ',
                    style: hankenGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: mutedTextColor,
                    ),
                  ),
                  Text(
                    sortBy, // e.g. "Distance" or "Nom"
                    style: hankenGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 11,
                    color: mutedTextColor,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 12,
                    color: mutedTextColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    LucideIcons.slidersHorizontal,
                    size: 12,
                    color: mutedTextColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
