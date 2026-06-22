import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../models/aule_models.dart';
import '../../theme/aule_theme.dart';
import '../../utils/aule_eta.dart';
import 'line_badge.dart';

/// Ligne de départ dans la liste « Prochains départs ».
class DepartureRow extends StatelessWidget {
  final AuleLineDeparture departure;
  final DateTime now;
  final bool showDivider;

  const DepartureRow({
    super.key,
    required this.departure,
    required this.now,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    final eta = auleEtaSeconds(departure.arrivalAt, now);
    final fmt = formatAuleEta(eta);
    final color = etaColor(c, fmt.urgent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: c.lineSoft, width: 1))
            : null,
      ),
      child: Row(
        children: [
          LineBadge.medium(
            label: departure.label,
            mode: departure.mode,
            color: departure.lineColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  departure.destination,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: hankenGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.15,
                    color: c.text,
                  ),
                ),
                Text(
                  departure.modeLabel,
                  style: hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  fmt.num,
                  maxLines: 1,
                  style: hankenGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.4,
                    height: 1,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (fmt.unit.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(
                    fmt.unit,
                    style: hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: c.muted,
                    ),
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

/// Ligne de départ dans une carte d'arrêt (ETA 22px).
class StopDepartureRow extends StatelessWidget {
  final AuleLineDeparture departure;
  final DateTime now;

  const StopDepartureRow({
    super.key,
    required this.departure,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    final eta = auleEtaSeconds(departure.arrivalAt, now);
    final fmt = formatAuleEta(eta);
    final color = etaColor(c, fmt.urgent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          LineBadge.large(
            label: departure.label,
            mode: departure.mode,
            color: departure.lineColor,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  departure.destination,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: hankenGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.15,
                    color: c.text,
                  ),
                ),
                Text(
                  departure.modeLabel,
                  style: hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmt.text,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: hankenGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (fmt.urgent) ...[
                  const SizedBox(width: 4),
                  _UrgentDot(color: c.ok),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentDot extends StatefulWidget {
  final Color color;
  const _UrgentDot({required this.color});

  @override
  State<_UrgentDot> createState() => _UrgentDotState();
}

class _UrgentDotState extends State<_UrgentDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.3).animate(_ctrl),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
