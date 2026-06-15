import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/home_aggregator.dart';
import '../../../services/map_service.dart';
import '../../../theme/flow_theme.dart';
import '../../../widgets/flow_widgets.dart';
import '../../../widgets/home/home_section_header.dart';

class ImminentDeparturesSection extends StatelessWidget {
  final List<ImminentDeparture> departures;

  const ImminentDeparturesSection({super.key, required this.departures});

  @override
  Widget build(BuildContext context) {
    if (departures.isEmpty) return const SizedBox.shrink();

    final mapHelper = Provider.of<MapService>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(emoji: '🚋', title: 'Prochains départs'),
        ...departures.map((dep) {
          final lineColor = mapHelper.getTransportColor(
            dep.route.transportType,
            routeColorHex: dep.route.routeColor,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  color: FlowColors.white,
                  borderRadius: BorderRadius.circular(FlowTokens.rCardXl),
                  boxShadow: FlowTokens.soft,
                ),
                child: Row(
                  children: [
                    LineBadge(
                      code: dep.route.routeShortName ?? dep.route.routeId,
                      transportType: dep.route.transportType,
                      background: lineColor,
                      large: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dep.headsign,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: FlowColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dep.stationName,
                            style: FlowText.rowSub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _LargeWaitTime(waitMinutes: dep.waitMinutes),
                  ],
                ),
              ),
          );
        }),
      ],
    );
  }
}

class _LargeWaitTime extends StatelessWidget {
  final int waitMinutes;
  const _LargeWaitTime({required this.waitMinutes});

  @override
  Widget build(BuildContext context) {
    if (waitMinutes <= 1) {
      return Text(
        'Arrive',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: flowWaitColor(waitMinutes),
        ),
      );
    }
    return Text(
      '$waitMinutes min',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: flowWaitColor(waitMinutes),
      ),
    );
  }
}
