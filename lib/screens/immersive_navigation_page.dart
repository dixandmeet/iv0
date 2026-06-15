import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../services/aule_data_adapter.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/premium_navigation_theme.dart';
import '../widgets/immersive_navigation/immersive_shared.dart';
import '../widgets/line_detail/line_detail_map_body.dart';

enum ImmersivePhase { approaching, imminent, onboard, disembarkAlert }

/// Navigation GPS immersive — vue carte 3D, arrivée, trajet embarqué et alerte descente.
class ImmersiveNavigationPage extends StatefulWidget {
  final GtfsRoute route;
  final String headsign;
  final NearbyStation station;
  final StationDeparture departure;

  const ImmersiveNavigationPage({
    super.key,
    required this.route,
    required this.headsign,
    required this.station,
    required this.departure,
  });

  @override
  State<ImmersiveNavigationPage> createState() =>
      _ImmersiveNavigationPageState();
}

class _ImmersiveNavigationPageState extends State<ImmersiveNavigationPage> {
  Timer? _ticker;
  Timer? _onboardTicker;

  bool _isFavorite = false;
  bool _alertsEnabled = false;
  bool _disembarkAlerts = true;
  bool _showDisembarkAlert = false;
  bool _onboardMapMode = false;

  ImmersivePhase _phase = ImmersivePhase.approaching;

  late int _remainingSeconds;
  late DateTime _estimatedArrival;

  int _onboardStopIndex = 0;
  int _minutesToNext = 2;

