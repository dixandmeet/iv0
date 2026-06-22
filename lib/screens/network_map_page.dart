import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../theme/app_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/aule_data_adapter.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/aule/aule_network_map_view.dart';
import 'stop_detail_page.dart';

/// Plan du réseau plein écran : lignes, arrêts et position de l'utilisateur.
class NetworkMapPage extends StatefulWidget {
  const NetworkMapPage({super.key});

  @override
  State<NetworkMapPage> createState() => _NetworkMapPageState();
}

class _NetworkMapPageState extends State<NetworkMapPage> {
  static const _nantesCenter = LatLng(47.2184, -1.5536);

  final MapController _mapController = MapController();
  bool _loading = false;

  /// Modes affichés. `null` (jamais ici) ou ensemble vide => tout est masqué ;
  /// on initialise avec tous les modes présents sur le réseau.
  final Set<AuleLineMode> _activeModes = {...AuleLineMode.values};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gtfs = context.read<GtfsService>();
      if (gtfs.cachedRoutes.isEmpty || gtfs.cachedStops.isEmpty) {
        setState(() => _loading = true);
        if (gtfs.cachedRoutes.isEmpty) await gtfs.fetchRoutes();
        if (gtfs.cachedStops.isEmpty) await gtfs.fetchStops();
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  void _openStop(GtfsStop stop, LatLng? from) {
    final gtfs = context.read<GtfsService>();
    final station = gtfs.nearbyStationFor(stop, from: from);
    if (station == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            StopDetailPage(station: station, showDistance: from != null),
      ),
    );
  }

  /// Modes effectivement présents dans le réseau chargé.
  Set<AuleLineMode> _availableModes(List<GtfsRoute> routes) => {
        for (final r in routes) AuleDataAdapter.modeFrom(r.transportType),
      };

  void _recenter(LatLng? userPos) {
    _mapController.move(userPos ?? _nantesCenter, userPos != null ? 15 : 13.2);
  }

  void _openFilters(List<GtfsRoute> routes, AuleColors c) {
    final available = _availableModes(routes).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AuleTheme(
        colors: c,
        child: StatefulBuilder(
          builder: (ctx, setSheet) => _FilterSheet(
            colors: c,
            available: available,
            active: _activeModes,
            onToggle: (mode) {
              setSheet(() {
                if (_activeModes.contains(mode)) {
                  _activeModes.remove(mode);
                } else {
                  _activeModes.add(mode);
                }
              });
              setState(() {});
            },
            onReset: () {
              setSheet(() => _activeModes
                ..clear()
                ..addAll(available));
              setState(() {});
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;

    final gtfs = context.watch<GtfsService>();
    final location = context.watch<LocationService>();
    final pos = location.currentPosition;
    final userPos = pos != null ? LatLng(pos.latitude, pos.longitude) : null;

    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AuleTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            if (_loading || gtfs.cachedRoutes.isEmpty)
              Center(child: CircularProgressIndicator(color: c.brand))
            else
              Positioned.fill(
                child: AuleNetworkMapView(
                  controller: _mapController,
                  center: userPos ?? _nantesCenter,
                  routes: gtfs.cachedRoutes,
                  stops: gtfs.cachedStops,
                  activeModes: _activeModes,
                  userPosition: userPos,
                  onStopTap: (stop) => _openStop(stop, userPos),
                ),
              ),
            // Bouton retour + titre flottants.
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _CircleButton(
                    icon: LucideIcons.arrowLeft,
                    colors: c,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.line),
                      boxShadow: AuleTokens.cardShadow(c.shadow),
                    ),
                    child: Text(
                      'Plan du réseau',
                      style: hankenGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Barre d'actions basse façon Naolib : Filtres + zoom + recentrage.
            if (!_loading && gtfs.cachedRoutes.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                bottom: bottomPad + 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _FiltresPill(
                      colors: c,
                      active: _activeModes.length <
                          _availableModes(gtfs.cachedRoutes).length,
                      onTap: () => _openFilters(gtfs.cachedRoutes, c),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        _CircleButton(
                          icon: LucideIcons.plus,
                          colors: c,
                          onTap: () => _mapController.move(
                            _mapController.camera.center,
                            (_mapController.camera.zoom + 1).clamp(11, 17),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _CircleButton(
                          icon: LucideIcons.minus,
                          colors: c,
                          onTap: () => _mapController.move(
                            _mapController.camera.center,
                            (_mapController.camera.zoom - 1).clamp(11, 17),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _CircleButton(
                          icon: userPos != null
                              ? LucideIcons.locateFixed
                              : LucideIcons.locate,
                          colors: c,
                          highlight: userPos != null,
                          onTap: () => _recenter(userPos),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bouton « Filtres » arrondi (bas-gauche).
class _FiltresPill extends StatelessWidget {
  final AuleColors colors;
  final bool active;
  final VoidCallback onTap;
  const _FiltresPill(
      {required this.colors, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: active ? colors.brand : colors.line),
          boxShadow: AuleTokens.cardShadow(colors.shadow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.slidersHorizontal,
                size: 18, color: active ? colors.brand : colors.text),
            const SizedBox(width: 8),
            Text(
              'Filtres',
              style: hankenGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: active ? colors.brand : colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feuille de filtres par mode de transport.
class _FilterSheet extends StatelessWidget {
  final AuleColors colors;
  final List<AuleLineMode> available;
  final Set<AuleLineMode> active;
  final void Function(AuleLineMode) onToggle;
  final VoidCallback onReset;

  const _FilterSheet({
    required this.colors,
    required this.available,
    required this.active,
    required this.onToggle,
    required this.onReset,
  });

  static const _labels = {
    AuleLineMode.tram: 'Tramway',
    AuleLineMode.busway: 'Chronobus',
    AuleLineMode.bus: 'Bus',
  };

  static const _icons = {
    AuleLineMode.tram: LucideIcons.trainFront,
    AuleLineMode.busway: LucideIcons.busFront,
    AuleLineMode.bus: LucideIcons.bus,
  };

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Filtrer les lignes',
                style: hankenGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onReset,
                child: Text(
                  'Tout afficher',
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.brand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final mode in available) ...[
            _ModeRow(
              colors: colors,
              icon: _icons[mode] ?? LucideIcons.bus,
              label: _labels[mode] ?? 'Bus',
              selected: active.contains(mode),
              onTap: () => onToggle(mode),
            ),
            if (mode != available.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final AuleColors colors;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeRow({
    required this.colors,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? colors.brandWeak : colors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? colors.brandLine : colors.line, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? colors.brand : colors.muted),
            const SizedBox(width: 12),
            Text(
              label,
              style: hankenGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            const Spacer(),
            Icon(
              selected ? LucideIcons.checkCheck : LucideIcons.circle,
              size: 20,
              color: selected ? colors.brand : colors.faint,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final AuleColors colors;
  final VoidCallback onTap;
  final bool highlight;
  const _CircleButton({
    required this.icon,
    required this.colors,
    required this.onTap,
    this.highlight = false,
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
          shape: BoxShape.circle,
          border: Border.all(color: colors.line),
          boxShadow: AuleTokens.cardShadow(colors.shadow),
        ),
        child: Icon(icon,
            size: 20, color: highlight ? colors.brand : colors.text),
      ),
    );
  }
}
