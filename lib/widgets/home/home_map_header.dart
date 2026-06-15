import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/aule_theme.dart';
import '../../theme/flow_theme.dart';
import '../aule/aule_map_tiles.dart';

/// Carte discrète en arrière-plan du header Accueil (~28 % de l'écran).
class HomeMapHeader extends StatelessWidget {
  final LatLng center;

  const HomeMapHeader({super.key, required this.center});

  @override
  Widget build(BuildContext context) {
    const c = AuleColors.light;
    final height = MediaQuery.sizeOf(context).height * 0.28;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0, 0, 0, 0.35, 0,
            ]),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                AuleMapTiles.layer(context, c),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height * 0.55,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    FlowColors.white,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: FlowColors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: FlowColors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: FlowColors.blue.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