  // Centre de Nantes : repli quand la position GPS n'est pas encore connue.
  static const _fallbackPosition = LatLng(47.25156, -1.53026);

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.departure.waitMinutes * 60;
    _estimatedArrival =
        DateTime.now().add(Duration(seconds: _remainingSeconds));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tickApproach());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _onboardTicker?.cancel();
    super.dispose();
  }

  Color _lineColor() =>
      AuleDataAdapter.routeColor(widget.route) ??
      PremiumNavTheme.brand;

  String _lineCode() =>
      widget.route.routeShortName ?? widget.route.routeId;

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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

  /// Vraie carte de navigation : tuiles, tracé réel de la ligne, marqueurs
  /// véhicule/arrêt/position — façon GPS de voiture.
  Widget _buildNavMap(Color lineColor) {
    final gtfs = context.watch<GtfsService>();
    final location = context.watch<LocationService>();
    final pos = location.currentPosition;
    final userPos = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _fallbackPosition;
    final vehiclePos = gtfs.projectVehicleOnRoute(
      widget.route,
      widget.station.stop,
      widget.headsign,
      _remainingSeconds.toDouble(),
    );
    return LineDetailMapBody(
      route: widget.route,
      headsign: widget.headsign,
      stop: widget.station.stop,
      userPosition: userPos,
      vehiclePosition: vehiclePos,
      lineColor: lineColor,
      waitMinutes: (_remainingSeconds / 60).ceil(),
      vehicleIcon: _vehicleIcon(widget.route.transportType),
      showControls: false,
    );
  }

  bool get _isApproaching => _remainingSeconds <= 60;
  bool get _isArrived => _remainingSeconds <= 0;

  List<GtfsStop> _stopsAhead(GtfsService gtfs) {
    final all = gtfs.stopsToward(
      widget.route,
      widget.headsign,
      via: widget.station.stop,
    );
    var idx = all.indexWhere((s) => s.stopId == widget.station.stop.stopId);
    if (idx < 0) {
      idx = all.indexWhere((s) => s.stopName == widget.station.stop.stopName);
    }
    if (idx < 0) return [widget.station.stop];
    return all.sublist(idx);
  }

  int _stopsBeforeDestination(GtfsService gtfs) {
    final ahead = _stopsAhead(gtfs);
    return math.max(0, ahead.length - 1);
  }

  List<(String, String)> _upcomingStops(GtfsService gtfs) {
    final ahead = _stopsAhead(gtfs);
    final start = math.min(_onboardStopIndex + 1, ahead.length - 1);
    final slice = ahead.sublist(start, math.min(start + 3, ahead.length));
    final now = DateTime.now();

    return slice.map((s) {
      final mins = (slice.indexOf(s) + 1) * 3;
      final t = now.add(Duration(minutes: mins));
      return (s.stopName, _formatTime(t));
    }).toList();
  }

  String _nextOnboardStop(GtfsService gtfs) {
    final ahead = _stopsAhead(gtfs);
    final idx = math.min(_onboardStopIndex + 1, ahead.length - 1);
    return ahead[idx].stopName;
  }

  void _tickApproach() {
    if (!mounted || _phase == ImmersivePhase.onboard) return;

    setState(() {
      _remainingSeconds = math.max(0, _remainingSeconds - 1);
      _estimatedArrival = DateTime.now().add(
        Duration(seconds: _remainingSeconds),
      );

      if (_remainingSeconds <= 10) {
        _phase = ImmersivePhase.imminent;
      } else {
        _phase = ImmersivePhase.approaching;
      }
    });
  }

  void _startOnboardTicker() {
    _onboardTicker?.cancel();
    _onboardTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() {
        if (_minutesToNext > 0) _minutesToNext--;
        if (_minutesToNext <= 0) {
          _onboardStopIndex++;
          _minutesToNext = 3;
        }

        final gtfs = context.read<GtfsService>();
        final remaining = _stopsBeforeDestination(gtfs) - _onboardStopIndex;
        if (_disembarkAlerts && remaining == 1 && !_showDisembarkAlert) {
          _showDisembarkAlert = true;
          _phase = ImmersivePhase.disembarkAlert;
          HapticFeedback.heavyImpact();
        }
      });
    });
  }

  void _toggleAlerts() {
    setState(() => _alertsEnabled = !_alertsEnabled);
    if (_alertsEnabled && _isApproaching) {
      HapticFeedback.mediumImpact();
    }
  }

  void _onBoard() {
    if (!_isArrived && _remainingSeconds > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Votre tram n\'est pas encore arrivé — suivez-le en temps réel.',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _phase = ImmersivePhase.onboard;
      _onboardStopIndex = 0;
      _minutesToNext = 2;
      _showDisembarkAlert = false;
    });
    _startOnboardTicker();
  }

  void _onDisembark() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Trajet terminé — bonne continuation !',
          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PremiumNavTheme.brand,
      ),
    );
  }

  void _dismissDisembarkAlert() {
    setState(() {
      _showDisembarkAlert = false;
      _phase = ImmersivePhase.onboard;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gtfs = context.watch<GtfsService>();
    final lineColor = _lineColor();
    final lineCode = _lineCode();
    final stopsBeforeDest = _stopsBeforeDestination(gtfs);

    return Scaffold(
      backgroundColor: PremiumNavTheme.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_phase == ImmersivePhase.onboard)
            _buildOnboardBody(gtfs, lineColor, lineCode, stopsBeforeDest)
          else
            _buildApproachBody(lineColor, lineCode, stopsBeforeDest),

          if (_showDisembarkAlert)
            DisembarkAlertOverlay(
              onDisembark: () {
                _dismissDisembarkAlert();
                _onDisembark();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildApproachBody(
    Color lineColor,
    String lineCode,
    int stopsBeforeDest,
  ) {
    final isImminent = _phase == ImmersivePhase.imminent;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildNavMap(lineColor),

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ImmersiveTopBar(
                lineCode: lineCode,
                lineColor: lineColor,
                direction: widget.headsign,
                isFavorite: _isFavorite,
                onBack: () => Navigator.pop(context),
                onFavorite: () =>
                    setState(() => _isFavorite = !_isFavorite),
              ),
              const Spacer(),
            ],
          ),
        ),

        if (!isImminent)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 56,
            right: 16,
            child: ImmersiveEtaCard(
              remainingSeconds: _remainingSeconds,
              isApproaching: _isApproaching,
            ),
          ),

        if (isImminent) ...[
          Positioned(
            top: MediaQuery.paddingOf(context).top + 56,
            left: 0,
            right: 0,
            child: Center(
              child: ImmersiveArrivalCountdown(seconds: _remainingSeconds),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 160,
            left: 16,
            right: 16,
            child: const ImmersivePrepareCard(),
          ),
        ],

        if (!isImminent)
          Positioned(
            left: 16,
            right: 16,
            bottom: 340,
            child: ImmersiveManeuverCard(
              stopName: widget.station.stop.stopName,
              distanceMeters:
                  widget.station.distanceMeters.round().clamp(50, 500),
            ),
          ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ImmersiveBottomPanel(
            nextStop: widget.station.stop.stopName,
            estimatedArrival: _formatTime(_estimatedArrival),
            destinationInfo:
                '$stopsBeforeDest arrêts avant votre destination',
            alertsEnabled: _alertsEnabled,
            isArrived: _isArrived,
            waitMinutes: (_remainingSeconds / 60).ceil(),
            onToggleAlerts: _toggleAlerts,
            onBoard: _onBoard,
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardBody(
    GtfsService gtfs,
    Color lineColor,
    String lineCode,
    int stopsBeforeDest,
  ) {
    final remaining = math.max(0, stopsBeforeDest - _onboardStopIndex);
    final upcoming = _upcomingStops(gtfs);

    if (_onboardMapMode) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildNavMap(lineColor),
          SafeArea(
            child: Column(
              children: [
                ImmersiveTopBar(
                  lineCode: lineCode,
                  lineColor: lineColor,
                  direction: widget.headsign,
                  isFavorite: _isFavorite,
                  onBack: () => Navigator.pop(context),
                  onFavorite: () =>
                      setState(() => _isFavorite = !_isFavorite),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 60,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PremiumNavTheme.radiusSm),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  color: PremiumNavTheme.surface.withValues(alpha: 0.94),
                  child: Text(
                    'Reste $remaining arrêt${remaining > 1 ? 's' : ''} avant votre destination',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: PremiumNavTheme.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_disembarkAlerts)
            Positioned(
              left: 16,
              right: 16,
              bottom: 200,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PremiumNavTheme.brandLight,
                  borderRadius:
                      BorderRadius.circular(PremiumNavTheme.radiusSm),
                  border: Border.all(
                    color: PremiumNavTheme.brand.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.bellRing,
                      size: 18,
                      color: PremiumNavTheme.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Alertes de descente activées · Notification sonore',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PremiumNavTheme.brandDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ImmersiveBottomPanel(
              nextStop: _nextOnboardStop(gtfs),
              estimatedArrival: _formatTime(
                DateTime.now().add(Duration(minutes: remaining * 3)),
              ),
              destinationInfo: widget.headsign,
              alertsEnabled: _disembarkAlerts,
              isArrived: false,
              waitMinutes: 0,
              onToggleAlerts: () =>
                  setState(() => _disembarkAlerts = !_disembarkAlerts),
              onBoard: _onDisembark,
              primaryLabel: 'Je suis descendu',
              primarySubtitle: null,
            ),
          ),
          Positioned(
            right: 16,
            bottom: 260,
            child: Material(
              color: PremiumNavTheme.surface,
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => setState(() => _onboardMapMode = false),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    'Vue trajet',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: PremiumNavTheme.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(
              children: [
                _NavCircle(
                  icon: LucideIcons.arrowLeft,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                _NavCircle(
                  icon: LucideIcons.map,
                  onTap: () => setState(() => _onboardMapMode = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: PremiumNavTheme.brandLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.circleCheck,
                          size: 16,
                          color: PremiumNavTheme.brand,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Trajet démarré',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: PremiumNavTheme.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: PremiumNavTheme.surface,
                      borderRadius:
                          BorderRadius.circular(PremiumNavTheme.radiusLg),
                      boxShadow: PremiumNavTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: lineColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Ligne $lineCode',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Direction ${widget.headsign}',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: PremiumNavTheme.text,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TripProgressBar(
                          currentIndex: _onboardStopIndex,
                          totalStops: math.min(stopsBeforeDest, 5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: PremiumNavTheme.surface,
                      borderRadius:
                          BorderRadius.circular(PremiumNavTheme.radiusLg),
                      boxShadow: PremiumNavTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROCHAIN ARRÊT',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PremiumNavTheme.muted,
                            letterSpacing: 0.06,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _nextOnboardStop(gtfs),
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: PremiumNavTheme.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Arrivée dans $_minutesToNext min',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PremiumNavTheme.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (upcoming.isNotEmpty)
                    TripStopsList(stops: upcoming),
                  const SizedBox(height: 16),
                  if (_disembarkAlerts)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PremiumNavTheme.brandLight,
                        borderRadius:
                            BorderRadius.circular(PremiumNavTheme.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.bellRing,
                            size: 18,
                            color: PremiumNavTheme.brand,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Alertes de descente activées',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: PremiumNavTheme.brandDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: Material(
              color: PremiumNavTheme.brand,
              elevation: 6,
              shadowColor: PremiumNavTheme.brand.withValues(alpha: 0.35),
              borderRadius:
                  BorderRadius.circular(PremiumNavTheme.radiusMd),
              child: InkWell(
                onTap: _onDisembark,
                borderRadius:
                    BorderRadius.circular(PremiumNavTheme.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Je suis descendu',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PremiumNavTheme.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: PremiumNavTheme.text),
        ),
      ),
    );
  }
}
