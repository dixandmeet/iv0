import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/driver/driver_workspace_mode.dart';
import '../../theme/driver_home_palette.dart';

/// Aperçu persona (conducteur / contrôleur) affiché à côté de la carte profil.
class DriverPersonaModeCard extends StatelessWidget {
  final String asset;
  final DriverWorkspaceMode mode;

  const DriverPersonaModeCard({
    super.key,
    required this.asset,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final accent = mode.accentColor;

    return Container(
      width: 76,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 58,
            child: Transform.scale(
              scale: 1.35,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => Icon(
                  mode == DriverWorkspaceMode.conduite
                      ? LucideIcons.bus
                      : LucideIcons.shieldCheck,
                  color: accent,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mode.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
