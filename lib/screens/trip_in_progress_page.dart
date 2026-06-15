import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/aule_data_adapter.dart';
import '../services/gtfs_service.dart';
import '../widgets/vehicle_tracking/vehicle_vertical_timeline.dart';

/// Écran « Trajet en cours » — après montée dans le véhicule.
class TripInProgressPage extends StatefulWidget {
  final GtfsRoute route;
  final String headsign;
  final NearbyStation station;
  final StationDeparture departure;

  const TripInProgressPage({
    super.key,
    required this.route,
    required this.headsign,
    required this.station,
    required this.departure,
  });

  @override
  State<TripInProgressPage> createState() => _TripInProgressPageState();
}

class _TripInProgressPageState extends State<TripInProgressPage> {
  Timer? _ticker;
  int _stopsRemaining = 4;
  int _minutesToDestination = 12;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        if (_stopsRemaining > 0) _stopsRemaining--;
        if (_minutesToDestination > 0) _minutesToDestination--;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Color _lineColor() =>
      AuleDataAdapter.routeColor(widget.route) ??
      const Color(0xFF16A34A);

  List<TimelineStop> _buildStops(GtfsService gtfs) {
    final allStops = gtfs.stopsToward(widget.route, widget.headsign);
    final userIdx = allStops.indexWhere(
      (s) => s.stopName == widget.station.stop.stopName,
    );
    if (userIdx < 0) return [];

    final end = math.min(allStops.length, userIdx + 5);
    final slice = allStops.sublist(userIdx, end);
    final now = DateTime.now();

    return List.generate(slice.length, (i) {
      final arrival = now.add(Duration(minutes: i * 3));
      final timeStr =
          '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
      return TimelineStop(
        name: slice[i].stopName,
        arrivalTime: timeStr,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = _lineColor();
    final lineCode =
        widget.route.routeShortName ?? widget.route.routeId;
    final gtfs = context.watch<GtfsService>();
    final stops = _buildStops(gtfs);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF0B1220)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trajet en cours',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B1220),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lineColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: lineColor.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'TRAM $lineCode',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        LucideIcons.radio,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'En direct',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Direction ${widget.headsign}',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prochain arrêt dans $_minutesToDestination min',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            VehicleVerticalTimeline(
              stops: stops,
              userStopIndex: 0,
              vehicleBetweenIndex: 0,
              lineColor: lineColor,
              showVehicleOnTimeline: true,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.bell,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Alerte de descente activée — $_stopsRemaining arrêts avant votre destination.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
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
