import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/gtfs.dart';
import '../../services/gtfs_service.dart';
import '../nearby_stops/line_badge.dart';
import '../schedule_source_badge.dart';

typedef DirectionTapCallback = void Function(
  GtfsRoute route,
  StationDeparture departure,
);

/// Carte de départ d'une ligne à l'arrêt (style maquette).
class DepartureCard extends StatelessWidget {
  final StationLineGroup group;
  final bool showDivider;

  /// Tap sur une direction → grille horaire du jour de cette ligne à l'arrêt.
  final DirectionTapCallback? onDirectionTap;

  /// Tap sur le badge de ligne → page ligne (tracé, carte, temps réel).
  final DirectionTapCallback? onLineTap;

  const DepartureCard({
    super.key,
    required this.group,
    this.showDivider = true,
    this.onDirectionTap,
    this.onLineTap,
  });

  IconData _vehicleIcon(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'tram':
        return LucideIcons.tramFront;
      case 'busway':
      case 'navibus':
      case 'bus':
      default:
        return LucideIcons.bus;
    }
  }

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

    final route = group.route;
    final label = route.routeShortName ?? route.routeId;
    final color = LineBadge.colorFor(label);
    final multi = group.directions.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: showDivider
            ? Border(bottom: BorderSide(color: borderCol, width: 1))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment:
            multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          _LineBadge(
            label: label,
            color: color,
            transportType: route.transportType,
            vehicleIcon: _vehicleIcon,
            onTap: onLineTap == null
                ? null
                : () => onLineTap!(route, group.directions.first),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < group.directions.length; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, thickness: 1, color: borderCol),
                    const SizedBox(height: 12),
                  ],
                  _DirectionRow(
                    departure: group.directions[i],
                    route: route,
                    primaryText: primaryText,
                    mutedText: mutedText,
                    compact: multi,
                    onTap: onDirectionTap == null
                        ? null
                        : () => onDirectionTap!(route, group.directions[i]),
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

class _LineBadge extends StatelessWidget {
  final String label;
  final Color color;
  final String transportType;
  final IconData Function(String) vehicleIcon;
  final VoidCallback? onTap;

  const _LineBadge({
    required this.label,
    required this.color,
    required this.transportType,
    required this.vehicleIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Icon(
            vehicleIcon(transportType),
            color: Colors.white.withValues(alpha: 0.9),
            size: 14,
          ),
        ],
      ),
    );
    if (onTap == null) return badge;
    return Semantics(
      button: true,
      label: 'Voir la ligne $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: badge,
      ),
    );
  }
}

class _DirectionRow extends StatelessWidget {
  final StationDeparture departure;
  final GtfsRoute route;
  final Color primaryText;
  final Color mutedText;
  final bool compact;
  final VoidCallback? onTap;

  const _DirectionRow({
    required this.departure,
    required this.route,
    required this.primaryText,
    required this.mutedText,
    required this.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final wait = departure.waitMinutes;
    final nextWait = departure.nextWaitMinutes;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                departure.headsign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                  letterSpacing: -0.2,
                ),
              ),
              if (route.routeLongName != null &&
                  route.routeLongName!.isNotEmpty &&
                  route.routeLongName != departure.headsign) ...[
                const SizedBox(height: 2),
                Text(
                  '→ ${route.routeLongName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedText,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              const ScheduleSourceBadge(),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$wait min',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 4),
                const _RealTimeSignal(color: Color(0xFF16A34A)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '• $nextWait min',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: mutedText,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            onTap != null ? LucideIcons.chevronRight : LucideIcons.ellipsisVertical,
            size: 18,
            color: mutedText,
          ),
        ),
      ],
    ),
    );
  }
}

class _RealTimeSignal extends StatelessWidget {
  final Color color;
  const _RealTimeSignal({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(4),
        const SizedBox(width: 1.5),
        _bar(7),
        const SizedBox(width: 1.5),
        _bar(10),
      ],
    );
  }

  Widget _bar(double h) => Container(
        width: 2,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      );
}
