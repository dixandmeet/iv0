import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/gtfs.dart';
import '../../theme/flow_theme.dart';
import '../../widgets/flow_primitives.dart';
import '../../widgets/flow_widgets.dart';
import 'report_incident_bottom_sheet.dart';

/// Fiche d'informations du véhicule suivi, ouverte d'un tap sur sa capsule :
/// ligne, direction, arrivée estimée, source de la position, et bascule de
/// la vue 3D.
class TrackedVehicleSheet extends StatelessWidget {
  final GtfsRoute route;
  final String headsign;
  final String stationName;
  final int waitSeconds;
  final String sourceLabel;
  final IconData sourceIcon;
  final Color lineColor;
  final bool view3D;
  final VoidCallback onToggle3D;

  const TrackedVehicleSheet({
    super.key,
    required this.route,
    required this.headsign,
    required this.stationName,
    required this.waitSeconds,
    required this.sourceLabel,
    required this.sourceIcon,
    required this.lineColor,
    required this.view3D,
    required this.onToggle3D,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (waitSeconds / 60).ceil();
    final typeLabel = switch (route.transportType) {
      'tram' => 'Tram',
      'busway' => 'Busway',
      'navibus' => 'Navibus',
      _ => 'Bus',
    };

    return FlowSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Entête : ligne et direction.
          Row(
            children: [
              LineBadge(
                code: route.routeShortName ?? route.routeId,
                transportType: route.transportType,
                background: lineColor,
                large: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$typeLabel · Ligne ${route.routeShortName ?? route.routeId}',
                      style: FlowText.h3,
                    ),
                    const SizedBox(height: 2),
                    Text('→ $headsign',
                        style: FlowText.rowSub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              SoftBadge(
                text: minutes <= 1 ? 'Arrive' : '$minutes min',
                color: flowWaitColor(minutes),
                background: FlowColors.fill,
                dot: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Arrivée',
                  value: minutes <= 1 ? '< 1 min' : '$minutes min',
                  valueColor: flowWaitColor(minutes),
                  sub: 'estimée',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: 'Votre arrêt',
                  value: stationName,
                  sub: 'destination du suivi',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Source de la position.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlowColors.fill,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Icon(sourceIcon, size: 20, color: FlowColors.g2),
                const SizedBox(width: 12),
                Expanded(child: Text(sourceLabel, style: FlowText.rowSub)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: FlowButton(
                  label: view3D ? 'Quitter la vue 3D' : 'Suivre en vue 3D',
                  icon: LucideIcons.rotate3d,
                  onPressed: () {
                    Navigator.pop(context);
                    onToggle3D();
                  },
                ),
              ),
              const SizedBox(width: 10),
              FlowIconButton(
                icon: LucideIcons.bell,
                size: 48,
                iconSize: 21,
                onTap: () {
                  final rootContext =
                      Navigator.of(context, rootNavigator: true).context;
                  Navigator.pop(context);
                  showFlowSheet(
                    rootContext,
                    builder: (_) => ReportIncidentBottomSheet(
                      preselectedRouteId:
                          route.routeShortName ?? route.routeId,
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
