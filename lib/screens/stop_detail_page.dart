import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/disruption_service.dart';
import '../services/favorites_service.dart';
import '../services/gtfs_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/stop_detail/departure_card.dart';
import '../widgets/stop_detail/stop_detail_header.dart';
import '../widgets/stop_detail/stop_filter_chips.dart';
import '../widgets/stop_detail/approaching_alert_banner.dart';
import '../widgets/stop_detail/line_disruption_banner.dart';
import '../widgets/stop_detail/stop_services_card.dart';
import 'disruptions_page.dart';
import 'line_detail_page.dart';
import 'stop_schedule_grid_page.dart';

/// Au-delà de cette attente, un passage est masqué par défaut (bruit).
const _maxWaitMinutes = 60;

/// Nombre de départs affichés avant le bouton « Voir tous les départs ».
const _defaultVisibleCount = 5;

/// Page détail d'un arrêt : prochains départs.
class StopDetailPage extends StatefulWidget {
  final NearbyStation station;

  /// Vrai si [NearbyStation.distanceMeters] vient de la position réelle de
  /// l'utilisateur : on affiche alors distance + temps de marche, sinon le
  /// nombre de lignes.
  final bool showDistance;

  const StopDetailPage({
    super.key,
    required this.station,
    this.showDistance = false,
  });

  @override
  State<StopDetailPage> createState() => _StopDetailPageState();
}

class _StopDetailPageState extends State<StopDetailPage> {
  Timer? _ticker;
  StopFilter _filter = StopFilter.all;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DisruptionService>().load();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Sous-titre de l'en-tête : distance + temps de marche si la position
  /// réelle est connue, sinon le nombre de lignes desservant la station.
  String get _meta {
    final station = widget.station;
    if (!widget.showDistance) {
      final n = station.routes.length;
      return '$n ligne${n > 1 ? 's' : ''}';
    }
    final meters = station.distanceMeters;
    final distance = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
    // ~75 m/min : vitesse de marche prudente en ville.
    final walk = (meters / 75).ceil();
    return '$distance · $walk min à pied';
  }

  bool _matchesFilter(StationDeparture dep, FavoritesService favorites) {
    switch (_filter) {
      case StopFilter.all:
        return true;
      case StopFilter.tram:
        return dep.route.transportType == 'tram';
      case StopFilter.bus:
        return dep.route.transportType != 'tram';
      case StopFilter.favorites:
        return favorites.isFavoriteLine(dep.route.routeId);
    }
  }

  /// Page ligne (tracé, carte, suivi temps réel, horaires, perturbations).
  void _openLineDetail(StationDeparture departure) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LineDetailPage(
          route: departure.route,
          headsign: departure.headsign,
          station: widget.station,
          departure: departure,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0A0D13) : const Color(0xFFF6F7FB);
    final mutedText = isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final colors = isDark ? AuleColors.dark : AuleColors.light;

    final gtfs = context.watch<GtfsService>();
    final favorites = context.watch<FavoritesService>();
    final disruptions = context.watch<DisruptionService>();
    final stopId = widget.station.stop.stopId;

    // Tous les passages, triés chronologiquement, hors passages trop lointains.
    final allDepartures = gtfs.stationDepartures(widget.station)
      ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
    final upcoming = allDepartures
        .where((d) => d.waitMinutes <= _maxWaitMinutes)
        .toList();

    // Chips masquées faute de données (évite un filtre menant à une liste vide).
    final hasTram = allDepartures.any((d) => d.route.transportType == 'tram');
    final hasBus = allDepartures.any((d) => d.route.transportType != 'tram');
    final hasFavorite = allDepartures
        .any((d) => favorites.isFavoriteLine(d.route.routeId));
    final hiddenFilters = <StopFilter>{
      if (!hasTram) StopFilter.tram,
      if (!hasBus) StopFilter.bus,
      if (!hasFavorite) StopFilter.favorites,
    };
    if (hiddenFilters.contains(_filter)) _filter = StopFilter.all;

    final filtered =
        upcoming.where((d) => _matchesFilter(d, favorites)).toList();
    final hasMore = filtered.length > _defaultVisibleCount;
    final visible = _showAll || !hasMore
        ? filtered
        : filtered.take(_defaultVisibleCount).toList();

    // Véhicules en approche (< 1 min) — pour le bandeau d'alarme.
    final approaching = filtered.where((d) => d.waitMinutes < 1).toList();

    // Perturbations touchant une des lignes desservies par cet arrêt.
    final stopDisruptions = [
      for (final route in widget.station.routes)
        ...disruptions.disruptionsForLine(
          route.routeShortName ?? route.routeId,
        ),
    ];

    return AuleTheme(
      colors: colors,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 4),
              StopDetailHeader(
                stopName: widget.station.stop.stopName,
                meta: _meta,
                accessible: widget.station.stop.isWheelchairAccessible,
                onBack: () => Navigator.pop(context),
                isFavorite: favorites.isFavorite(stopId),
                onToggleFavorite: () => favorites.toggle(stopId),
              ),
              const SizedBox(height: 8),
              StopFilterChips(
                selected: _filter,
                hidden: hiddenFilters,
                colors: colors,
                onSelected: (f) => setState(() {
                  _filter = f;
                  _showAll = false;
                }),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (stopDisruptions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: LineDisruptionBanner(
                            reports: stopDisruptions,
                            colors: colors,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const DisruptionsPage(),
                              ),
                            ),
                          ),
                        ),
                      if (approaching.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: ApproachingAlertBanner(
                            departures: approaching,
                            colors: colors,
                            onTap: approaching.length == 1
                                ? () => _openLineDetail(approaching.first)
                                : null,
                          ),
                        ),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 24),
                          child: Center(
                            child: Text(
                              'Aucun départ à cet arrêt.',
                              style: hankenGrotesk(
                                fontWeight: FontWeight.w600,
                                color: mutedText,
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              for (var i = 0; i < visible.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                DepartureCard(
                                  departure: visible[i],
                                  colors: colors,
                                  onTap: () => _openLineDetail(visible[i]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (hasMore && !_showAll)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _ShowAllButton(
                            colors: colors,
                            onTap: () => setState(() => _showAll = true),
                          ),
                        ),
                      if (widget.station.routes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _FullScheduleButton(
                            colors: colors,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => StopScheduleGridPage(
                                  station: widget.station,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: StopServicesCard(
                          station: widget.station,
                          colors: colors,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton discret « Voir tous les départs » : déplie la liste complète.
class _ShowAllButton extends StatelessWidget {
  final AuleColors colors;
  final VoidCallback onTap;

  const _ShowAllButton({required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Voir tous les départs',
                style: hankenGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.muted,
                ),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronDown, size: 16, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton « Tous les horaires » : ouvre la grille horaire complète (fiche
/// horaire par ligne / direction / type de jour).
class _FullScheduleButton extends StatelessWidget {
  final AuleColors colors;
  final VoidCallback onTap;

  const _FullScheduleButton({required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.brandWeak,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.brandLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.calendarClock, size: 18, color: colors.brand),
              const SizedBox(width: 8),
              Text(
                'Tous les horaires',
                style: hankenGrotesk(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: colors.brand,
                ),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 16, color: colors.brand),
            ],
          ),
        ),
      ),
    );
  }
}
