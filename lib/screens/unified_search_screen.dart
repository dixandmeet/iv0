import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/flow_theme.dart';
import '../widgets/flow_primitives.dart';
import '../widgets/flow_widgets.dart';
import 'search_route_screen.dart';
import 'stop_detail_page.dart';

/// Recherche unifiée : arrêts, lignes, itinéraire (adresses/POI en stub).
class UnifiedSearchScreen extends StatefulWidget {
  const UnifiedSearchScreen({super.key});

  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  LatLng? _userPosition(BuildContext context) {
    final pos = Provider.of<LocationService>(context, listen: false)
        .currentPosition;
    return pos != null ? LatLng(pos.latitude, pos.longitude) : null;
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final gtfs = Provider.of<GtfsService>(context, listen: false);
    final from = _userPosition(context);

    final stops = query.isEmpty
        ? <NearbyStation>[]
        : gtfs.searchStations(query, from: from, limit: 8);
    final routes = query.isEmpty ? <GtfsRoute>[] : gtfs.searchRoutes(query, limit: 8);

    return Scaffold(
      backgroundColor: FlowColors.white,
      appBar: AppBar(
        backgroundColor: FlowColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: FlowColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Recherche', style: FlowText.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: FlowColors.fill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FlowColors.line),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.search, size: 20, color: FlowColors.g2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      decoration: const InputDecoration(
                        hintText: 'Où allez-vous ?',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (query.isEmpty) ...[
                  _RouteLink(
                    onTap: () {
                      Navigator.push(
                        context,
                        FlowPageRoute(page: const SearchRouteScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel('Bientôt disponible'),
                  const SizedBox(height: 8),
                  const _StubRow(
                    icon: LucideIcons.mapPin,
                    title: 'Adresses',
                    sub: 'Géocodage à venir',
                  ),
                  const _StubRow(
                    icon: LucideIcons.landmark,
                    title: 'Points d\'intérêt',
                    sub: 'Recherche POI à venir',
                  ),
                ] else ...[
                  if (stops.isNotEmpty) ...[
                    const SectionLabel('Arrêts'),
                    const SizedBox(height: 6),
                    ...stops.map((s) => _ResultRow(
                          icon: LucideIcons.mapPin,
                          iconBg: FlowColors.blueSoft,
                          iconColor: FlowColors.blue,
                          title: s.stop.stopName,
                          sub: s.distanceMeters > 0
                              ? '${s.distanceMeters.round()} m'
                              : 'Arrêt Naolib',
                          onTap: () {
                            Navigator.push(
                              context,
                              FlowPageRoute(
                                page: StopDetailPage(
                                  station: s,
                                  showDistance: from != null,
                                ),
                              ),
                            );
                          },
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (routes.isNotEmpty) ...[
                    const SectionLabel('Lignes'),
                    const SizedBox(height: 6),
                    ...routes.map((r) => _ResultRow(
                          icon: LucideIcons.route,
                          iconBg: FlowColors.fill,
                          iconColor: FlowColors.ink,
                          title: 'Ligne ${r.routeShortName ?? r.routeId}',
                          sub: r.routeLongName ?? r.transportType,
                          onTap: () {},
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (stops.isEmpty && routes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          'Aucun résultat',
                          style: TextStyle(color: FlowColors.g2),
                        ),
                      ),
                    ),
                  const Divider(height: 24),
                  _RouteLink(
                    onTap: () {
                      Navigator.push(
                        context,
                        FlowPageRoute(page: const SearchRouteScreen()),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLink extends StatelessWidget {
  final VoidCallback onTap;
  const _RouteLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlowColors.blueSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.route, color: FlowColors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Calculer un itinéraire A → B',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: FlowColors.blue,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, color: FlowColors.blue, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StubRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _StubRow({
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconTile(icon: icon, background: FlowColors.fill, iconColor: FlowColors.gWeak),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FlowText.rowTitle),
                Text(sub, style: FlowText.rowSub),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _ResultRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconTile(icon: icon, background: iconBg, iconColor: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FlowText.rowTitle),
                  Text(sub, style: FlowText.rowSub),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
