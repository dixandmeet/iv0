import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../models/line_detail_models.dart';
import '../services/aule_data_adapter.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/vehicle_tracking/approach_alert_sheet.dart';
import '../widgets/vehicle_tracking/vehicle_action_buttons.dart';
import '../widgets/vehicle_tracking/vehicle_detail_card.dart';
import '../widgets/vehicle_tracking/vehicle_info_card.dart';
import '../widgets/line_detail/line_detail_map.dart';
import '../widgets/vehicle_tracking/vehicle_vertical_timeline.dart';
import 'trip_in_progress_page.dart';

/// Écran Véhicule — suivi temps réel jusqu'à la montée dans le tram.
class VehicleTrackingPage extends StatefulWidget {
  final GtfsRoute route;
  final String headsign;
  final NearbyStation station;
  final StationDeparture departure;

  const VehicleTrackingPage({
    super.key,
    required this.route,
    required this.headsign,
    required this.station,
    required this.departure,
  });

  @override
  State<VehicleTrackingPage> createState() => _VehicleTrackingPageState();
}

class _VehicleTrackingPageState extends State<VehicleTrackingPage> {
  static const _fallbackPosition = LatLng(47.2184, -1.5536);

  Timer? _ticker;
  bool _isFavorite = false;
  bool _notificationsEnabled = false;
  bool _approachAlertShown = false;
  bool _isBoarded = false;
  late int _waitMinutes;
  late int _remainingSeconds;
  late int _initialWaitSeconds;
  late DateTime _estimatedArrival;

  @override
  void initState() {
    super.initState();
    _waitMinutes = widget.departure.waitMinutes;
    _initialWaitSeconds = widget.departure.waitMinutes * 60;
    _remainingSeconds = _initialWaitSeconds;
    _estimatedArrival =
        DateTime.now().add(Duration(minutes: _waitMinutes));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _isBoarded) return;

    setState(() {
      final elapsed =
          DateTime.now().difference(_estimatedArrival.subtract(
        Duration(minutes: widget.departure.waitMinutes),
      ));
      final remainingSec =
          (widget.departure.waitMinutes * 60 - elapsed.inSeconds)
              .clamp(0, 9999);
      _remainingSeconds = remainingSec;
      _waitMinutes = (remainingSec / 60).ceil().clamp(0, 99);
      if (_waitMinutes == 0 && remainingSec > 0) _waitMinutes = 1;
      _estimatedArrival = DateTime.now().add(
        Duration(seconds: remainingSec),
      );
    });

