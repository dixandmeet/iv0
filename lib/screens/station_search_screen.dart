import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/aule_data_adapter.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/aule_theme.dart';
import 'line_schedule_page.dart';
import 'stop_detail_page.dart';

/// Recherche du réseau Naolib : arrêts ET lignes. Sans saisie, propose les
/// stations à proximité ; un tap ouvre les horaires de l'arrêt, ou la fiche
/// horaire de la ligne.
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
      MaterialPageRoute<void>(
        builder: (_) => StopDetailPage(
          station: station,
          showDistance: hasDistance,
        ),
      ),
    );
  }

  void _openLineSchedule(GtfsRoute route) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LineSchedulePage(route: route),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;

    final gtfs = Provider.of<GtfsService>(context);
    final location = Provider.of<LocationService>(context);
    final pos = location.currentPosition;
    final LatLng? userPos =
        pos != null ? LatLng(pos.latitude, pos.longitude) : null;
    final query = _controller.text.trim();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
              child: Row(
                children: [
                  _IconButton(
                    icon: LucideIcons.arrowLeft,
                    colors: c,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _searchField(c)),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: c.line),
            Expanded(
              child: gtfs.cachedStops.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AuleTokens.rCardSm),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text('Chargement du réseau Naolib…',
                            style: _subStyle(c)),
                      ),
                    )
                  : query.isEmpty
                      ? _nearbyList(gtfs, userPos, c)
                      : _resultsList(gtfs, userPos, query, c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(AuleColors c) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AuleTokens.rSearch),
        border: Border.all(color: c.brand, width: 2),
        boxShadow: [
          BoxShadow(
            color: c.brand.withValues(alpha: 0.18),
            blurRadius: 0,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, color: c.brand, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              cursorColor: c.brand,
              style: _titleStyle(c),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Arrêt ou ligne…',
                hintStyle: hankenGrotesk(
                  color: c.faint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _controller.clear,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.x, color: c.muted, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  /// Suggestions sans saisie : stations les plus proches de l'utilisateur
  /// (ou du centre de Nantes si le GPS est indisponible).
  Widget _nearbyList(GtfsService gtfs, LatLng? userPos, AuleColors c) {
    final stations =
        gtfs.nearbyStations(userPos ?? _nantesCenter, limit: 6, maxMeters: 2500);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _SectionLabel(
          userPos == null
              ? 'Autour du centre de Nantes'
              : 'Stations à proximité',
          colors: c,
        ),
        const SizedBox(height: 4),
        if (stations.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Aucune station à proximité.', style: _subStyle(c)),
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

  Widget _resultsList(
      GtfsService gtfs, LatLng? userPos, String query, AuleColors c) {
    final lines = gtfs.searchRoutes(query);
    final stations = gtfs.searchStations(query, from: userPos);

    if (lines.isEmpty && stations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text('Aucun résultat pour « $query ».', style: _subStyle(c)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (lines.isNotEmpty) ...[
          _SectionLabel('Lignes', colors: c),
          const SizedBox(height: 4),
          ...lines.map((r) => _LineRow(
                route: r,
                colors: c,
                onTap: () => _openLineSchedule(r),
              )),
          const SizedBox(height: 12),
        ],
        if (stations.isNotEmpty) ...[
          _SectionLabel('Arrêts', colors: c),
          const SizedBox(height: 4),
          ...stations.map((station) => _StationRow(
                station: station,
                showDistance: userPos != null,
                onTap: () =>
                    _openSchedule(station, hasDistance: userPos != null),
              )),
        ],
      ],
    );
  }
}

/// Ligne de résultat « ligne » : badge coloré + terminus.
class _LineRow extends StatelessWidget {
  final GtfsRoute route;
  final AuleColors colors;
  final VoidCallback onTap;

  const _LineRow({
    required this.route,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final color = AuleDataAdapter.routeColor(route) ?? const Color(0xFF6B7280);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 40),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AuleDataAdapter.lineCode(route),
                style: hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AuleDataAdapter.modeLabel(route.transportType),
                    style: hankenGrotesk(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    AuleDataAdapter.terminusLabel(route),
                    style: _titleStyle(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: c.faint),
          ],
        ),
      ),
    );
  }
}

// --- Styles & primitives Aule locaux ---------------------------------------

TextStyle _titleStyle(AuleColors c) => hankenGrotesk(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: c.text,
    );

TextStyle _subStyle(AuleColors c) => hankenGrotesk(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: c.muted,
    );

/// Bouton-icône carré arrondi (équivalent Aule de l'ancien FlowIconButton).
class _IconButton extends StatelessWidget {
  final IconData icon;
  final AuleColors colors;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.line),
        ),
        child: Icon(icon, size: 20, color: colors.text),
      ),
    );
  }
}

/// Petit label de section en capitales.
class _SectionLabel extends StatelessWidget {
  final String text;
  final AuleColors colors;
  const _SectionLabel(this.text, {required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: hankenGrotesk(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        height: 1.1,
        color: colors.faint,
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.brandWeak,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.mapPin, size: 20, color: c.brand),
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
                          style: _titleStyle(c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (station.stop.isWheelchairAccessible) ...[
                        const SizedBox(width: 6),
                        Icon(LucideIcons.accessibility, size: 14, color: c.ok),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _sub,
                    style: _subStyle(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: c.faint),
          ],
        ),
      ),
    );
  }
}
