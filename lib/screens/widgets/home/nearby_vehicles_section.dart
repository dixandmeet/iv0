import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/home_aggregator.dart';
import '../../../services/map_service.dart';
import '../../../theme/flow_theme.dart';
import '../../../widgets/flow_primitives.dart';
import '../../../widgets/flow_widgets.dart';
import '../../../widgets/home/home_section_header.dart';
import '../vehicle_details_bottom_sheet.dart';

class NearbyVehiclesSection extends StatelessWidget {
  final List<NearbyVehicleInfo> vehicles;

  const NearbyVehiclesSection({super.key, required this.vehicles});

  @override
  Widget build(BuildContext context) {
    final mapHelper = Provider.of<MapService>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(emoji: '🚌', title: 'Véhicules autour de vous'),
        if (vehicles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucun véhicule détecté à proximité',
              style: TextStyle(color: FlowColors.g2, fontSize: 14),
            ),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final info = vehicles[index];
                return _VehicleCard(
                  info: info,
                  mapHelper: mapHelper,
                  onTap: () {
                    showFlowSheet(
                      context,
                      builder: (_) => VehicleDetailsBottomSheet(
                        vehicle: info.vehicle,
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final NearbyVehicleInfo info;
  final MapService mapHelper;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.info,
    required this.mapHelper,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = info.vehicle;
    final lineColor = mapHelper.getTransportColor(
      v.transportType,
    );
    final distance = info.distanceMeters < 1000
        ? '${info.distanceMeters.round()} m'
        : '${(info.distanceMeters / 1000).toStringAsFixed(1)} km';

    return FlowTappable(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlowColors.white,
          borderRadius: BorderRadius.circular(FlowTokens.rCardXl),
          boxShadow: FlowTokens.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LineBadge(
                  code: v.routeId,
                  transportType: v.transportType,
                  background: lineColor,
                ),
                const Spacer(),
                Icon(
                  mapHelper.getTransportIcon(v.transportType),
                  size: 18,
                  color: FlowColors.g2,
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Direction ${info.directionLabel}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FlowColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  distance,
                  style: FlowText.rowSub,
                ),
                const Text(' · ', style: FlowText.rowSub),
                Text(
                  info.etaMinutes <= 1 ? 'Arrive' : '${info.etaMinutes} min',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: flowWaitColor(info.etaMinutes),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
