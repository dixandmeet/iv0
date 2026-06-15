import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/line_detail_models.dart';
import '../line_detail/realtime_signal.dart';

/// Carte d'information véhicule — ligne, direction, ETA, affluence.
class VehicleInfoCard extends StatelessWidget {
  final String lineCode;
  final Color lineColor;
  final String direction;
  final String stopName;
  final int waitMinutes;
  final int waitSeconds;
  final DateTime estimatedArrival;
  final VehicleOccupancy occupancy;
  final bool isApproaching;
  final double approachProgress;
  final IconData vehicleIcon;

  const VehicleInfoCard({
    super.key,
    required this.lineCode,
    required this.lineColor,
    required this.direction,
    this.stopName = '',
    required this.waitMinutes,
    this.waitSeconds = 0,
    required this.estimatedArrival,
    required this.occupancy,
    this.isApproaching = false,
    this.approachProgress = 0,
    this.vehicleIcon = LucideIcons.tramFront,
  });

  String get _etaLabel {
    if (isApproaching && waitSeconds > 0 && waitSeconds < 60) {
      return '$waitSeconds s';
    }
    if (waitMinutes <= 1 && isApproaching) return 'Imminent';
    return '$waitMinutes min';
  }

  @override
  Widget build(BuildContext context) {
    final etaColor = isApproaching ? const Color(0xFFF59E0B) : lineColor;
    final timeStr =
        '${estimatedArrival.hour.toString().padLeft(2, '0')}:${estimatedArrival.minute.toString().padLeft(2, '0')}';
    final progress = approachProgress.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isApproaching
              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
              : const Color(0xFFE7EAF0),
          width: isApproaching ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isApproaching ? const Color(0xFFF59E0B) : Colors.black)
                .withValues(alpha: isApproaching ? 0.1 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stopName.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  LucideIcons.mapPin,
                  size: 13,
                  color: lineColor,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'À l\'arrêt $stopName',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5B6677),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isApproaching)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'En approche',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LineBadge(
                code: lineCode,
                color: lineColor,
                icon: vehicleIcon,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direction',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9AA4B2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      direction,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isApproaching ? 'Arrivée imminente' : 'Prochain passage',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: etaColor,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _etaLabel,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: isApproaching && waitSeconds < 60 ? 26 : 28,
                          fontWeight: FontWeight.w800,
                          color: etaColor,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: RealtimeSignal(color: etaColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9AA4B2),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (progress > 0.04) ...[
            const SizedBox(height: 14),
            _ApproachProgressBar(progress: progress, color: lineColor),
          ],
          const SizedBox(height: 14),
          _OccupancyRow(occupancy: occupancy),
        ],
      ),
    );
  }
}

class _ApproachProgressBar extends StatelessWidget {
  final double progress;
  final Color color;

  const _ApproachProgressBar({
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.navigation, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              'Le véhicule se rapproche',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5B6677),
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()} %',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _LineBadge extends StatelessWidget {
  final String code;
  final Color color;
  final IconData icon;

  const _LineBadge({
    required this.code,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 2),
          Text(
            code,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _OccupancyRow extends StatelessWidget {
  final VehicleOccupancy occupancy;

  const _OccupancyRow({required this.occupancy});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, bars) = switch (occupancy) {
      VehicleOccupancy.low => (
          'Faible affluence',
          LucideIcons.users,
          const Color(0xFF16A34A),
          1,
        ),
      VehicleOccupancy.medium => (
          'Moyenne affluence',
          LucideIcons.users,
          const Color(0xFFF59E0B),
          2,
        ),
      VehicleOccupancy.high => (
          'Forte affluence',
          LucideIcons.users,
          const Color(0xFFDC2626),
          3,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Row(
            children: List.generate(3, (i) {
              final filled = i < bars;
              return Container(
                width: 4,
                height: 8 + i * 3,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: filled
                      ? color
                      : color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
