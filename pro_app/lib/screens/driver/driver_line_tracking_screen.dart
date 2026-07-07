import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/gtfs.dart';
import '../../services/driver/driver_service.dart';
import '../../services/gtfs_service.dart';
import '../../widgets/driver/delay_badge.dart';
import '../../widgets/driver/driver_position_map.dart';
import '../../widgets/driver/stop_strip.dart';
import 'driver_report_screen.dart';

/// Suivi de ligne : ligne, direction, prochain/suivant arrêt, frise des arrêts,
/// avance/retard et signalement d'incident.
class DriverLineTrackingScreen extends StatefulWidget {
  const DriverLineTrackingScreen({super.key});

  @override
  State<DriverLineTrackingScreen> createState() =>
      _DriverLineTrackingScreenState();
}

class _DriverLineTrackingScreenState extends State<DriverLineTrackingScreen> {
  List<GtfsStop> _stops = [];
  String? _loadedForKey; // lineId|headsign déjà chargé
  bool _loading = false;

  Future<void> _loadStopsIfNeeded(DriverService driverService) async {
    final service = driverService.currentService;
    if (service?.lineId == null) return;
    final key = '${service!.lineId}|${service.headsign}';
    if (key == _loadedForKey || _loading) return;
    _loading = true;

    final gtfs = context.read<GtfsService>();
    await gtfs.fetchRoutes();
    await gtfs.fetchStops();
    final route = gtfs.cachedRoutes
        .cast<GtfsRoute?>()
        .firstWhere((r) => r?.routeId == service.lineId, orElse: () => null);

    var stops = <GtfsStop>[];
    if (route != null && service.headsign != null) {
      stops = gtfs.stopsToward(route, service.headsign!);
    }

    if (!mounted) return;
    setState(() {
      _stops = stops;
      _loadedForKey = key;
      _loading = false;
    });
  }

  int _currentStopIndex(Position? pos) {
    if (pos == null || _stops.isEmpty) return 0;
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < _stops.length; i++) {
      final d = Geolocator.distanceBetween(pos.latitude, pos.longitude,
          _stops[i].position.latitude, _stops[i].position.longitude);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final driverService = context.watch<DriverService>();
    final service = driverService.currentService;
    final theme = Theme.of(context);

    if (service == null || !service.isRunning) {
      return _EmptyTracking(theme: theme);
    }

    // Charge la frise dès qu'un service actif est disponible.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadStopsIfNeeded(driverService));

    final currentIndex = _currentStopIndex(driverService.lastPosition);
    final nextStop =
        _stops.isNotEmpty ? _stops[currentIndex].stopName : 'Arrêt inconnu';
    final followingStop = (_stops.length > currentIndex + 1)
        ? _stops[currentIndex + 1].stopName
        : '—';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // Ligne + direction
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.busFront,
                  color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.lineLabel,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(service.directionLabel,
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ma position en temps réel
        DriverPositionMap(
          userPosition: driverService.lastPosition == null
              ? null
              : LatLng(driverService.lastPosition!.latitude,
                  driverService.lastPosition!.longitude),
          stops: _stops,
          currentStopIndex: currentIndex,
        ),
        const SizedBox(height: 20),

        // Avance / retard
        Text('Régularité',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Flexible(
              child: DelayBadge(
                minutes: driverService.delayMinutes,
                large: true,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => driverService.adjustDelay(-1),
              icon: const Icon(LucideIcons.minus),
              tooltip: 'Avance',
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => driverService.adjustDelay(1),
              icon: const Icon(LucideIcons.plus),
              tooltip: 'Retard',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Prochain / suivant
        Row(
          children: [
            Expanded(
              child: _StopCard(
                badge: 'Prochain arrêt',
                name: nextStop,
                highlight: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StopCard(
                badge: 'Arrêt suivant',
                name: followingStop,
                highlight: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Frise des arrêts
        Text('Itinéraire',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StopStrip(stops: _stops, currentIndex: currentIndex),
        const SizedBox(height: 28),

        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DriverReportScreen()),
          ),
          icon: const Icon(LucideIcons.triangleAlert),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Signaler un incident', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class _StopCard extends StatelessWidget {
  final String badge;
  final String name;
  final bool highlight;
  const _StopCard(
      {required this.badge, required this.name, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        highlight ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.mapPin, size: 14, color: color),
              const SizedBox(width: 6),
              Text(badge,
                  style: theme.textTheme.labelMedium?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyTracking extends StatelessWidget {
  final ThemeData theme;
  const _EmptyTracking({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.navigationOff,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Aucun service en cours',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Démarrez un service depuis l\'accueil pour suivre votre ligne en temps réel.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
