import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../models/line_detail_models.dart';
import '../services/aule_data_adapter.dart';
import '../services/disruption_service.dart';
import '../services/favorites_service.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../services/realtime_config.dart';
import '../theme/aule_theme.dart';
import '../widgets/line_detail/decision_support_card.dart';
import '../widgets/line_detail/line_detail_header.dart';
import '../widgets/line_detail/line_detail_map.dart';
import '../widgets/line_detail/line_timeline.dart';
import '../widgets/line_detail/next_departures_row.dart';
import '../widgets/line_detail/theoretical_schedule_bottom_sheet.dart';
import '../widgets/line_detail/stop_info_card.dart';
import '../widgets/line_detail/line_take_vehicle_button.dart';
import '../widgets/line_detail/vehicle_info_section.dart';
import '../widgets/nearby_stops/bottom_nav_bar.dart';
import '../widgets/stop_detail/line_disruption_banner.dart';
import 'app_shell.dart';
import 'immersive_navigation_page.dart';

/// Page premium « Détail ligne » — prochains passages, carte temps réel,
/// plan de ligne, aide à la décision et actions utilisateur.
class LineDetailPage extends StatefulWidget {
  final GtfsRoute route;
  final String headsign;
  final NearbyStation station;
  final StationDeparture departure;

  const LineDetailPage({
    super.key,
    required this.route,
    required this.headsign,
    required this.station,
    required this.departure,
  });

  @override
  State<LineDetailPage> createState() => _LineDetailPageState();
}

class _LineDetailPageState extends State<LineDetailPage> {
  static const _distance = Distance();
  static const _fallbackPosition = LatLng(47.25156, -1.53026);

  Timer? _ticker;
  final bool _boardingRegistered = false;

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

