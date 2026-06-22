import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../theme/app_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/aule_models.dart';
import '../../theme/aule_theme.dart';
import '../../utils/aule_eta.dart';
import 'aule_map_tiles.dart';
import 'line_badge.dart';

/// En-tête carte radar — cartographie réelle + véhicules géolocalisés.
class RadarMapHeader extends StatelessWidget {
  final LatLng center;
  final List<AuleVehicleData> vehicles;
  final DateTime now;

  const RadarMapHeader({
    super.key,
    required this.center,
    required this.vehicles,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    final topPad = MediaQuery.paddingOf(context).top;

    final markers = <Marker>[
      Marker(
        point: center,
        width: 24,
        height: 24,
        alignment: Alignment.center,
        child: const _UserDot(),
      ),
      for (final v in vehicles)
        if (v.position != null)
          Marker(
            point: v.position!,
            width: 52,
            height: 56,
            alignment: Alignment.center,
            child: _VehicleMarker(vehicle: v, now: now),
          ),
    ];

    return SizedBox(
      height: AuleTokens.mapHeaderHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: FlutterMap(
              key: ValueKey(
                  '${center.latitude.toStringAsFixed(4)}_${center.longitude.toStringAsFixed(4)}'),
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15.2,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                AuleMapTiles.layer(context, c),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: AuleTokens.mapHeaderHeight * 0.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    c.bg.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 8,
            left: 18,
            right: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(11, 8, 13, 8),
                  decoration: BoxDecoration(
                    color: c.chip,
                    border: Border.all(color: c.chipLine),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: c.shadow,
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                        spreadRadius: -12,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const _RadarPulse(),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Véhicules autour de vous',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: c.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${vehicles.length} détectés',
                        style: hankenGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: c.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleMarker extends StatelessWidget {
  final AuleVehicleData vehicle;
  final DateTime now;

  const _VehicleMarker({required this.vehicle, required this.now});

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    final fmt = formatAuleEta(auleEtaSeconds(vehicle.arrivalAt, now));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LineBadge(
          label: vehicle.label,
          mode: vehicle.mode,
          color: vehicle.lineColor,
          size: 34,
          fontSize: 13,
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: c.chip,
            border: Border.all(color: c.chipLine),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            fmt.text,
            style: hankenGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: c.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _UserDot extends StatefulWidget {
  const _UserDot();

  @override
  State<_UserDot> createState() => _UserDotState();
}

class _UserDotState extends State<_UserDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 3.4).animate(
              CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
            ),
            child: FadeTransition(
              opacity: Tween(begin: 0.18, end: 0.0).animate(_ctrl),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c.brand,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: c.brand,
              shape: BoxShape.circle,
              border: Border.all(color: c.surface, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPulse extends StatefulWidget {
  const _RadarPulse();

  @override
  State<_RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<_RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    return SizedBox(
      width: 10,
      height: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 3.4).animate(
              CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
            ),
            child: FadeTransition(
              opacity: Tween(begin: 0.5, end: 0.0).animate(_ctrl),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: c.brand,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: c.brand,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
