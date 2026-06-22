import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/leg_guidance_context.dart';
import '../models/line_detail_models.dart';
import '../services/aule_data_adapter.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/aule/line_badge.dart' as aule;
import '../widgets/vehicle_tracking/approach_alert_sheet.dart';
import '../widgets/vehicle_tracking/vehicle_action_buttons.dart';
import '../widgets/vehicle_tracking/vehicle_info_card.dart';
import '../widgets/vehicle_tracking/vehicle_map_header.dart';
import '../widgets/vehicle_tracking/vehicle_vertical_timeline.dart';

enum GuidancePhase { walkToStop, waiting, inTransit, transfer, arrived }

// Palette Aule (clair) — le guidage est volontairement en thème clair (et
// sombre « à bord »). Constantes locales pour rester utilisables en `const`.
const Color _ink = Color(0xFF0B1220);
const Color _muted = Color(0xFF5B6677);
const Color _faint = Color(0xFF9AA4B2);
const Color _line = Color(0xFFE7EAF0);
const Color _fill = Color(0xFFF2F4F8);
const Color _brand = Color(0xFF1B66F5);
const Color _brandWeak = Color(0xFFEAF1FE);
const Color _green = Color(0xFF15803D);
const Color _greenSoft = Color(0xFFDCF2E4);
const List<BoxShadow> _soft = [
  BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 8)),
  BoxShadow(color: Color(0x0F101828), blurRadius: 6, offset: Offset(0, 2)),
];

