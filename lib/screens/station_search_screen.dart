import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/flow_theme.dart';
import '../widgets/flow_primitives.dart';
import '../widgets/flow_widgets.dart';
import 'stop_detail_page.dart';

/// Recherche d'une station du réseau Naolib par son nom. Sans saisie,
/// propose les stations à proximité ; un tap ouvre les horaires.
class StationSearchScreen extends StatefulWidget {
  const StationSearchScreen({super.key});

  @override
  State<StationSearchScreen> createState() => _StationSearchScreenState();
}

class _StationSearchScreenState extends State<StationSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  // Centre par défaut (Place du Commerce) si le GPS est indisponible.
  static const LatLng _nantesCenter = LatLng(47.218371, -1.553621);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openSchedule(NearbyStation station, {required bool hasDistance}) {
    Navigator.push(
      context,
      FlowPageRoute(
        page: StopDetailPage(
          station: station,
          showDistance: hasDistance,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gtfs = Provider.of<GtfsService>(context);
    final location = Provider.of<LocationService>(context);
    final pos = location.currentPosition;
    final LatLng? userPos =
        pos != null ? LatLng(pos.latitude, pos.longitude) : null;
    final query = _controller.text.trim();

    return Scaffold(
      backgroundColor: FlowColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
              child: Row(
                children: [
                  FlowIconButton(
                      icon: LucideIcons.arrowLeft,
                      onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(child: _searchField()),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: gtfs.cachedStops.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(FlowTokens.margin),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text('Chargement du réseau Naolib…',
                            style: FlowText.rowSub),
                      ),
                    )
                  : query.isEmpty
                      ? _nearbyList(gtfs, userPos)
                      : _resultsList(gtfs, userPos, query),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: FlowColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlowColors.blue, width: 2),
        boxShadow: [
          BoxShadow(
            color: FlowColors.blue.withValues(alpha: 0.18),
            blurRadius: 0,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, color: FlowColors.blue, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: FlowTextField(
              controller: _controller,
              autofocus: true,
              hintText: 'Rechercher une station…',
            ),
          ),
          if (_controller.text.isNotEmpty)
            FlowTappable(
              onTap: _controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(LucideIcons.x, color: FlowColors.g2, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  /// Suggestions sans saisie : stations les plus proches de l'utilisateur
  /// (ou du centre de Nantes si le GPS est indisponible).
  Widget _nearbyList(GtfsService gtfs, LatLng? userPos) {
    final stations =
        gtfs.nearbyStations(userPos ?? _nantesCenter, limit: 6, maxMeters: 2500);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          FlowTokens.margin, 14, FlowTokens.margin, 24),
      children: [
        SectionLabel(userPos == null
            ? 'Autour du centre de Nantes'
            : 'Stations à proximité'),
        const SizedBox(height: 4),
        if (stations.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child:
                Text('Aucune station à proximité.', style: FlowText.rowSub),
          )
        else
          ...stations.map((s) => _StationRow(
                station: s,
                showDistance: true,
                onTap: () => _openSchedule(s, hasDistance: userPos != null),
              )),
      ],
    );
  }

  Widget _resultsList(GtfsService gtfs, LatLng? userPos, String query) {
    final results = gtfs.searchStations(query, from: userPos);
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(FlowTokens.margin),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text('Aucune station trouvée pour « $query ».',
              style: FlowText.rowSub),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          FlowTokens.margin, 8, FlowTokens.margin, 24),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final station = results[i];
        return _StationRow(
          station: station,
          showDistance: userPos != null,
          onTap: () => _openSchedule(station, hasDistance: userPos != null),
        );
      },
    );
  }
}

/// Ligne de résultat : nom de la station, distance éventuelle et codes des
/// lignes qui la desservent.
class _StationRow extends StatelessWidget {
  final NearbyStation station;
  final bool showDistance;
  final VoidCallback onTap;

  const _StationRow({
    required this.station,
    required this.showDistance,
    required this.onTap,
  });

  String get _sub {
    final codes = station.routes
        .map((r) => r.routeShortName ?? r.routeId)
        .take(6)
        .join(' · ');
    final more = station.routes.length > 6
        ? ' +${station.routes.length - 6}'
        : '';
    if (!showDistance) return '$codes$more';
    final meters = station.distanceMeters;
    final distance = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
    return '$distance · $codes$more';
  }

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      pressedScale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            const IconTile(
              icon: LucideIcons.mapPin,
              background: FlowColors.blueSoft,
              iconColor: FlowColors.blue,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          station.stop.stopName,
                          style: FlowText.rowTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (station.stop.isWheelchairAccessible) ...[
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.accessibility,
                            size: 14, color: FlowColors.green),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _sub,
                    style: FlowText.rowSub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight,
                size: 18, color: FlowColors.gWeak),
          ],
        ),
      ),
    );
  }
}
