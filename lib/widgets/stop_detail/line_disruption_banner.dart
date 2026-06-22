import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/report.dart';
import '../../theme/aule_theme.dart';

/// Bandeau d'alerte signalant qu'une ou plusieurs lignes sont perturbées.
///
/// Deux usages :
///  • fiche d'arrêt ([showDescriptions] = false) : résumé + puces des lignes
///    impactées, tap → page Alertes & perturbations ;
///  • fiche ligne ([showDescriptions] = true) : détail des perturbations de la
///    ligne courante.
class LineDisruptionBanner extends StatelessWidget {
  final List<Report> reports;
  final AuleColors colors;
  final VoidCallback? onTap;
  final bool showDescriptions;

  const LineDisruptionBanner({
    super.key,
    required this.reports,
    required this.colors,
    this.onTap,
    this.showDescriptions = false,
  });

  Color get _accent =>
      colors.isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const SizedBox.shrink();

    final lines = <String>[];
    for (final r in reports) {
      if (!lines.contains(r.routeId)) lines.add(r.routeId);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.32)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.triangleAlert, size: 20, color: _accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showDescriptions
                        ? (reports.length > 1
                            ? '${reports.length} perturbations en cours'
                            : 'Perturbation en cours')
                        : (reports.length > 1
                            ? '${reports.length} perturbations sur cet arrêt'
                            : 'Perturbation sur cet arrêt'),
                    style: hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (showDescriptions)
                    ...reports.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          r.description ?? r.typeLabel,
                          style: hankenGrotesk(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: colors.muted,
                          ),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final line in lines)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              line,
                              style: hankenGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 18, color: colors.faint),
            ],
          ],
        ),
      ),
    );
  }
}