  IconData _vehicleIcon(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'tram':
        return LucideIcons.tramFront;
      case 'busway':
      case 'navibus':
      case 'bus':
      default:
        return LucideIcons.bus;
    }
  }

  int _headwayMinutes(String transportType) {
    switch (transportType.toLowerCase()) {
      case 'tram':
        return 6;
      case 'busway':
        return 8;
      case 'navibus':
        return 20;
      default:
        return 12;
    }
  }

  List<DepartureSlot> _buildDepartures() {
    final now = DateTime.now();
    final wait = widget.departure.waitMinutes;
    final next = widget.departure.nextWaitMinutes;
    final headway = _headwayMinutes(widget.route.transportType);
    // Sans flux live Okina, même les prochains passages sont théoriques
    // (horaires GTFS), pas du temps réel.
    final liveStatus = RealtimeConfig.isLiveEnabled
        ? DepartureStatus.realtime
        : DepartureStatus.theoretical;

    return [
      DepartureSlot(
        waitMinutes: wait,
        departureTime: now.add(Duration(minutes: wait)),
        status: liveStatus,
      ),
      DepartureSlot(
        waitMinutes: next,
        departureTime: now.add(Duration(minutes: next)),
        status: liveStatus,
      ),
      DepartureSlot(
        waitMinutes: next + headway,
        departureTime: now.add(Duration(minutes: next + headway)),
        status: DepartureStatus.theoretical,
      ),
      DepartureSlot(
        waitMinutes: next + headway * 2,
        departureTime: now.add(Duration(minutes: next + headway * 2)),
        status: DepartureStatus.theoretical,
      ),
      DepartureSlot(
        waitMinutes: next + headway * 3,
        departureTime: now.add(Duration(minutes: next + headway * 3)),
        status: DepartureStatus.theoretical,
      ),
    ];
  }

  DecisionInsight _buildInsight(LatLng userPos, LatLng? vehiclePos) {
    final walkM = _distance
        .as(LengthUnit.Meter, userPos, widget.station.stop.position)
        .round();
    final walkMin = (walkM / 75).ceil().clamp(1, 99);
    final wait = widget.departure.waitMinutes;
    final recommended = (wait - 1).clamp(0, 99);
    final vehicleKm = vehiclePos != null
        ? _distance.as(LengthUnit.Kilometer, userPos, vehiclePos)
        : 1.2;

    return DecisionInsight(
      recommendedLeaveMinutes: recommended,
      walkMinutes: walkMin,
      walkMeters: walkM,
      vehicleDistanceKm: vehicleKm,
      willMissPassage: recommended < walkMin,
      willArriveBeforeVehicle: recommended >= walkMin && wait > walkMin,
    );
  }

  List<String> _connections(GtfsService gtfs) {
    final current = widget.route.routeShortName ?? widget.route.routeId;
    return gtfs.cachedRoutes
        .where((r) {
          final served = gtfs.stationLineGroups(widget.station)
              .any((g) => g.route.routeId == r.routeId);
          return served && (r.routeShortName ?? r.routeId) != current;
        })
        .map((r) => r.routeShortName ?? r.routeId)
        .take(4)
        .toList();
  }

  String _vehicleId() {
    final seed = widget.route.routeId.hashCode.abs() % 9000 + 1000;
    return '$seed';
  }

  String _vehicleDisplayName() {
    final type = widget.route.transportType == 'tram' ? 'Tram' : 'Bus';
    return '$type ${_vehicleId()}';
  }

  void _openVehicleTracking() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? AuleColors.dark : AuleColors.light;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => AuleTheme(
          colors: colors,
          child: ImmersiveNavigationPage(
            route: widget.route,
            headsign: widget.headsign,
            station: widget.station,
            departure: widget.departure,
          ),
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0A0D13) : const Color(0xFFF6F7FB);
    final colors = isDark ? AuleColors.dark : AuleColors.light;

    final location = context.watch<LocationService>();
    final gtfs = context.watch<GtfsService>();
    final favorites = context.watch<FavoritesService>();
    final isFavoriteLine = favorites.isFavoriteLine(widget.route.routeId);
    final disruptions = context.watch<DisruptionService>();
    final lineDisruptions = disruptions.disruptionsForLine(
      widget.route.routeShortName ?? widget.route.routeId,
    );
    final pos = location.currentPosition;
    final userPos = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _fallbackPosition;

    final lineColor =
        AuleDataAdapter.routeColor(widget.route) ?? const Color(0xFF16A34A);
    final waitSeconds = widget.departure.waitMinutes * 60;
    final vehiclePos = gtfs.projectVehicleOnRoute(
      widget.route,
      widget.station.stop,
      widget.headsign,
      waitSeconds.toDouble(),
    );

    final stops = gtfs.stopsToward(
      widget.route,
      widget.headsign,
      via: widget.station.stop,
    );
    final termini = stops.length >= 2
        ? (stops.first.stopName, stops.last.stopName)
        : gtfs.terminiToward(widget.route, widget.headsign);
    final selectedIndex =
        stops.indexWhere((s) => s.stopName == widget.station.stop.stopName);
    final safeSelected = selectedIndex >= 0 ? selectedIndex : 0;
    final aheadIndex = selectedIndex >= 0
        ? gtfs.firstStopAheadIndex(
            stops,
            selectedIndex,
            widget.route.transportType,
            waitSeconds.toDouble(),
          )
        : 0;
    final maxBetween = math.max(0, stops.length - 2);
    final vehicleBetween = math.max(0, math.min(aheadIndex - 1, maxBetween));
    final remainingStops = selectedIndex >= 0
        ? math.max(0, math.min(selectedIndex - aheadIndex, 99))
        : 3;

    final departures = _buildDepartures();
    final insight = _buildInsight(userPos, vehiclePos);
    final connections = _connections(gtfs);

    return AuleTheme(
      colors: colors,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  LineDetailHeader(
                    route: widget.route,
                    headsign: widget.headsign,
                    fromStopName: widget.station.stop.stopName,
                    modeLabel: AuleDataAdapter.modeLabel(
                      widget.route.transportType,
                    ),
                    lineColor: lineColor,
                    nextWaitMinutes: widget.departure.waitMinutes,
                    isFavorite: isFavoriteLine,
                    isRealtime: RealtimeConfig.isLiveEnabled,
                    onBack: () => Navigator.pop(context),
                    onFavoriteToggle: () =>
                        favorites.toggleLine(widget.route.routeId),
                    vehicleIcon: _vehicleIcon(widget.route.transportType),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      if (lineDisruptions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: LineDisruptionBanner(
                            reports: lineDisruptions,
                            colors: colors,
                            showDescriptions: true,
                          ),
                        ),
                      NextDeparturesRow(
                        departures: departures,
                        lineColor: lineColor,
                        stopName: widget.station.stop.stopName,
                        headwayMinutes: gtfs.headwayMinutesFor(
                          widget.route.transportType,
                        ),
                        onSeeMore: () {
                          final times = gtfs.theoreticalDepartureTimes(
                            widget.route,
                            widget.station.stop,
                            direction: widget.headsign,
                            fullDay: true,
                          );
                          TheoreticalScheduleBottomSheet.show(
                            context,
                            times: times,
                            stopName: widget.station.stop.stopName,
                            headsign: widget.headsign,
                            lineCode: widget.route.routeShortName ??
                                widget.route.routeId,
                            lineColor: lineColor,
                            headwayMinutes: gtfs.headwayMinutesFor(
                              widget.route.transportType,
                            ),
                          );
                        },
                      ),
                      LineTimeline(
                        stops: stops,
                        selectedIndex: safeSelected,
                        vehicleBetweenIndex: vehicleBetween,
                        lineColor: lineColor,
                        headsign: widget.headsign,
                        originTerminus: termini?.$1,
                        destinationTerminus: termini?.$2,
                        lineCode: widget.route.routeShortName ??
                            widget.route.routeId,
                        vehicleIcon: _vehicleIcon(widget.route.transportType),
                      ),
                      LineDetailMap(
                        route: widget.route,
                        headsign: widget.headsign,
                        stop: widget.station.stop,
                        userPosition: userPos,
                        vehiclePosition: vehiclePos,
                        lineColor: lineColor,
                        waitMinutes: widget.departure.waitMinutes,
                        vehicleIcon: _vehicleIcon(widget.route.transportType),
                      ),
                      DecisionSupportCard(insight: insight),
                      StopInfoCard(
                        stop: widget.station.stop,
                        lineColor: lineColor,
                        connections: connections,
                      ),
                      VehicleInfoSection(
                        vehicleNumber: _vehicleDisplayName(),
                        modeLabel: AuleDataAdapter.modeLabel(
                          widget.route.transportType,
                        ),
                        lineCode: widget.route.routeShortName ??
                            widget.route.routeId,
                        lineColor: lineColor,
                        occupancy: VehicleOccupancy.low,
                        remainingStops: remainingStops,
                        delayMinutes: 1,
                        lastUpdate: DateTime.now(),
                        vehicleIcon: _vehicleIcon(widget.route.transportType),
                        isRealtime: RealtimeConfig.isLiveEnabled,
                      ),
                    ],
                  ),
                ),
              ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: LineTakeVehicleButton(
                  lineColor: lineColor,
                  label: LineTakeVehicleButton.labelFor(
                    widget.route.transportType,
                    registered: _boardingRegistered,
                  ),
                  icon: LineTakeVehicleButton.iconFor(
                    widget.route.transportType,
                    registered: _boardingRegistered,
                  ),
                  isRegistered: _boardingRegistered,
                  onPressed: _openVehicleTracking,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: 0,
          onTap: (index) {
            AppShell.switchTab(context, index);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
