import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/aule_data_adapter.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../theme/aule_theme.dart';
import '../theme/flow_theme.dart';
import 'itinerary_guidance_page.dart';
import '../widgets/aule/line_badge.dart' as aule;
import '../widgets/flow_primitives.dart';
import '../widgets/flow_widgets.dart';

enum _SortCriteria { fastest, lessWalking, direct }

class RouteResultScreen extends StatefulWidget {
  final String origin;
  final String destination;
  final List<TransitItinerary> itineraries;

  const RouteResultScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.itineraries,
  });

  @override
  State<RouteResultScreen> createState() => _RouteResultScreenState();
}

class _RouteResultScreenState extends State<RouteResultScreen> {
  late String _origin;
  late String _destination;
  late List<TransitItinerary> _itineraries;
  _SortCriteria _criteria = _SortCriteria.fastest;
  int? _expandedIndex;
  bool _swapping = false;

  @override
  void initState() {
    super.initState();
    _origin = widget.origin;
    _destination = widget.destination;
    _itineraries = List.of(widget.itineraries);
    _expandedIndex = _displayedItineraries.isNotEmpty ? 0 : null;
  }

  List<TransitItinerary> get _displayedItineraries {
    var list = List<TransitItinerary>.from(_itineraries);
    if (_criteria == _SortCriteria.direct) {
      list = list.where(_isDirect).toList();
    }
    list.sort((a, b) {
      switch (_criteria) {
        case _SortCriteria.fastest:
          return _byArrival(a, b);
        case _SortCriteria.lessWalking:
          final walkCmp = _walkScore(a).compareTo(_walkScore(b));
          return walkCmp != 0 ? walkCmp : _byArrival(a, b);
        case _SortCriteria.direct:
          return _byArrival(a, b);
      }
    });
    return list;
  }

  int _walkScore(TransitItinerary it) {
    final explicit =
        it.steps.where((s) => s.lineType == 'walk').fold<int>(0, (a, s) => a + s.durationMinutes);
    final transfers = _transferCount(it);
    return explicit + transfers * 3;
  }

  int _transferCount(TransitItinerary it) {
    final legs = it.steps.where((s) => s.lineType != 'walk').length;
    return legs <= 1 ? 0 : legs - 1;
  }

  bool _isDirect(TransitItinerary it) => _transferCount(it) == 0;

  /// « Le plus rapide » honnête : d'abord les options réellement en service,
  /// puis par heure d'arrivée réelle (repli sur la durée estimée).
  int _byArrival(TransitItinerary a, TransitItinerary b) {
    if (a.serviceLater != b.serviceLater) return a.serviceLater ? 1 : -1;
    final aa = a.arrivalTime;
    final ba = b.arrivalTime;
    if (aa != null && ba != null) return aa.compareTo(ba);
    return a.totalDurationMinutes.compareTo(b.totalDurationMinutes);
  }

  Future<void> _swapEndpoints() async {
    if (_swapping) return;
    final newOrigin = _destination;
    final newDest = _origin;
    setState(() {
      _swapping = true;
      _origin = newOrigin;
      _destination = newDest;
      _expandedIndex = 0;
    });

    final gtfs = context.read<GtfsService>();
    final location = context.read<LocationService>();
    try {
      final pos = location.currentPosition ?? await location.updateCurrentPosition();
      final results = await gtfs.searchItinerary(
        newOrigin,
        newDest,
        userPosition: pos == null ? null : LatLng(pos.latitude, pos.longitude),
      );
      if (!mounted) return;
      setState(() {
        _itineraries = results;
        _expandedIndex = results.isNotEmpty ? 0 : null;
        _swapping = false;
      });
      if (results.isEmpty) {
        showFlowToast(context, 'Aucun itinéraire trouvé pour ce trajet.',
            icon: LucideIcons.circleAlert);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _swapping = false);
      showFlowToast(context, 'Erreur lors du calcul', icon: LucideIcons.triangleAlert);
    }
  }

