import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/gtfs.dart';
import '../services/gtfs_service.dart';
import '../theme/flow_theme.dart';
import 'flow_widgets.dart';

/// Plan de ligne affiché dans le bottom sheet pendant le suivi d'un
/// véhicule : arrêts restants dans le sens de circulation, position du
/// véhicule en tête, arrêt de l'utilisateur mis en évidence, ETA par arrêt.
class LinePlanSheet extends StatelessWidget {
  final GtfsRoute route;
  final String headsign;
  final NearbyStation station;
  final int waitSeconds;
  final Color lineColor;
  final GtfsService gtfs;
  final ScrollController scrollController;

  const LinePlanSheet({
    super.key,
    required this.route,
    required this.headsign,
    required this.station,
    required this.waitSeconds,
    required this.lineColor,
    required this.gtfs,
    required this.scrollController,
  });

  static const Distance _distance = Distance();

  @override
  Widget build(BuildContext context) {
    final stops = gtfs.stopsToward(route, headsign);
    final targetIndex =
        stops.indexWhere((s) => s.stopName == station.stop.stopName);
    final aheadIndex = targetIndex >= 0
        ? gtfs.firstStopAheadIndex(
            stops, targetIndex, route.transportType, waitSeconds.toDouble())
        : 0;
    final remaining = stops.sublist(aheadIndex);
    final targetInRemaining = targetIndex >= 0 ? targetIndex - aheadIndex : -1;
    final etas = _etaSeconds(remaining, targetInRemaining);

    return Container(
      decoration: const BoxDecoration(
        color: FlowColors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(FlowTokens.rSheet)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F1A1916),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const SheetHandle(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FlowTokens.margin),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionLabel('Plan de ligne'),
                Text(
                  remaining.length > 1
                      ? '${remaining.length} arrêts restants'
                      : '${remaining.length} arrêt restant',
                  style: FlowText.kicker.copyWith(color: FlowColors.gWeak),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FlowTokens.margin),
            child: Row(
              children: [
                LineBadge(
                  code: route.routeShortName ?? route.routeId,
                  transportType: route.transportType,
                  background: lineColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '→ $headsign',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: FlowColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: remaining.isEmpty
                ? ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        FlowTokens.margin, 8, FlowTokens.margin, 24),
                    children: const [
                      Text('Plan de ligne indisponible pour cette ligne.',
                          style: FlowText.rowSub),
                    ],
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        FlowTokens.margin, 0, FlowTokens.margin, 24),
                    itemCount: remaining.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return _vehicleRow();
                      final stopIndex = i - 1;
                      return _StopRow(
                        stop: remaining[stopIndex],
                        lineColor: lineColor,
                        isTarget: stopIndex == targetInRemaining,
                        isLast: stopIndex == remaining.length - 1,
                        etaSeconds: etas?[stopIndex],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// ETA (secondes) de chaque arrêt restant, calé sur l'ETA connu de l'arrêt
  /// cible : on ajoute/retire le temps de parcours entre arrêts (distance à
  /// vol d'oiseau × détour 1.35 / vitesse commerciale du mode).
  List<int>? _etaSeconds(List<GtfsStop> remaining, int targetInRemaining) {
    if (targetInRemaining < 0 || remaining.isEmpty) return null;
    final speed = GtfsService.avgSpeedMps(route.transportType);

    double legSeconds(int from, int to) =>
        _distance.as(LengthUnit.Meter, remaining[from].position,
            remaining[to].position) *
        1.35 /
        speed;

    final etas = List<double>.filled(remaining.length, 0);
    etas[targetInRemaining] = waitSeconds.toDouble();
    for (var i = targetInRemaining - 1; i >= 0; i--) {
      etas[i] = etas[i + 1] - legSeconds(i, i + 1);
    }
    for (var i = targetInRemaining + 1; i < remaining.length; i++) {
      etas[i] = etas[i - 1] + legSeconds(i - 1, i);
    }
    return [for (final e in etas) e < 0 ? 0 : e.round()];
  }

  /// Tête du plan : position actuelle du véhicule.
  Widget _vehicleRow() {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Expanded(child: Container()),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: lineColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: lineColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(flowModeIcon(route.transportType),
                      size: 14, color: Colors.white),
                ),
                Expanded(
                  child: Container(
                    width: 3,
                    color: lineColor.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Véhicule',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: FlowColors.ink,
              ),
            ),
          ),
          const Text(
            'en approche',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: FlowColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne du plan : segment de timeline + nom de l'arrêt + ETA.
class _StopRow extends StatelessWidget {
  final GtfsStop stop;
  final Color lineColor;
  final bool isTarget;
  final bool isLast;
  final int? etaSeconds;

  const _StopRow({
    required this.stop,
    required this.lineColor,
    required this.isTarget,
    required this.isLast,
    this.etaSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final faded = lineColor.withValues(alpha: 0.25);
    final double dotSize = isTarget ? 16 : 10;

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    Expanded(child: Container(width: 3, color: faded)),
                    Expanded(
                      child: Container(
                        width: 3,
                        color: isLast ? Colors.transparent : faded,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: isTarget ? lineColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: lineColor,
                      width: isTarget ? 3 : 2.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.stopName,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isTarget || isLast
                        ? FontWeight.w800
                        : FontWeight.w600,
                    letterSpacing: -0.2,
                    color: FlowColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isTarget || isLast)
                  Text(
                    isTarget ? 'Votre arrêt' : 'Terminus',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isTarget ? FlowColors.blue : FlowColors.gWeak,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (etaSeconds != null)
            etaSeconds! <= 60
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.circleDot,
                          size: 12, color: FlowColors.green),
                      SizedBox(width: 4),
                      Text(
                        'Arrive',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: FlowColors.green,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '${(etaSeconds! / 60).ceil()} min',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: isTarget
                          ? flowWaitColor((etaSeconds! / 60).ceil())
                          : FlowColors.g2,
                    ),
                  ),
        ],
      ),
    );
  }
}
