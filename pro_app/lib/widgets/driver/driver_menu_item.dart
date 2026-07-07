import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/driver_home_palette.dart';

/// Une ligne de menu : icône à gauche (dans une pastille douce), libellé,
/// badge optionnel et chevron. Pensée pour être groupée dans une carte blanche
/// (cf. [DriverMenuGroup]).
class DriverMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badge;
  final bool destructive;
  final bool showChevron;
  final VoidCallback onTap;

  const DriverMenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.badge,
    this.destructive = false,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        destructive ? DriverHomePalette.danger : DriverHomePalette.primary;
    final textColor =
        destructive ? DriverHomePalette.danger : DriverHomePalette.textDark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight:
                      destructive ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DriverHomePalette.danger,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (showChevron)
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: DriverHomePalette.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte blanche regroupant plusieurs [DriverMenuItem], séparés par de fins
/// filets.
class DriverMenuGroup extends StatelessWidget {
  final List<Widget> items;

  const DriverMenuGroup({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(items[i]);
      if (i != items.length - 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.only(left: 68),
            child: Divider(height: 1, color: DriverHomePalette.border),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }
}
