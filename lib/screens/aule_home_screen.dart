import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/aule_data_adapter.dart';
import '../services/gtfs_service.dart';
import '../services/home_aggregator.dart';
import '../services/location_service.dart';
import '../services/report_service.dart';
import '../services/supabase_service.dart';
import '../services/vehicle_detection_service.dart';
import '../theme/aule_theme.dart';
import '../utils/aule_eta.dart';
import '../widgets/aule/alert_card.dart';
import '../widgets/aule/aule_icons.dart';
import '../widgets/aule/aule_search_bar.dart';
import '../widgets/aule/departure_row.dart';
import '../widgets/aule/network_status.dart';
import '../widgets/aule/radar_map_header.dart';
import '../widgets/aule/section_title.dart';
import '../widgets/aule/stop_card.dart';
import 'search_route_screen.dart';
import 'unified_search_screen.dart';

/// Écran Accueil « Radar » — données GTFS + temps réel.
class AuleHomeScreen extends StatefulWidget {
  final VoidCallback? onFavoritesTap;

  const AuleHomeScreen({super.key, this.onFavoritesTap});

  @override
  State<AuleHomeScreen> createState() => _AuleHomeScreenState();
}

class _AuleHomeScreenState extends State<AuleHomeScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _favoritesKey = GlobalKey();

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UnifiedSearchScreen()),
    );
  }

  void _scrollToFavorites() {
    widget.onFavoritesTap?.call();
    final ctx = _favoritesKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    context.watch<AuleClock>();

    final location = context.watch<LocationService>();
    final gtfs = context.watch<GtfsService>();
    final detection = context.watch<VehicleDetectionService>();
    final reports = context.watch<ReportService>();
    final supabase = context.watch<SupabaseService>();

    final now = DateTime.now();
    final pos = location.currentPosition;
    final LatLng? userPos =
        pos != null ? LatLng(pos.latitude, pos.longitude) : null;

    final vehicles = HomeAggregator.nearbyVehicles(
      detection.detectedVehicles,
      userPos,
    );

    final snapshot = AuleDataAdapter.buildHomeSnapshot(
      gtfs: gtfs,
      userPosition: userPos,
      vehicles: vehicles,
      reports: reports.activeReports,
      isOffline: supabase.isOfflineMode,
      now: now,
    );

    final sortedDepartures = [...snapshot.departures]
      ..sort((a, b) => a.arrivalAt.compareTo(b.arrivalAt));

    final suggestion = snapshot.suggestion;
    final suggestionFmt = suggestion?.arrivalAt != null
        ? formatAuleEta(auleEtaSeconds(suggestion!.arrivalAt!, now))
        : null;

    return ColoredBox(
      color: c.bg,
      child: Stack(
        children: [
          Column(
            children: [
              RadarMapHeader(
                center: HomeAggregator.resolveCenter(userPos),
                vehicles: snapshot.vehicles,
                now: now,
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
                  children: [
                    if (snapshot.isOffline)
                      const _InfoStrip(
                        text:
                            'Hors-ligne · véhicules temps réel indisponibles',
                      )
                    else if (!snapshot.hasGps)
                      const _InfoStrip(
                        text: 'Position indisponible — réactivez le GPS',
                      ),
                    SectionTitle(
                      icon: AuleIcons.pin(size: 19, color: c.text),
                      title: 'Arrêts autour de vous',
                    ),
                    if (snapshot.stops.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          snapshot.hasGps
                              ? 'Aucun arrêt à proximité. Rapprochez-vous du réseau.'
                              : 'Activez le GPS pour voir les arrêts proches.',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.muted,
                          ),
                        ),
                      )
                    else
                      ...snapshot.stops.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: StopCard(stop: s, now: now),
                        ),
                      ),
                    const SizedBox(height: 15),
                    if (sortedDepartures.isNotEmpty) ...[
                      SectionTitle(
                        icon: AuleIcons.bus(size: 19, color: c.text),
                        title: 'Prochains départs',
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: c.surface,
                          border: Border.all(color: c.line),
                          borderRadius:
                              BorderRadius.circular(AuleTokens.rCard),
                          boxShadow: AuleTokens.cardShadow(c.shadow),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: List.generate(sortedDepartures.length, (i) {
                            return DepartureRow(
                              departure: sortedDepartures[i],
                              now: now,
                              showDivider: i < sortedDepartures.length - 1,
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                    SectionTitle(
                      icon: AuleIcons.network(size: 19, color: c.text),
                      title: 'État du réseau',
                    ),
                    NetworkStatus(
                      percent: snapshot.networkHealthPercent,
                      disruptions: snapshot.networkDisruptions,
                    ),
                    if (snapshot.alerts.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SectionTitle(
                        icon: AuleIcons.alert(size: 19, color: c.warn),
                        title: 'Informations trafic',
                      ),
                      ...snapshot.alerts.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: AlertCard(alert: a),
                        ),
                      ),
                    ],
                    if (suggestion != null) ...[
                      const SizedBox(height: 17),
                      _SuggestionCard(
                        timeLabel: suggestion.timeLabel,
                        title: suggestion.title,
                        etaNum: suggestionFmt?.num,
                        etaUnit: suggestionFmt?.unit,
                      ),
                    ],
                    const SizedBox(height: 28),
                    SectionTitle(
                      icon: AuleIcons.favoriteOutline(size: 19, color: c.text),
                      title: 'Favoris',
                    ),
                    _FavoritesRow(key: _favoritesKey),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: AuleTokens.mapHeaderHeight - 26,
            child: AuleSearchBar(
              onSearchTap: _openSearch,
              onFavoritesTap: _scrollToFavorites,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final String text;
  const _InfoStrip({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.brandWeak,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.brandLine),
        ),
        child: Text(
          text,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: c.brand,
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String timeLabel;
  final String title;
  final String? etaNum;
  final String? etaUnit;

  const _SuggestionCard({
    required this.timeLabel,
    required this.title,
    this.etaNum,
    this.etaUnit,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: c.brandWeak,
        border: Border.all(color: c.brandLine),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.brand,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: AuleIcons.assistant(size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUGGESTION · $timeLabel',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: c.brand,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
          if (etaNum != null)
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    etaNum!,
                    maxLines: 1,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1,
                      color: c.brand,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (etaUnit != null && etaUnit!.isNotEmpty)
                    Text(
                      etaUnit!,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: c.muted,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoritesRow extends StatelessWidget {
  const _FavoritesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    final items = [
      ('home', 'Maison', 'Itinéraire rapide'),
      ('work', 'Travail', 'Itinéraire rapide'),
      ('star', 'Ajouter', 'Nouveau favori'),
    ];

    return Row(
      children: List.generate(items.length, (i) {
        final (iconKey, name, subtitle) = items[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? 11 : 0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SearchRouteScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(13, 15, 13, 15),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(AuleTokens.rCardSm),
                  boxShadow: [
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                      spreadRadius: -18,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.brandWeak,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: _favIcon(iconKey, c.brand),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: c.text,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _favIcon(String key, Color color) {
    switch (key) {
      case 'home':
        return AuleIcons.home(size: 19, color: color);
      case 'work':
        return AuleIcons.work(size: 19, color: color);
      default:
        return AuleIcons.favoriteOutline(size: 19, color: color);
    }
  }
}
