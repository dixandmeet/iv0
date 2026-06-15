import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class QuickActionItem {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const QuickActionItem({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
}

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final borderCol = isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    final items = [
      QuickActionItem(
        label: 'Autour de moi',
        icon: LucideIcons.mapPin,
        iconColor: const Color(0xFF1B66F5),
        onTap: () {},
      ),
      QuickActionItem(
        label: 'Favoris',
        icon: LucideIcons.star,
        iconColor: const Color(0xFFFBC02D), // Yellow
        onTap: () {},
      ),
      QuickActionItem(
        label: 'Domicile',
        icon: LucideIcons.home,
        iconColor: const Color(0xFF16A34A), // Green
        onTap: () {},
      ),
      QuickActionItem(
        label: 'Travail',
        icon: LucideIcons.briefcase,
        iconColor: const Color(0xFF1B66F5), // Blue
        onTap: () {},
      ),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderCol),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with custom color
                      Icon(
                        item.icon,
                        color: item.iconColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      // Text label
                      Text(
                        item.label,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
