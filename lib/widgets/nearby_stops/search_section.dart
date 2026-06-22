import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchSection extends StatelessWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onLocateTap;
  final String hintText;

  const SearchSection({
    super.key,
    this.onSearchTap,
    this.onLocateTap,
    this.hintText = 'Destination, adresse, arrêt...',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final mutedTextColor = isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol = isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(32),
          child: InkWell(
            onTap: onSearchTap,
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Left search icon
                  Icon(
                    LucideIcons.search,
                    color: mutedTextColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),

                  // Center placeholder text
                  Expanded(
                    child: Text(
                      hintText,
                      style: hankenGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),

                  // Right GPS button
                  GestureDetector(
                    onTap: onLocateTap,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B66F5),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        LucideIcons.navigation, // Diagonal arrow icon
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
