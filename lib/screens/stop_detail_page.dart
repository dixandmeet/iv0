import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/gtfs_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/line_detail/theoretical_schedule_bottom_sheet.dart';
import '../widgets/nearby_stops/line_badge.dart';
import '../widgets/stop_detail/departure_card.dart';
import '../widgets/stop_detail/stop_detail_header.dart';
import 'line_detail_page.dart';

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

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
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

  /// Grille horaire complète de la journée pour la ligne/direction touchée,
  /// à cet arrêt — l'accès direct aux « détails des horaires » de la station.
  void _openSchedule(GtfsRoute route, StationDeparture departure) {
    final gtfs = context.read<GtfsService>();
    final times = gtfs.theoreticalDepartureTimes(
      route,
      widget.station.stop,
      direction: departure.headsign,
      fullDay: true,
    );
    TheoreticalScheduleBottomSheet.show(
      context,
      times: times,
      stopName: widget.station.stop.stopName,
      headsign: departure.headsign,
      lineCode: route.routeShortName ?? route.routeId,
      lineColor: LineBadge.colorFor(route.routeShortName ?? route.routeId),
      headwayMinutes: gtfs.headwayMinutesFor(route.transportType),
    );
  }

  /// Page ligne (tracé, carte, suivi temps réel) — via le badge de ligne.
  void _openLineDetail(GtfsRoute route, StationDeparture departure) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LineDetailPage(
          route: route,
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
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final mutedText = isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final colors = isDark ? AuleColors.dark : AuleColors.light;

    final gtfs = context.watch<GtfsService>();
    final groups = gtfs.stationLineGroups(widget.station);

    return AuleTheme(
      colors: colors,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              StopDetailHeader(
                stopName: widget.station.stop.stopName,
                meta: _meta,
                accessible: widget.station.stop.isWheelchairAccessible,
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: groups.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(
                                      'Aucun départ à cet arrêt.',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontWeight: FontWeight.w600,
                                        color: mutedText,
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (var i = 0; i < groups.length; i++)
                                      DepartureCard(
                                        group: groups[i],
                                        showDivider: i < groups.length - 1,
                                        onDirectionTap: _openSchedule,
                                        onLineTap: _openLineDetail,
                                      ),
                                  ],
                                ),
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
