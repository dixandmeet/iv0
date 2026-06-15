import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// En-tête de la page détail arrêt : nom de l'arrêt + retour accueil.
class StopDetailHeader extends StatelessWidget {
  final String stopName;
  final VoidCallback onBack;

  /// Sous-titre optionnel (ex. « 320 m · 5 min à pied » ou « 3 lignes »).
  final String? meta;

  /// Affiche le pictogramme d'accessibilité PMR à côté du sous-titre.
  final bool accessible;

  const StopDetailHeader({
    super.key,
    required this.stopName,
    required this.onBack,
    this.meta,
    this.accessible = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: "Retour à l'accueil",
            child: Material(
              color: cardBg,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderCol),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.arrowLeft,
                    size: 20,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stopName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    height: 1.2,
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(LucideIcons.footprints,
                          size: 13, color: mutedTextColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          meta!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: mutedTextColor,
                          ),
                        ),
                      ),
                      if (accessible) ...[
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.accessibility,
                            size: 14, color: Color(0xFF2F9E5F)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