  void _selectCriteria(_SortCriteria criteria) {
    if (_criteria == criteria) return;
    setState(() {
      _criteria = criteria;
      _expandedIndex = _displayedItineraries.isNotEmpty ? 0 : null;
    });
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  void _openGuidance(TransitItinerary itinerary) {
    Navigator.push(
      context,
      FlowPageRoute(
        page: ItineraryGuidancePage(
          origin: _origin,
          destination: _destination,
          itinerary: itinerary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayedItineraries;
    final fastestMin =
        displayed.isEmpty ? null : displayed.first.totalDurationMinutes;

    return Scaffold(
      backgroundColor: FlowColors.fill,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OriginDestinationHeader(
              origin: _origin,
              destination: _destination,
              swapping: _swapping,
              onSwap: _swapEndpoints,
            ),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  _CriteriaChip(
                    label: 'Le plus rapide',
                    icon: LucideIcons.zap,
                    active: _criteria == _SortCriteria.fastest,
                    onTap: () => _selectCriteria(_SortCriteria.fastest),
                  ),
                  const SizedBox(width: 8),
                  _CriteriaChip(
                    label: 'Moins de marche',
                    icon: LucideIcons.footprints,
                    active: _criteria == _SortCriteria.lessWalking,
                    onTap: () => _selectCriteria(_SortCriteria.lessWalking),
                  ),
                  const SizedBox(width: 8),
                  _CriteriaChip(
                    label: 'Direct',
                    active: _criteria == _SortCriteria.direct,
                    onTap: () => _selectCriteria(_SortCriteria.direct),
                  ),
                ],
              ),
            ),
            if (displayed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  '${displayed.length} itinéraire${displayed.length > 1 ? 's' : ''}'
                  '${fastestMin != null ? ' · dès $fastestMin min' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: FlowColors.g2,
                  ),
                ),
              ),
            Expanded(
              child: _swapping
                  ? const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: FlowColors.blue,
                        ),
                      ),
                    )
                  : displayed.isEmpty
                      ? _EmptyResults(criteria: _criteria)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: displayed.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final it = displayed[index];
                            final bestMin = displayed.first.totalDurationMinutes;
                            return _ItineraryCard(
                              itinerary: it,
                              isBest: index == 0,
                              expanded: _expandedIndex == index,
                              crowd: [CrowdLevel.mid, CrowdLevel.low, CrowdLevel.high][index % 3],
                              transferCount: _transferCount(it),
                              walkScore: _walkScore(it),
                              deltaMinutes: it.totalDurationMinutes - bestMin,
                              onTap: () => _openGuidance(it),
                              onExpand: () => _toggleExpanded(index),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final _SortCriteria criteria;
  const _EmptyResults({required this.criteria});

  @override
  Widget build(BuildContext context) {
    final message = criteria == _SortCriteria.direct
        ? 'Aucun trajet direct disponible.\nEssayez un autre critère.'
        : 'Aucun itinéraire ne correspond à ce critère.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.route, size: 40, color: FlowColors.gWeak),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FlowColors.g2,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginDestinationHeader extends StatelessWidget {
  final String origin;
  final String destination;
  final bool swapping;
  final VoidCallback onSwap;

  const _OriginDestinationHeader({
    required this.origin,
    required this.destination,
    required this.swapping,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FlowColors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          FlowIconButton(icon: LucideIcons.arrowLeft, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EndpointRow(
                  icon: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: FlowColors.gWeak, width: 2.5),
                    ),
                  ),
                  label: origin,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    height: 10,
                    child: VerticalDivider(width: 2, color: FlowColors.line),
                  ),
                ),
                _EndpointRow(
                  icon: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: FlowColors.blue,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  label: destination,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FlowIconButton(
            icon: swapping ? LucideIcons.loader : LucideIcons.arrowUpDown,
            onTap: swapping ? () {} : onSwap,
          ),
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool bold;

  const _EndpointRow({
    required this.icon,
    required this.label,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: FlowText.rowTitle.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CriteriaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _CriteriaChip({
    required this.label,
    this.icon,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? FlowColors.blue : FlowColors.g2;
    return FlowTappable(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? FlowColors.blueSoft : FlowColors.white,
          borderRadius: BorderRadius.circular(12),
          border: active ? null : Border.all(color: FlowColors.line),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

AuleLineMode _modeFromType(String type) {
  switch (type.toLowerCase()) {
    case 'tram':
      return AuleLineMode.tram;
    case 'busway':
      return AuleLineMode.busway;
    default:
      return AuleLineMode.bus;
  }
}

Color _stepColor(RouteStep step, GtfsService gtfs, MapService mapHelper) {
  for (final route in gtfs.cachedRoutes) {
    final code = route.routeShortName ?? route.routeId;
    if (code == step.lineShortName) {
      return AuleDataAdapter.routeColor(route) ??
          mapHelper.getTransportColor(step.lineType);
    }
  }
  return AuleLineColors.forLine(step.lineShortName);
}

class _ItineraryCard extends StatelessWidget {
  final TransitItinerary itinerary;
  final bool isBest;
  final bool expanded;
  final CrowdLevel crowd;
  final int transferCount;
  final int walkScore;
  final int deltaMinutes;
  final VoidCallback onTap;
  final VoidCallback onExpand;

  const _ItineraryCard({
    required this.itinerary,
    required this.isBest,
    required this.expanded,
    required this.crowd,
    required this.transferCount,
    required this.walkScore,
    required this.deltaMinutes,
    required this.onTap,
    required this.onExpand,
  });

  Color _accentColor(GtfsService gtfs, MapService mapHelper) {
    for (final step in itinerary.steps) {
      if (step.lineType != 'walk') {
        return _stepColor(step, gtfs, mapHelper);
      }
    }
    return FlowColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final mapHelper = Provider.of<MapService>(context);
    final gtfs = Provider.of<GtfsService>(context, listen: false);
    final it = itinerary;
    final accent = _accentColor(gtfs, mapHelper);
    // Heures réelles (prochain passage théorique) quand elles existent, sinon
    // repli « maintenant + durée estimée ».
    final now = DateTime.now();
    final departTime = it.departureTime ?? now;
    final arriveTime =
        it.arrivalTime ?? now.add(Duration(minutes: it.totalDurationMinutes));
    final arrival = DateFormat('HH:mm').format(arriveTime);
    final depart = DateFormat('HH:mm').format(departTime);
    final originStop = it.steps.first.departureStop;
    final destStop = it.steps.last.arrivalStop;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: FlowColors.white,
        borderRadius: BorderRadius.circular(FlowTokens.rCardXl),
        border: Border.all(
          color: isBest ? accent.withValues(alpha: 0.45) : FlowColors.line,
          width: isBest ? 1.5 : 1,
        ),
        boxShadow: isBest
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : FlowTokens.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: FlowTappable(
        onTap: onTap,
        pressedScale: 0.988,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              color: isBest ? accent : FlowColors.line,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, expanded ? 16 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isBest)
                              const SoftBadge(
                                text: 'LE PLUS RAPIDE',
                                icon: LucideIcons.zap,
                                color: FlowColors.blue,
                                background: FlowColors.blueSoft,
                              )
                            else ...[
                              const SectionLabel('Alternative'),
                              if (deltaMinutes > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '+$deltaMinutes min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: accent.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      _ArrivalPill(depart: depart, arrival: arrival, accent: accent),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onExpand,
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: FlowColors.fill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LucideIcons.chevronDown,
                              size: 16,
                              color: FlowColors.g2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${it.totalDurationMinutes}',
                            style: FlowText.bigNumber.copyWith(fontSize: 34, height: 0.95),
                          ),
                          const SizedBox(width: 4),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 3),
                            child: Text(
                              'min',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: FlowColors.g2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _LegsRow(
                          itinerary: it,
                          gtfs: gtfs,
                          mapHelper: mapHelper,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RouteSegmentBar(
                    itinerary: it,
                    gtfs: gtfs,
                    mapHelper: mapHelper,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 13, color: FlowColors.gWeak),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '$originStop  →  $destStop',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: FlowColors.g2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MetaPill(
                        icon: null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CrowdBars(level: crowd),
                            const SizedBox(width: 5),
                            Text(
                              crowdLabel(crowd),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: switch (crowd) {
                                  CrowdLevel.low => FlowColors.green,
                                  CrowdLevel.mid => FlowColors.orange,
                                  CrowdLevel.high => FlowColors.red,
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      _MetaPill(
                        icon: transferCount == 0 ? LucideIcons.circleCheck : LucideIcons.gitCompare,
                        label: transferCount == 0 ? 'Direct' : '$transferCount corresp.',
                      ),
                      if (walkScore > 0)
                        _MetaPill(
                          icon: LucideIcons.footprints,
                          label: '~$walkScore min',
                        ),
                      _MetaPill(
                        icon: LucideIcons.ticket,
                        label: '${it.estimatedCost.toStringAsFixed(2).replaceAll('.', ',')} €',
                        emphasized: true,
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    sizeCurve: Curves.easeOutCubic,
                    crossFadeState:
                        expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: _StepDetails(
                      itinerary: it,
                      mapHelper: mapHelper,
                      gtfs: gtfs,
                    ),
                    secondChild: const SizedBox(width: double.infinity),
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

class _ArrivalPill extends StatelessWidget {
  final String depart;
  final String arrival;
  final Color accent;

  const _ArrivalPill({
    required this.depart,
    required this.arrival,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Départ $depart',
            style: const TextStyle(
              fontSize: 10,
              color: FlowColors.gWeak,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            arrival,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSegmentBar extends StatelessWidget {
  final TransitItinerary itinerary;
  final GtfsService gtfs;
  final MapService mapHelper;

  const _RouteSegmentBar({
    required this.itinerary,
    required this.gtfs,
    required this.mapHelper,
  });

  @override
  Widget build(BuildContext context) {
    final total = itinerary.totalDurationMinutes.clamp(1, 999);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            for (var i = 0; i < itinerary.steps.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: itinerary.steps[i].durationMinutes.clamp(1, total),
                child: Container(
                  color: itinerary.steps[i].lineType == 'walk'
                      ? FlowColors.fill2
                      : _stepColor(itinerary.steps[i], gtfs, mapHelper),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final Widget? child;
  final bool emphasized;

  const _MetaPill({
    this.icon,
    this.label,
    this.child,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized ? FlowColors.fill2 : FlowColors.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: emphasized ? FlowColors.line : FlowColors.fill2,
        ),
      ),
      child: child ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: emphasized ? FlowColors.ink : FlowColors.g2),
                const SizedBox(width: 4),
              ],
              Text(
                label ?? '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                  color: emphasized ? FlowColors.ink : FlowColors.g2,
                ),
              ),
            ],
          ),
    );
  }
}

class _LegsRow extends StatelessWidget {
  final TransitItinerary itinerary;
  final MapService mapHelper;
  final GtfsService gtfs;

  const _LegsRow({
    required this.itinerary,
    required this.mapHelper,
    required this.gtfs,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    final transitSteps =
        itinerary.steps.where((s) => s.lineType != 'walk').toList();

    for (var i = 0; i < transitSteps.length; i++) {
      final step = transitSteps[i];
      widgets.add(
        aule.LineBadge.medium(
          label: step.lineShortName,
          mode: _modeFromType(step.lineType),
          color: _stepColor(step, gtfs, mapHelper),
        ),
      );
      if (i < transitSteps.length - 1) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Icon(LucideIcons.chevronRight, size: 14, color: FlowColors.gWeak),
        ));
      }
    }

    return Align(
      alignment: Alignment.centerRight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: widgets),
      ),
    );
  }
}

class _StepDetails extends StatelessWidget {
  final TransitItinerary itinerary;
  final MapService mapHelper;
  final GtfsService gtfs;

  const _StepDetails({
    required this.itinerary,
    required this.mapHelper,
    required this.gtfs,
  });

  @override
  Widget build(BuildContext context) {
    final steps = itinerary.steps;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0 && steps[i - 1].lineType != 'walk' && steps[i].lineType != 'walk')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: FlowColors.blueSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.arrowLeftRight, size: 11, color: FlowColors.blue),
                          SizedBox(width: 4),
                          Text(
                            'Correspondance',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: FlowColors.blue,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 8),
              child: _StepTile(
                step: steps[i],
                mapHelper: mapHelper,
                gtfs: gtfs,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final RouteStep step;
  final MapService mapHelper;
  final GtfsService gtfs;

  const _StepTile({
    required this.step,
    required this.mapHelper,
    required this.gtfs,
  });

  @override
  Widget build(BuildContext context) {
    final isWalk = step.lineType == 'walk';
    final color = isWalk ? FlowColors.g2 : _stepColor(step, gtfs, mapHelper);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlowColors.fill,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWalk)
            aule.LineBadge.small(
              label: step.lineShortName,
              mode: _modeFromType(step.lineType),
              color: color,
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: FlowColors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: FlowColors.line),
              ),
              child: const Icon(LucideIcons.footprints, size: 14, color: FlowColors.ink),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: FlowText.rowTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${step.departureStop} → ${step.arrivalStop}',
                  style: FlowText.rowSub,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: FlowColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${step.durationMinutes} min',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: FlowColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
