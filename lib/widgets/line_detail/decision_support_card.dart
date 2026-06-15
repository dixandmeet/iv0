import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/line_detail_models.dart';

/// Carte d'aide à la décision contextuelle.
class DecisionSupportCard extends StatelessWidget {
  final DecisionInsight insight;

  const DecisionSupportCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedText =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    final miss = insight.willMissPassage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          children: [
            _Row(
              icon: LucideIcons.clock,
              iconColor: miss
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF16A34A),
              iconBg: miss
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFDCFCE7),
              title: 'Départ conseillé dans ${insight.recommendedLeaveMinutes} min',
              subtitle: 'Pour arriver à temps à l\'arrêt',
              trailing: miss
                  ? const SizedBox(width: 28)
                  : _OkBadge(),
              primaryText: miss ? const Color(0xFFDC2626) : primaryText,
              mutedText: mutedText,
              borderCol: borderCol,
              showDivider: true,
            ),
            _Row(
              icon: LucideIcons.footprints,
              iconColor: const Color(0xFF1B66F5),
              iconBg: const Color(0xFFEAF1FE),
              title: 'Temps de marche jusqu\'à l\'arrêt',
              subtitle: '${insight.walkMinutes} min (${insight.walkMeters} m)',
              trailing: miss
                  ? const SizedBox(width: 28)
                  : _OkBadge(),
              primaryText: primaryText,
              mutedText: mutedText,
              borderCol: borderCol,
              showDivider: true,
            ),
            if (insight.willMissPassage)
              _Row(
                icon: LucideIcons.triangleAlert,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEE2E2),
                title: 'Vous risquez de manquer ce passage',
                subtitle: 'Départ conseillé inférieur au temps de marche',
                trailing: Icon(LucideIcons.chevronRight, size: 18, color: mutedText),
                primaryText: const Color(0xFFDC2626),
                mutedText: mutedText,
                borderCol: borderCol,
                showDivider: false,
              )
            else if (insight.willArriveBeforeVehicle)
              _Row(
                icon: LucideIcons.circleCheck,
                iconColor: const Color(0xFF16A34A),
                iconBg: const Color(0xFFDCFCE7),
                title: 'Vous arriverez avant le véhicule',
                subtitle:
                    'Distance jusqu\'au véhicule : ${insight.vehicleDistanceKm.toStringAsFixed(1)} km',
                trailing: _OkBadge(),
                primaryText: primaryText,
                mutedText: mutedText,
                borderCol: borderCol,
                showDivider: false,
              )
            else
              _Row(
                icon: LucideIcons.mapPin,
                iconColor: const Color(0xFF1B66F5),
                iconBg: const Color(0xFFEAF1FE),
                title: 'Distance jusqu\'au véhicule',
                subtitle: '${insight.vehicleDistanceKm.toStringAsFixed(1)} km',
                trailing: _OkBadge(),
                primaryText: primaryText,
                mutedText: mutedText,
                borderCol: borderCol,
                showDivider: false,
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color primaryText;
  final Color mutedText;
  final Color borderCol;
  final bool showDivider;

  const _Row({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.primaryText,
    required this.mutedText,
    required this.borderCol,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: borderCol, indent: 64),
      ],
    );
  }
}

class _OkBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Ok',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF16A34A),
        ),
      ),
    );
  }
}
