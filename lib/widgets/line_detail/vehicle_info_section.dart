import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/line_detail_models.dart';

/// Section premium « Informations du véhicule ».
class VehicleInfoSection extends StatelessWidget {
  final String vehicleNumber;
  final String modeLabel;
  final String lineCode;
  final Color lineColor;
  final VehicleOccupancy occupancy;
  final int remainingStops;
  final int delayMinutes;
  final DateTime lastUpdate;
  final IconData vehicleIcon;
  final bool isRealtime;

  const VehicleInfoSection({
    super.key,
    required this.vehicleNumber,
    required this.modeLabel,
    required this.lineCode,
    required this.lineColor,
    required this.occupancy,
    required this.remainingStops,
    required this.delayMinutes,
    required this.lastUpdate,
    this.vehicleIcon = LucideIcons.bus,
    this.isRealtime = true,
  });

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
    final tileBg =
        isDark ? const Color(0xFF1B232F) : const Color(0xFFF8F9FB);

    final updateStr =
        '${lastUpdate.hour.toString().padLeft(2, '0')}:${lastUpdate.minute.toString().padLeft(2, '0')}';
    final delayOnTime = delayMinutes <= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Informations du véhicule',
                    style: hankenGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                    ),
                  ),
                  const Spacer(),
                  _StatusChip(isRealtime: isRealtime),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      lineColor.withValues(alpha: isDark ? 0.18 : 0.1),
                      lineColor.withValues(alpha: isDark ? 0.08 : 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: lineColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: lineColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(vehicleIcon, color: Colors.white, size: 20),
                          const SizedBox(height: 2),
                          Text(
                            lineCode,
                            style: hankenGrotesk(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleNumber,
                            style: hankenGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$modeLabel · Ligne $lineCode',
                            style: hankenGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mutedText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.radio,
                                size: 11,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                remainingStops <= 1
                                    ? 'Arrive à l\'arrêt'
                                    : '$remainingStops arrêts avant vous',
                                style: hankenGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          bg: tileBg,
                          icon: LucideIcons.users,
                          iconColor: _occupancyColor(occupancy),
                          iconBg: _occupancyColor(occupancy).withValues(alpha: 0.12),
                          label: 'Occupation',
                          child: _OccupancyBar(occupancy: occupancy),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          bg: tileBg,
                          icon: LucideIcons.clock,
                          iconColor: delayOnTime
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          iconBg: delayOnTime
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          label: 'Retard',
                          child: Text(
                            delayOnTime ? 'À l\'heure' : '+$delayMinutes min',
                            style: hankenGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: delayOnTime
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          bg: tileBg,
                          icon: LucideIcons.mapPin,
                          iconColor: const Color(0xFF1B66F5),
                          iconBg: const Color(0xFFEAF1FE),
                          label: 'Avant arrivée',
                          child: Text(
                            '$remainingStops',
                            style: hankenGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          bg: tileBg,
                          icon: LucideIcons.refreshCw,
                          iconColor: mutedText,
                          iconBg: isDark
                              ? const Color(0xFF252D3A)
                              : const Color(0xFFEEF0F4),
                          label: 'Mise à jour',
                          child: Text(
                            updateStr,
                            style: hankenGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _occupancyColor(VehicleOccupancy o) {
    switch (o) {
      case VehicleOccupancy.low:
        return const Color(0xFF16A34A);
      case VehicleOccupancy.medium:
        return const Color(0xFFF59E0B);
      case VehicleOccupancy.high:
        return const Color(0xFFDC2626);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final bool isRealtime;

  const _StatusChip({required this.isRealtime});

  @override
  Widget build(BuildContext context) {
    final bg = isRealtime
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFF3F4F6);
    final fg = isRealtime
        ? const Color(0xFF16A34A)
        : const Color(0xFF5B6677);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isRealtime ? 'Temps réel' : 'Estimé',
            style: hankenGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final Widget child;

  const _MetricTile({
    required this.bg,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final mutedText = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9BA7B7)
        : const Color(0xFF5B6677);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _OccupancyBar extends StatelessWidget {
  final VehicleOccupancy occupancy;

  const _OccupancyBar({required this.occupancy});

  @override
  Widget build(BuildContext context) {
    final (label, level, color) = switch (occupancy) {
      VehicleOccupancy.low => ('Faible', 0.3, const Color(0xFF16A34A)),
      VehicleOccupancy.medium => ('Moyenne', 0.6, const Color(0xFFF59E0B)),
      VehicleOccupancy.high => ('Élevée', 0.9, const Color(0xFFDC2626)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            width: double.infinity,
            child: Stack(
              children: [
                Container(color: color.withValues(alpha: 0.15)),
                FractionallySizedBox(
                  widthFactor: level,
                  child: Container(color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
