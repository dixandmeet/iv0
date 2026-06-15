import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/community_vehicle.dart';
import '../../services/map_service.dart';
import '../../theme/flow_theme.dart';
import '../../widgets/flow_primitives.dart';
import '../../widgets/flow_widgets.dart';
import 'report_incident_bottom_sheet.dart';

class VehicleDetailsBottomSheet extends StatelessWidget {
  final CommunityVehicle vehicle;

  /// Démarre le suivi du véhicule sur la carte (bouton « Suivre ce bus »).
  final VoidCallback? onFollow;

  const VehicleDetailsBottomSheet({super.key, required this.vehicle, this.onFollow});

  @override
  Widget build(BuildContext context) {
    final mapHelper = Provider.of<MapService>(context, listen: false);
    final status = vehicleStatus(vehicle);
    final crowd = vehicleCrowd(vehicle);
    final reliabilityColor = mapHelper.getReliabilityColor(vehicle.reliabilityLevel);
    final reliabilityValueColor = vehicle.confidenceScore >= 80
        ? FlowColors.green
        : vehicle.confidenceScore >= 50
            ? FlowColors.orange
            : FlowColors.gWeak;

    return FlowSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Entête
          Row(
            children: [
              LineBadge(code: vehicle.routeId, transportType: vehicle.transportType, large: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${mapHelper.getTransportLabel(vehicle.transportType)} · Ligne ${vehicle.routeId}',
                        style: FlowText.h3),
                    const SizedBox(height: 2),
                    Text(
                      vehicle.dataSource != null
                          ? '${vehicle.dataSourceLabel} · ${vehicle.activeUserCount > 1 ? '${vehicle.activeUserCount} co-voyageurs' : 'position certifiée'}'
                          : '${vehicle.activeUserCount} co-voyageur(s) · temps réel',
                      style: FlowText.rowSub,
                    ),
                  ],
                ),
              ),
              const SoftBadge(
                text: 'En direct',
                color: FlowColors.green,
                background: FlowColors.greenSoft,
                dot: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 stat tiles
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Affluence',
                  value: crowdLabel(crowd),
                  valueColor: crowd == CrowdLevel.high
                      ? FlowColors.red
                      : crowd == CrowdLevel.mid
                          ? FlowColors.orange
                          : FlowColors.green,
                  sub: 'à bord',
                  leading: CrowdBars(level: crowd),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: 'Fiabilité',
                  value: '${vehicle.confidenceScore}%',
                  valueColor: reliabilityValueColor,
                  sub: vehicle.dataSource != null
                      ? '${vehicle.reliabilityLevel.toUpperCase()} · ${vehicle.dataSourceLabel}'
                      : vehicle.reliabilityLevel.toUpperCase(),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: StatTile(
                  label: 'Statut',
                  value: status.text,
                  valueColor: status.color,
                  sub: 'vs théorique',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Encart source de la position
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlowColors.fill,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Icon(
                  vehicle.dataSource == 'driver'
                      ? LucideIcons.badgeCheck
                      : LucideIcons.users,
                  size: 20,
                  color: reliabilityColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _sourceDescription(vehicle),
                    style: FlowText.rowSub,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Boutons
          Row(
            children: [
              Expanded(
                child: FlowButton(
                  label: 'Suivre ce bus',
                  icon: LucideIcons.navigation,
                  onPressed: () {
                    Navigator.pop(context);
                    if (onFollow != null) {
                      onFollow!();
                    } else {
                      showFlowToast(context, 'Suivi de la ligne ${vehicle.routeId} activé',
                          icon: LucideIcons.navigation);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              FlowIconButton(
                icon: LucideIcons.bell,
                size: 48,
                iconSize: 21,
                onTap: () {
                  final rootContext = Navigator.of(context, rootNavigator: true).context;
                  Navigator.pop(context);
                  showFlowSheet(
                    rootContext,
                    builder: (_) => ReportIncidentBottomSheet(
                      preselectedRouteId: vehicle.routeId,
                      preselectedVehicleId: vehicle.id,
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

String _sourceDescription(CommunityVehicle vehicle) {
  final freshness = vehicle.freshnessSeconds;
  final ageLabel = freshness != null && freshness < 60
      ? 'il y a ${freshness}s'
      : 'mise à jour en continu';

  switch (vehicle.dataSource) {
    case 'driver':
      return 'Position certifiée remontée par le conducteur ($ageLabel).';
    case 'operator':
      return 'Position opérateur Naolib ($ageLabel).';
    case 'community':
      return 'Position consolidée par la communauté ($ageLabel), 100 % anonyme.';
    default:
      return 'Position temps réel ($ageLabel).';
  }
}
