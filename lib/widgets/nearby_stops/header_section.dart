import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../services/disruption_service.dart';
import '../../theme/app_fonts.dart';

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Bonne nuit';
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final borderCol = isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    final disruptions = context.watch<DisruptionService>();
    final impacted = disruptions.impactedLineCodes.length;
    final hasDisruptions = impacted > 0;

    final dotColor =
        hasDisruptions ? const Color(0xFFF59E0B) : const Color(0xFF16A34A);
    final statusLabel = hasDisruptions ? 'Réseau perturbé' : 'Réseau fluide';
    final statusDetail = hasDisruptions
        ? '$impacted ligne${impacted > 1 ? 's' : ''} impactée${impacted > 1 ? 's' : ''}'
        : 'Trafic normal';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _greeting(),
                  style: hankenGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Où allez-vous aujourd'hui ?",
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
                Icon(
                  hasDisruptions ? LucideIcons.triangleAlert : LucideIcons.bus,
                  size: 16,
                  color: dotColor,
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
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: hankenGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusDetail,
                      style: hankenGrotesk(
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