    _checkApproach();
  }

  void _checkApproach() {
    if (_approachAlertShown || !_notificationsEnabled) return;
    if (_waitMinutes > 1) return;

    _approachAlertShown = true;
    HapticFeedback.mediumImpact();

    final lineColor = _lineColor();
    final lineCode =
        widget.route.routeShortName ?? widget.route.routeId;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🚋 Votre tram arrive bientôt — Le tram $lineCode direction ${widget.headsign} arrive dans moins d\'une minute.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: lineColor,
      ),
    );

    ApproachAlertSheet.show(
      context,
      lineCode: lineCode,
      direction: widget.headsign,
      stopName: widget.station.stop.stopName,
      lineColor: lineColor,
      onViewMap: () {},
    );
  }

  Color _lineColor() =>
      AuleDataAdapter.routeColor(widget.route) ??
      const Color(0xFF16A34A);

  IconData _vehicleIcon() {
    switch (widget.route.transportType.toLowerCase()) {
      case 'tram':
        return LucideIcons.tramFront;
      default:
        return LucideIcons.bus;
    }
  }

  String _vehicleId() {
    final seed = widget.route.routeId.hashCode.abs() % 9000 + 1000;
    return 'Tram $seed';
  }

  String _vehicleModel() {
    switch (widget.route.transportType.toLowerCase()) {
      case 'tram':
        return 'Alstom Citadis';
      default:
        return 'Iveco Urbanway';
    }
  }

  VehicleOccupancy _occupancy() {
    final h = DateTime.now().hour;
    if (h >= 7 && h <= 9 || h >= 17 && h <= 19) {
      return VehicleOccupancy.medium;
    }
    return VehicleOccupancy.low;
  }

  double _approachProgress() {
    if (_initialWaitSeconds <= 0) return 0;
    return 1 - (_remainingSeconds / _initialWaitSeconds);
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  List<TimelineStop> _buildTimelineStops(GtfsService gtfs) {
    final allStops = gtfs.stopsToward(
      widget.route,
      widget.headsign,
      via: widget.station.stop,
    );
    var userIdx = allStops.indexWhere(
      (s) => s.stopId == widget.station.stop.stopId,
    );
    if (userIdx < 0) {
      userIdx = allStops.indexWhere(
        (s) => s.stopName == widget.station.stop.stopName,
      );
    }
    if (userIdx < 0) {
      return [
        TimelineStop(
          name: widget.station.stop.stopName,
          arrivalTime: _formatTime(_estimatedArrival),
        ),
      ];
    }

    final start = math.max(0, userIdx - 3);
    final end = math.min(allStops.length, userIdx + 3);
    final slice = allStops.sublist(start, end);
    final baseOffset = userIdx - start;

    return List.generate(slice.length, (i) {
      final stopMinOffset = i - baseOffset;
      final arrival = _estimatedArrival.add(
        Duration(minutes: stopMinOffset.clamp(0, 99) * 3),
      );
      return TimelineStop(
        name: slice[i].stopName,
        arrivalTime: i >= baseOffset ? _formatTime(arrival) : null,
      );
    });
  }

  void _toggleNotifications() {
    setState(() => _notificationsEnabled = !_notificationsEnabled);
    if (_notificationsEnabled && _waitMinutes <= 1) {
      _checkApproach();
    }
  }

  void _onBoard() {
    if (_waitMinutes > 1 && !_isArrived) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre tram n\'est pas encore arrivé — suivez-le en temps réel.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isBoarded = true);
    HapticFeedback.heavyImpact();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => TripInProgressPage(
          route: widget.route,
          headsign: widget.headsign,
          station: widget.station,
          departure: widget.departure,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _onShare() {
    final lineCode =
        widget.route.routeShortName ?? widget.route.routeId;
    final timeStr = _formatTime(_estimatedArrival);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tram $lineCode → ${widget.headsign} · Arrivée $timeStr à ${widget.station.stop.stopName}',
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Copier',
          onPressed: () {
            Clipboard.setData(ClipboardData(
              text:
                  'Je prends le tram $lineCode direction ${widget.headsign}, arrivée prévue à $timeStr (${widget.station.stop.stopName}).',
            ));
          },
        ),
      ),
    );
  }

  bool get _isApproaching => _waitMinutes <= 1;
  bool get _isArrived => _remainingSeconds <= 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? AuleColors.dark : AuleColors.light;
    final location = context.watch<LocationService>();
    final gtfs = context.watch<GtfsService>();

    final pos = location.currentPosition;
    final userPos = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _fallbackPosition;

    final lineColor = _lineColor();
    final lineCode =
        widget.route.routeShortName ?? widget.route.routeId;
    final vehiclePos = gtfs.projectVehicleOnRoute(
      widget.route,
      widget.station.stop,
      widget.headsign,
      _remainingSeconds.toDouble(),
    );

    final timelineStops = _buildTimelineStops(gtfs);
    final timelineUserIdx = timelineStops.indexWhere(
      (s) => s.name == widget.station.stop.stopName,
    );
    final safeUserIdx = timelineUserIdx >= 0
        ? timelineUserIdx
        : timelineStops.length ~/ 2;

    return AuleTheme(
      colors: colors,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Row(
                      children: [
                        _TrackingNavButton(
                          icon: LucideIcons.arrowLeft,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _TrackingNavButton(
                          icon: LucideIcons.star,
                          filled: _isFavorite,
                          onTap: () =>
                              setState(() => _isFavorite = !_isFavorite),
                        ),
                      ],
                    ),
                  ),
                  LineDetailMap(
                    route: widget.route,
                    headsign: widget.headsign,
                    stop: widget.station.stop,
                    userPosition: userPos,
                    vehiclePosition: vehiclePos,
                    lineColor: lineColor,
                    waitMinutes: _waitMinutes,
                    vehicleIcon: _vehicleIcon(),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: VehicleInfoCard(
                              lineCode: lineCode,
                              lineColor: lineColor,
                              direction: widget.headsign,
                              stopName: widget.station.stop.stopName,
                              waitMinutes: _waitMinutes,
                              waitSeconds: _remainingSeconds,
                              estimatedArrival: _estimatedArrival,
                              occupancy: _occupancy(),
                              isApproaching: _isApproaching,
                              approachProgress: _approachProgress(),
                              vehicleIcon: _vehicleIcon(),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: VehicleVerticalTimeline(
                            stops: timelineStops,
                            userStopIndex: safeUserIdx,
                            vehicleBetweenIndex:
                                math.max(0, safeUserIdx - 1),
                            lineColor: lineColor,
                            vehicleIcon: _vehicleIcon(),
                            showVehicleOnTimeline: _isApproaching,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: VehicleDetailCard(
                            vehicleNumber: _vehicleId(),
                            vehicleModel: _vehicleModel(),
                            lineColor: lineColor,
                            lineCode: lineCode,
                            features:
                                VehicleDetailCard.defaultTramFeatures(),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                220 + MediaQuery.paddingOf(context).bottom,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VehicleActionButtons(
                lineColor: lineColor,
                notificationsEnabled: _notificationsEnabled,
                isArrived: _isArrived,
                isBoarded: _isBoarded,
                waitMinutes: _waitMinutes,
                onToggleNotifications: _toggleNotifications,
                onBoard: _onBoard,
                onShare: _onShare,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _TrackingNavButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: filled ? const Color(0xFFF59E0B) : const Color(0xFF0B1220),
            fill: filled ? 1.0 : 0.0,
          ),
        ),
      ),
    );
  }
}