void _guidanceToast(BuildContext context, String message, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Badge doux (équivalent Aule de l'ancien SoftBadge Flow).
class _SoftBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;
  const _SoftBadge({
    required this.text,
    required this.color,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: hankenGrotesk(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Guidage pas à pas d'un itinéraire TC complet (marche, attente, trajet,
/// correspondances).
class ItineraryGuidancePage extends StatefulWidget {
  final String origin;
  final String destination;
  final TransitItinerary itinerary;

  const ItineraryGuidancePage({
    super.key,
    required this.origin,
    required this.destination,
    required this.itinerary,
  });

  @override
  State<ItineraryGuidancePage> createState() => _ItineraryGuidancePageState();
}

class _ItineraryGuidancePageState extends State<ItineraryGuidancePage>
    with SingleTickerProviderStateMixin {
  static const _fallbackPosition = LatLng(47.2184, -1.5536);

  GuidancePhase _phase = GuidancePhase.walkToStop;
  int _stepIndex = 0;
  LegGuidanceContext? _legContext;
  bool _loading = true;

  Timer? _ticker;
  int _waitMinutes = 0;
  late DateTime _estimatedArrival;
  bool _notificationsEnabled = false;
  bool _approachAlertShown = false;

  int _inTransitUserIdx = 0;
  int _minutesToNextStop = 2;
  late AnimationController _progressController;

  RouteStep get _currentStep => widget.itinerary.steps[_stepIndex];
  bool get _isLastStep => _stepIndex >= widget.itinerary.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _loadLegContext();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadLegContext() async {
    setState(() => _loading = true);
    final gtfs = context.read<GtfsService>();
    final location = context.read<LocationService>();
    final pos = location.currentPosition ?? await location.updateCurrentPosition();

    final ctx = await gtfs.resolveLegGuidance(
      _currentStep,
      near: pos == null ? null : LatLng(pos.latitude, pos.longitude),
    );

    if (!mounted) return;
    if (ctx == null) {
      _guidanceToast(
        context,
        'Impossible de démarrer le guidage pour cette étape.',
        icon: LucideIcons.circleAlert,
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _legContext = ctx;
      _waitMinutes = ctx.waitMinutes.clamp(1, 99);
      _estimatedArrival =
          DateTime.now().add(Duration(minutes: _waitMinutes));
      _inTransitUserIdx = 0;
      _minutesToNextStop = 2;
      _loading = false;
    });
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _loading) return;

    if (_phase == GuidancePhase.waiting) {
      setState(() {
        final elapsed = DateTime.now().difference(
          _estimatedArrival.subtract(Duration(minutes: _waitMinutes)),
        );
        final remainingSec =
            (_waitMinutes * 60 - elapsed.inSeconds).clamp(0, 9999);
        _waitMinutes = (remainingSec / 60).ceil().clamp(0, 99);
        if (_waitMinutes == 0) _waitMinutes = 1;
        _estimatedArrival = DateTime.now().add(Duration(seconds: remainingSec));
      });
      _checkApproach();
    } else if (_phase == GuidancePhase.inTransit) {
      // Simulation légère de progression entre arrêts.
      if (DateTime.now().second % 30 == 0) {
        setState(() {
          if (_minutesToNextStop > 0) _minutesToNextStop--;
          final stops = _inTransitStops(context.read<GtfsService>());
          if (_minutesToNextStop == 0 &&
              _inTransitUserIdx < stops.length - 1) {
            _inTransitUserIdx++;
            _minutesToNextStop = 3;
          }
        });
      }
    }
  }

  void _checkApproach() {
    if (_approachAlertShown || !_notificationsEnabled) return;
    if (_waitMinutes > 1 || _legContext == null) return;

    _approachAlertShown = true;
    HapticFeedback.mediumImpact();
    final ctx = _legContext!;
    final lineColor = _lineColor(ctx);
    final lineCode = ctx.route.routeShortName ?? ctx.route.routeId;

    ApproachAlertSheet.show(
      context,
      lineCode: lineCode,
      direction: ctx.headsign,
      stopName: ctx.boardingStop.stopName,
      lineColor: lineColor,
      onViewMap: () {},
    );
  }

  Color _lineColor(LegGuidanceContext ctx) =>
      AuleDataAdapter.routeColor(ctx.route) ?? const Color(0xFF16A34A);

  IconData _vehicleIcon(LegGuidanceContext ctx) {
    switch (ctx.route.transportType.toLowerCase()) {
      case 'tram':
        return LucideIcons.tramFront;
      default:
        return LucideIcons.bus;
    }
  }

  VehicleOccupancy _occupancy() {
    final h = DateTime.now().hour;
    if (h >= 7 && h <= 9 || h >= 17 && h <= 19) {
      return VehicleOccupancy.medium;
    }
    return VehicleOccupancy.low;
  }

  void _onAtStop() {
    HapticFeedback.lightImpact();
    setState(() => _phase = GuidancePhase.waiting);
  }

  void _onBoard() {
    if (_waitMinutes > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le véhicule n\'est pas encore arrivé — patientez quelques instants.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = GuidancePhase.inTransit;
      _inTransitUserIdx = 0;
      _minutesToNextStop = 2;
    });
  }

  void _onAlight() {
    HapticFeedback.heavyImpact();
    if (_isLastStep) {
      setState(() => _phase = GuidancePhase.arrived);
      _ticker?.cancel();
      return;
    }
    setState(() => _phase = GuidancePhase.transfer);
  }

  Future<void> _onContinueTransfer() async {
    setState(() {
      _stepIndex++;
      _phase = GuidancePhase.walkToStop;
      _approachAlertShown = false;
    });
    await _loadLegContext();
  }

  List<TimelineStop> _inTransitStops(GtfsService gtfs) {
    final ctx = _legContext;
    if (ctx == null) return const [];

    final allStops =
        gtfs.stopsToward(ctx.route, ctx.headsign, via: ctx.boardingStop);
    final boardIdx = allStops
        .indexWhere((s) => s.stopId == ctx.boardingStop.stopId);
    final alightIdx =
        allStops.indexWhere((s) => s.stopId == ctx.alightStop.stopId);
    if (boardIdx < 0 || alightIdx <= boardIdx) {
      return [
        TimelineStop(
          name: ctx.alightStop.stopName,
          arrivalTime: '${ctx.departure.waitMinutes} min',
          isAlight: true,
        ),
      ];
    }

    final slice = allStops.sublist(boardIdx, alightIdx + 1);
    return List.generate(slice.length, (i) {
      final offsetMin = i == 0 ? 0 : (i - _inTransitUserIdx).clamp(0, 99) * 3;
      return TimelineStop(
        name: slice[i].stopName,
        arrivalTime: i == 0 ? null : '$offsetMin min',
        isAlight: i == slice.length - 1,
      );
    });
  }

  /// Timeline d'approche pendant l'attente : quelques arrêts en amont de
  /// l'arrêt de montée, ce dernier marqué « vous êtes ici ». Renvoie aussi
  /// l'index de l'arrêt de montée dans la tranche.
  (List<TimelineStop>, int) _waitingStops(GtfsService gtfs) {
    final ctx = _legContext;
    if (ctx == null) return (const [], 0);

    final allStops =
        gtfs.stopsToward(ctx.route, ctx.headsign, via: ctx.boardingStop);
    var boardIdx =
        allStops.indexWhere((s) => s.stopId == ctx.boardingStop.stopId);
    if (boardIdx < 0) {
      boardIdx =
          allStops.indexWhere((s) => s.stopName == ctx.boardingStop.stopName);
    }
    if (boardIdx < 0) {
      return (
        [
          TimelineStop(
            name: ctx.boardingStop.stopName,
            arrivalTime: _formatTime(_estimatedArrival),
          ),
        ],
        0,
      );
    }

    // Timeline d'approche : arrêts en amont, l'arrêt de montée en dernière
    // ligne (« vous êtes ici », juste au-dessus du panneau d'actions). Si
    // l'arrêt est en début de ligne, on complète vers l'aval pour ~4 arrêts.
    final start = math.max(0, boardIdx - 3);
    var end = boardIdx + 1;
    if (end - start < 4) end = math.min(allStops.length, start + 4);
    final slice = allStops.sublist(start, end);
    final userIdx = boardIdx - start;

    final stops = List.generate(slice.length, (i) {
      // Avant l'arrêt de montée : pas d'heure (véhicule pas encore passé).
      // À partir de l'arrêt de montée : heures estimées (+3 min/arrêt).
      final arrival = _estimatedArrival.add(
        Duration(minutes: (i - userIdx).clamp(0, 99) * 3),
      );
      return TimelineStop(
        name: slice[i].stopName,
        arrivalTime: i >= userIdx ? _formatTime(arrival) : null,
      );
    });
    return (stops, userIdx);
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String? _nextStopName(GtfsService gtfs) {
    final stops = _inTransitStops(gtfs);
    final nextIdx = _inTransitUserIdx + 1;
    if (nextIdx >= stops.length) return null;
    return stops[nextIdx].name;
  }

  int? _alightStopIndex(GtfsService gtfs) {
    final stops = _inTransitStops(gtfs);
    for (var i = 0; i < stops.length; i++) {
      if (stops[i].isAlight) return i;
    }
    return stops.isEmpty ? null : stops.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _legContext == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _brand),
              const SizedBox(height: 16),
              Text(
                'Préparation du guidage…',
                style: hankenGrotesk(
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return switch (_phase) {
      GuidancePhase.arrived => _buildArrived(context),
      GuidancePhase.transfer => _buildTransfer(context),
      GuidancePhase.walkToStop => _buildWalk(context),
      GuidancePhase.waiting => _buildWaiting(context),
      GuidancePhase.inTransit => _buildInTransit(context),
    };
  }

  int _walkMinutes(double meters) =>
      (meters / 80).ceil().clamp(1, 99);

  Widget _buildWalk(BuildContext context) {
    final ctx = _legContext!;
    final lineColor = _lineColor(ctx);
    final location = context.watch<LocationService>();
    final pos = location.currentPosition;
    final userPos = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _fallbackPosition;
    final lineCode = ctx.route.routeShortName ?? ctx.route.routeId;
    final isFirstLeg = _stepIndex == 0;
    final walkMeters = ctx.boardingDistanceMeters;
    final walkMin = _walkMinutes(walkMeters);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AuleTheme(
      colors: AuleColors.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VehicleMapHeader(
              route: ctx.route,
              headsign: ctx.headsign,
              stop: ctx.boardingStop,
              userPosition: userPos,
              vehiclePosition: null,
              lineColor: lineColor,
              vehicleIcon: _vehicleIcon(ctx),
              walkingPath: true,
              heightFraction: 0.38,
              onBack: () => Navigator.pop(context),
              onFavoriteToggle: () {},
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GuidanceStepHeader(
                      stepIndex: _stepIndex,
                      totalSteps: widget.itinerary.steps.length,
                      origin: widget.origin,
                      destination: widget.destination,
                    ),
                    const SizedBox(height: 14),
                    _WalkInstructionCard(
                      isFirstLeg: isFirstLeg,
                      stopName: ctx.boardingStop.stopName,
                      instruction: _currentStep.instruction,
                      lineCode: lineCode,
                      lineColor: lineColor,
                      lineMode: AuleDataAdapter.modeFrom(ctx.route.transportType),
                      walkMeters: walkMeters,
                      walkMinutes: walkMin,
                    ),
                    if (widget.itinerary.steps.length > 1) ...[
                      const SizedBox(height: 14),
                      _ItineraryStepsPreview(
                        steps: widget.itinerary.steps,
                        currentIndex: _stepIndex,
                        lineColor: lineColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Appuyez quand vous êtes à l\'arrêt ${ctx.boardingStop.stopName}',
                    textAlign: TextAlign.center,
                    style: hankenGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrimaryGuidanceButton(
                    label: 'Je suis à l\'arrêt',
                    color: lineColor,
                    icon: LucideIcons.mapPin,
                    onTap: _onAtStop,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiting(BuildContext context) {
    final ctx = _legContext!;
    final lineColor = _lineColor(ctx);
    final gtfs = context.watch<GtfsService>();
    final location = context.watch<LocationService>();
    final pos = location.currentPosition;
    final userPos = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _fallbackPosition;
    final lineCode = ctx.route.routeShortName ?? ctx.route.routeId;
    final isApproaching = _waitMinutes <= 1;

    final vehiclePos = gtfs.projectVehicleOnRoute(
      ctx.route,
      ctx.boardingStop,
      ctx.headsign,
      (_waitMinutes * 60).toDouble(),
    );

    final (waitStops, waitUserIdx) = _waitingStops(gtfs);

    return AuleTheme(
      colors: AuleColors.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: VehicleMapHeader(
                    route: ctx.route,
                    headsign: ctx.headsign,
                    stop: ctx.boardingStop,
                    userPosition: userPos,
                    vehiclePosition: vehiclePos,
                    lineColor: lineColor,
                    vehicleIcon: _vehicleIcon(ctx),
                    isApproaching: isApproaching,
                    lineContextMeters: 520,
                    onBack: () => Navigator.pop(context),
                    onFavoriteToggle: () {},
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: VehicleInfoCard(
                      lineCode: lineCode,
                      lineColor: lineColor,
                      direction: ctx.headsign,
                      stopName: ctx.boardingStop.stopName,
                      waitMinutes: _waitMinutes,
                      estimatedArrival: _estimatedArrival,
                      occupancy: _occupancy(),
                      isApproaching: isApproaching,
                      vehicleIcon: _vehicleIcon(ctx),
                    ),
                  ),
                ),
                if (waitStops.length >= 2)
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: VehicleVerticalTimeline(
                        stops: waitStops,
                        userStopIndex: waitUserIdx,
                        vehicleBetweenIndex: math.max(0, waitUserIdx - 1),
                        lineColor: lineColor,
                        vehicleIcon: _vehicleIcon(ctx),
                        showVehicleOnTimeline: isApproaching,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
              child: VehicleActionButtons(
                lineColor: lineColor,
                notificationsEnabled: _notificationsEnabled,
                isArrived: isApproaching,
                waitMinutes: _waitMinutes,
                onToggleNotifications: () {
                  setState(() => _notificationsEnabled = !_notificationsEnabled);
                  if (_notificationsEnabled) _checkApproach();
                },
                onBoard: _onBoard,
                onShare: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInTransit(BuildContext context) {
    final ctx = _legContext!;
    final lineColor = _lineColor(ctx);
    final gtfs = context.watch<GtfsService>();
    final location = context.watch<LocationService>();
    final pos = location.currentPosition;
    final userPos = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _fallbackPosition;
    final lineCode = ctx.route.routeShortName ?? ctx.route.routeId;
    final stops = _inTransitStops(gtfs);
    final nextStop = _nextStopName(gtfs) ?? ctx.alightStop.stopName;
    final alightIdx = _alightStopIndex(gtfs);
    final safeUserIdx =
        _inTransitUserIdx.clamp(0, math.max(0, stops.length - 1)).toInt();

    final vehiclePos = gtfs.projectVehicleOnRoute(
      ctx.route,
      ctx.boardingStop,
      ctx.headsign,
      0,
    );

    return AuleTheme(
      colors: AuleColors.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF2A2824),
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.38,
                    child: VehicleMapHeader(
                      route: ctx.route,
                      headsign: ctx.headsign,
                      stop: ctx.alightStop,
                      userPosition: userPos,
                      vehiclePosition: vehiclePos,
                      lineColor: lineColor,
                      vehicleIcon: _vehicleIcon(ctx),
                      lineClipStart: ctx.boardingStop.position,
                      lineClipEnd: ctx.alightStop.position,
                      onBack: () => Navigator.pop(context),
                      onFavoriteToggle: () {},
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _InTransitBanner(
                        lineCode: lineCode,
                        lineColor: lineColor,
                        lineMode: AuleDataAdapter.modeFrom(ctx.route.transportType),
                        headsign: ctx.headsign,
                        nextStopName: nextStop,
                        minutesToNext: _minutesToNextStop,
                        vehicleIcon: _vehicleIcon(ctx),
                        progressController: _progressController,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                    child: VehicleVerticalTimeline(
                      stops: stops,
                      userStopIndex: safeUserIdx,
                      vehicleBetweenIndex: math.max(0, safeUserIdx - 1),
                      lineColor: lineColor,
                      vehicleIcon: _vehicleIcon(ctx),
                      alightStopIndex: alightIdx,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
              child: _PrimaryGuidanceButton(
                label: 'Je descends ici',
                color: const Color(0xFFD6453E),
                icon: LucideIcons.logOut,
                onTap: _onAlight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransfer(BuildContext context) {
    final ctx = _legContext!;
    final lineColor = _lineColor(ctx);
    final nextStep = widget.itinerary.steps[_stepIndex + 1];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconButton(
                alignment: Alignment.centerLeft,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.arrowLeft),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _brand, width: 2),
                  boxShadow: _soft,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SoftBadge(
                      text: 'CORRESPONDANCE',
                      icon: LucideIcons.arrowLeftRight,
                      color: _brand,
                      background: _brandWeak,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Descendez à ${ctx.alightStop.stopName}',
                      style: hankenGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Puis prenez ${nextStep.lineShortName} vers ${nextStep.arrivalStop}',
                      style: hankenGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              _PrimaryGuidanceButton(
                label: 'Continuer le guidage',
                color: lineColor,
                icon: LucideIcons.arrowRight,
                onTap: _onContinueTransfer,
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArrived(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: _soft,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: _greenSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.circleCheck,
                        size: 36,
                        color: _green,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Vous êtes arrivé !',
                      style: hankenGrotesk(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.destination,
                      textAlign: TextAlign.center,
                      style: hankenGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.itinerary.totalDurationMinutes} min · ${widget.itinerary.estimatedCost.toStringAsFixed(2)} €',
                      style: hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _faint,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              _PrimaryGuidanceButton(
                label: 'Terminer',
                color: _brand,
                icon: LucideIcons.check,
                onTap: () => Navigator.pop(context),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidanceStepHeader extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final String origin;
  final String destination;

  const _GuidanceStepHeader({
    required this.stepIndex,
    required this.totalSteps,
    required this.origin,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (stepIndex + 1) / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Étape ${stepIndex + 1} / $totalSteps',
              style: hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _brand,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()} %',
              style: hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _faint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: _line,
            color: _brand,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.navigation, size: 14, color: _brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  origin,
                  style: hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  LucideIcons.arrowRight,
                  size: 14,
                  color: _faint,
                ),
              ),
              Expanded(
                child: Text(
                  destination,
                  textAlign: TextAlign.end,
                  style: hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalkInstructionCard extends StatelessWidget {
  final bool isFirstLeg;
  final String stopName;
  final String instruction;
  final String lineCode;
  final Color lineColor;
  final AuleLineMode lineMode;
  final double walkMeters;
  final int walkMinutes;

  const _WalkInstructionCard({
    required this.isFirstLeg,
    required this.stopName,
    required this.instruction,
    required this.lineCode,
    required this.lineColor,
    required this.lineMode,
    required this.walkMeters,
    required this.walkMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final headline = isFirstLeg
        ? 'Marchez vers $stopName'
        : 'Correspondance — rendez-vous à $stopName';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EAF0)),
        boxShadow: _soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _brandWeak,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  LucideIcons.footprints,
                  size: 22,
                  color: _brand,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: hankenGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      instruction,
                      style: hankenGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4B5563),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                aule.LineBadge.large(
                  label: lineCode,
                  mode: lineMode,
                  color: lineColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ensuite, prenez la ligne $lineCode',
                    style: hankenGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (walkMeters > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _WalkMetricChip(
                  icon: LucideIcons.footprints,
                  label: '~${walkMeters.round()} m',
                  color: _brand,
                  background: _brandWeak,
                ),
                const SizedBox(width: 8),
                _WalkMetricChip(
                  icon: LucideIcons.clock3,
                  label: '~$walkMinutes min',
                  color: _green,
                  background: _greenSoft,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WalkMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _WalkMetricChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItineraryStepsPreview extends StatelessWidget {
  final List<RouteStep> steps;
  final int currentIndex;
  final Color lineColor;

  const _ItineraryStepsPreview({
    required this.steps,
    required this.currentIndex,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'APERÇU DU TRAJET',
            style: hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _StepPreviewRow(
              index: i,
              step: steps[i],
              isCurrent: i == currentIndex,
              isPast: i < currentIndex,
              lineColor: lineColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepPreviewRow extends StatelessWidget {
  final int index;
  final RouteStep step;
  final bool isCurrent;
  final bool isPast;
  final Color lineColor;

  const _StepPreviewRow({
    required this.index,
    required this.step,
    required this.isCurrent,
    required this.isPast,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final isWalk = step.lineType == 'walk';
    final dotColor = isPast
        ? _green
        : isCurrent
            ? lineColor
            : _faint;
    final textColor = isPast
        ? _faint
        : isCurrent
            ? _ink
            : _muted;
    final weight = isCurrent ? FontWeight.w800 : FontWeight.w600;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCurrent
                ? dotColor.withValues(alpha: 0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: isCurrent ? 2 : 1.5),
          ),
          alignment: Alignment.center,
          child: isPast
              ? Icon(LucideIcons.check, size: 12, color: dotColor)
              : Text(
                  '${index + 1}',
                  style: hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: dotColor,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Icon(
          isWalk ? LucideIcons.footprints : LucideIcons.bus,
          size: 14,
          color: textColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isWalk
                ? 'Marche vers ${step.departureStop}'
                : '${step.lineShortName} → ${step.arrivalStop}',
            style: hankenGrotesk(
              fontSize: 13,
              fontWeight: weight,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isCurrent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: lineColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'En cours',
              style: hankenGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: lineColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _InTransitBanner extends StatelessWidget {
  final String lineCode;
  final Color lineColor;
  final AuleLineMode lineMode;
  final String headsign;
  final String nextStopName;
  final int minutesToNext;
  final IconData vehicleIcon;
  final AnimationController progressController;

  const _InTransitBanner({
    required this.lineCode,
    required this.lineColor,
    required this.lineMode,
    required this.headsign,
    required this.nextStopName,
    required this.minutesToNext,
    required this.vehicleIcon,
    required this.progressController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brand, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              aule.LineBadge.large(
                label: lineCode,
                mode: lineMode,
                color: lineColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direction $headsign',
                      style: hankenGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'À bord · temps réel',
                      style: hankenGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROCHAIN ARRÊT',
                      style: hankenGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _muted,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      '$minutesToNext min',
                      style: hankenGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  nextStopName,
                  style: hankenGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 9),
                AnimatedBuilder(
                  animation: progressController,
                  builder: (context, _) {
                    final w = 0.45 + progressController.value * 0.25;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: w,
                        minHeight: 6,
                        backgroundColor: _line,
                        color: _brand,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryGuidanceButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryGuidanceButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 8,
      shadowColor: color.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
