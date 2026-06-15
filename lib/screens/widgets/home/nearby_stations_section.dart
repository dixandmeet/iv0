import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../models/track_request.dart';
import '../../../services/gtfs_service.dart';
import '../../../services/map_service.dart';
import '../../../theme/flow_theme.dart';
import '../../../widgets/flow_primitives.dart';
import '../../../widgets/home/home_section_header.dart';
import '../../../widgets/nearby_station_card.dart';
import '../../stop_detail_page.dart';

typedef TrackLineCallback = void Function(TrackRequest request);

class NearbyStationsSection extends StatelessWidget {
  final List<NearbyStation> stations;
  final List<List<StationLineGroup>> groupsPerStation;
  final Map<int, StationBadge> badges;
  final LatLng? userPosition;
  final TrackLineCallback? onTrackLine;

  const NearbyStationsSection({
    super.key,
    required this.stations,
    required this.groupsPerStation,
    required this.badges,
    this.userPosition,
    this.onTrackLine,
  });

  @override
  Widget build(BuildContext context) {
    final mapHelper = Provider.of<MapService>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(emoji: '📍', title: 'Arrêts autour de vous'),
        if (stations.isEmpty)
          const _EmptyHint(
            text:
                'Aucun arrêt à proximité. Activez le GPS ou rapprochez-vous du réseau.',
          )
        else
          ...List.generate(stations.length, (i) {
            final station = stations[i];
            final groups = i < groupsPerStation.length
                ? groupsPerStation[i]
                : <StationLineGroup>[];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NearbyStationCard(
                station: station,
                groups: groups,
                mapHelper: mapHelper,
                badge: badges[i],
                showDistance: userPosition != null,
                onTap: () {
                  Navigator.push(
                    context,
                    FlowPageRoute(
                      page: StopDetailPage(
                        station: station,
                        showDistance: userPosition != null,
                      ),
                    ),
                  );
                },
                onDirectionTap: onTrackLine == null
                    ? null
                    : (route, st, departure) {
                        onTrackLine!(TrackRequest(
                          route: route,
                          station: st,
                          departure: departure,
                        ));
                      },
              ),
            );
          }),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: FlowColors.g2, fontSize: 14),
      ),
    );
  }
}
