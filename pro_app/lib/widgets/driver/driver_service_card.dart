import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/driver_home_palette.dart';

/// Grande carte du service en cours : dégradé vert foncé, ligne / véhicule,
/// grille d'informations (début service, direction, prochain départ, retard) et
/// deux actions (« Voir le trajet », « Fin service »).
class DriverServiceCard extends StatelessWidget {
  final String line; // ex. « Ligne C6 »
  final String? serviceCode; // ex. « Service 142 »
  final String? vehicleLabel; // ex. « Bus 3625 »
  final String departure; // origine
  final String direction; // destination / sens
  final String nextDeparture; // ex. « 10:15 »
  final int delayMinutes;
  final bool busy;
  final VoidCallback onViewRoute;
  final Future<void> Function() onEndService;

  const DriverServiceCard({
    super.key,
    required this.line,
    this.serviceCode,
    this.vehicleLabel,
    required this.departure,
    required this.direction,
    required this.nextDeparture,
    required this.delayMinutes,
    required this.busy,
    required this.onViewRoute,
    required this.onEndService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            DriverHomePalette.gradientStart,
            DriverHomePalette.gradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: DriverHomePalette.gradientEnd.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (serviceCode != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        serviceCode!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (vehicleLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    vehicleLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InfoCell(label: 'Début service', value: departure),
                    ),
                    Expanded(
                      child: _InfoCell(label: 'Direction', value: direction),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _InfoCell(
                        label: 'Prochain départ',
                        value: nextDeparture,
                        emphasize: true,
                      ),
                    ),
                    Expanded(
                      child: _InfoCell(
                        label: 'Retard',
                        value: DriverHomePalette.delayLabel(delayMinutes),
                        emphasize: true,
                        valueColor: delayMinutes > 0
                            ? const Color(0xFFFFC078)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  icon: LucideIcons.mapPlus,
                  label: 'Voir le trajet',
                  filled: true,
                  onPressed: onViewRoute,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CardButton(
                  icon: LucideIcons.circleStop,
                  label: 'Fin service',
                  filled: false,
                  busy: busy,
                  onPressed: busy ? null : () => onEndService(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  const _InfoCell({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: emphasize ? 17 : 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback? onPressed;

  const _CardButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.busy = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? DriverHomePalette.gradientEnd : Colors.white;
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: filled
            ? BorderSide.none
            : BorderSide(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                )
              else
                Icon(icon, size: 17, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
