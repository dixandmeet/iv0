import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/aule_data_adapter.dart';
import '../services/disruption_service.dart';
import '../services/favorites_service.dart';
import '../services/gtfs_service.dart';
import '../services/realtime_config.dart';
import '../theme/aule_theme.dart';
import '../widgets/line_detail/line_detail_header.dart';
import '../widgets/line_detail/line_timeline.dart';
import '../widgets/line_detail/stop_info_card.dart';
import '../widgets/line_detail/line_take_vehicle_button.dart';
import '../widgets/nearby_stops/bottom_nav_bar.dart';
import '../widgets/traveler_comments/traveler_comments_preview_section.dart';
import 'app_shell.dart';
import 'immersive_navigation_page.dart';

/// Page « Détail ligne » simplifiée — plan de ligne vertical (position du
/// véhicule + arrêt courant), infos arrêt et action « prendre le véhicule ».
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

  List<String> _connections(GtfsService gtfs) {
    final current = widget.route.routeShortName ?? widget.route.routeId;
    // Les lignes en correspondance sont exactement celles desservant l'arrêt :
    // un seul calcul des groupes suffit (éviter de le relancer par ligne).
    final seen = <String>{};
    final result = <String>[];
    for (final group in gtfs.stationLineGroups(widget.station)) {
      final code = group.route.routeShortName ?? group.route.routeId;
      if (code == current || !seen.add(code)) continue;
      result.add(code);
      if (result.length >= 4) break;
    }
    return result;
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
    final scaffoldBg =
        isDark ? const Color(0xFF0A0D13) : const Color(0xFFF6F7FB);
    final colors = isDark ? AuleColors.dark : AuleColors.light;

    final gtfs = context.watch<GtfsService>();
    final favorites = context.watch<FavoritesService>();
    final isFavoriteLine = favorites.isFavoriteLine(widget.route.routeId);

    final lineColor =
        AuleDataAdapter.routeColor(widget.route) ?? const Color(0xFF16A34A);
    final waitSeconds = widget.departure.waitMinutes * 60;

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
                            vehicleIcon:
                                _vehicleIcon(widget.route.transportType),
                          ),
                          TravelerCommentsPreviewSection(
                            route: widget.route,
                            headsign: widget.headsign,
                            station: widget.station,
                            stops: stops,
                            lineColor: lineColor,
                          ),
                          StopInfoCard(
                            stop: widget.station.stop,
                            lineColor: lineColor,
                            connections: connections,
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
