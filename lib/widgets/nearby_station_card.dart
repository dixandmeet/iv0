import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/gtfs.dart';
import '../services/gtfs_service.dart';
import '../services/map_service.dart';
import '../theme/flow_theme.dart';
import 'flow_primitives.dart';
import 'flow_widgets.dart';

/// Tap sur une direction d'une ligne (pour localiser/suivre le véhicule).
typedef DirectionTapCallback = void Function(
    GtfsRoute route, NearbyStation station, StationDeparture departure);

/// Distinction de pertinence affichée en haut de carte (un seul badge par
/// station). Calculée par [assignRelevance].
enum StationBadge { recommended, fastest, nearest, frequent }

extension StationBadgeStyle on StationBadge {
  String get label => switch (this) {
        StationBadge.recommended => 'Recommandé',
        StationBadge.fastest => 'Le plus rapide',
        StationBadge.nearest => 'Le plus proche',
        StationBadge.frequent => 'Le plus fréquent',
      };

  Color get color => switch (this) {
        StationBadge.recommended => FlowColors.blue,
        StationBadge.fastest => FlowColors.green,
        StationBadge.nearest => FlowColors.blue,
        StationBadge.frequent => FlowColors.orange,
      };

  Color get background => switch (this) {
        StationBadge.recommended => FlowColors.blueSoft,
        StationBadge.fastest => FlowColors.greenSoft,
        StationBadge.nearest => FlowColors.blueSoft,
        StationBadge.frequent => FlowColors.orangeSoft,
      };
}

/// Attribue au plus un badge de pertinence par station (par index) à partir
/// de la liste des stations (déjà triées par distance) et de leurs lignes.
/// Station #0 = « Recommandé », puis « Le plus rapide » (départ le plus
/// proche) et « Le plus fréquent » (plus grand nombre de lignes).
Map<int, StationBadge> assignRelevance(
  List<NearbyStation> stations,
  List<List<StationLineGroup>> groupsPerStation,
) {
  final result = <int, StationBadge>{};
  if (stations.isEmpty) return result;

  result[0] = StationBadge.recommended;

  int soonest(int i) {
    final groups = groupsPerStation[i];
    if (groups.isEmpty) return 9999;
    return groups.map((g) => g.soonestWait).reduce((a, b) => a < b ? a : b);
  }

  // Le plus rapide (hors station déjà recommandée).
  int? fastestIdx;
  int fastestWait = 9999;
  for (var i = 1; i < stations.length; i++) {
    final w = soonest(i);
    if (w < fastestWait) {
      fastestWait = w;
      fastestIdx = i;
    }
  }
  if (fastestIdx != null) result[fastestIdx] = StationBadge.fastest;

  // Le plus fréquent (plus de lignes), parmi les stations non encore badgées.
  int? freqIdx;
  int maxLines = -1;
  for (var i = 1; i < stations.length; i++) {
    if (result.containsKey(i)) continue;
    final c = groupsPerStation[i].length;
    if (c > maxLines) {
      maxLines = c;
      freqIdx = i;
    }
  }
  if (freqIdx != null && maxLines >= 3) {
    result[freqIdx] = StationBadge.frequent;
  }

  return result;
}

/// Carte premium d'une station proche : en-tête (nom + badge + guidage),
/// méta (distance / marche / PMR) et départs regroupés par ligne.
class NearbyStationCard extends StatefulWidget {
  final NearbyStation station;
  final List<StationLineGroup> groups;
  final MapService mapHelper;
  final StationBadge? badge;
  final bool showDistance;
  final VoidCallback onTap;
  final DirectionTapCallback? onDirectionTap;

  const NearbyStationCard({
    super.key,
    required this.station,
    required this.groups,
    required this.mapHelper,
    required this.onTap,
    this.badge,
    this.showDistance = true,
    this.onDirectionTap,
  });

  /// Nombre de lignes visibles avant repli (carte compacte ~180px).
  static const int _maxVisible = 3;

  @override
  State<NearbyStationCard> createState() => _NearbyStationCardState();
}

class _NearbyStationCardState extends State<NearbyStationCard> {
  bool _expanded = false;

  String get _meta {
    if (!widget.showDistance) {
      final n = widget.station.routes.length;
      return '$n ligne${n > 1 ? 's' : ''}';
    }
    final meters = widget.station.distanceMeters;
    final distance = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
    // ~75 m/min : vitesse de marche prudente en ville.
    final walk = (meters / 75).ceil();
    return '$distance · $walk min à pied';
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    final showAll = _expanded || groups.length <= NearbyStationCard._maxVisible;
    final visible =
        showAll ? groups : groups.take(NearbyStationCard._maxVisible).toList();
    final hidden = groups.length - visible.length;

    return FlowTappable(
      onTap: widget.onTap,
      pressedScale: 0.985,
      child: Container(
        decoration: BoxDecoration(
          color: FlowColors.white,
          borderRadius: BorderRadius.circular(FlowTokens.rCardXl),
          boxShadow: FlowTokens.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 6),
              _metaRow(),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 9),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: FlowColors.line,
                          ),
                        ),
                      _lineRow(visible[i]),
                    ],
                  ],
                ),
              ),
              if (hidden > 0 || _expanded && groups.length > NearbyStationCard._maxVisible)
                _expandToggle(hidden),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineRow(StationLineGroup group) {
    return StationLineRow(
      group: group,
      color: widget.mapHelper.getTransportColor(
        group.route.transportType,
        routeColorHex: group.route.routeColor,
      ),
      onDirectionTap: widget.onDirectionTap == null
          ? null
          : (dep) => widget.onDirectionTap!(group.route, widget.station, dep),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  widget.station.stop.stopName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: FlowColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.badge != null) ...[
                const SizedBox(width: 8),
                RelevanceBadge(badge: widget.badge!),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        const IconTile(
          icon: LucideIcons.navigation,
          background: FlowColors.blueSoft,
          iconColor: FlowColors.blue,
          size: 34,
        ),
      ],
    );
  }

  Widget _metaRow() {
    final accessible = widget.station.stop.isWheelchairAccessible;
    return Row(
      children: [
        const Icon(LucideIcons.footprints,
            size: 14, color: FlowColors.g2),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            _meta,
            style: FlowText.rowSub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (accessible) ...[
          const SizedBox(width: 6),
          const Icon(LucideIcons.accessibility,
              size: 15, color: FlowColors.green),
        ],
      ],
    );
  }

  Widget _expandToggle(int hidden) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FlowTappable(
        onTap: () => setState(() => _expanded = !_expanded),
        behavior: HitTestBehavior.deferToChild,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _expanded
                    ? 'Réduire'
                    : hidden > 1
                        ? '+ $hidden autres lignes'
                        : '+ 1 autre ligne',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: FlowColors.g2,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 15,
                color: FlowColors.g2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une ligne de la carte : badge ligne (affiché une seule fois) puis une ou
/// plusieurs directions, chacune avec son prochain passage. Chaque direction
/// est tappable pour localiser/suivre le véhicule sur la carte.
class StationLineRow extends StatelessWidget {
  final StationLineGroup group;
  final Color color;
  final ValueChanged<StationDeparture>? onDirectionTap;

  const StationLineRow({
    super.key,
    required this.group,
    required this.color,
    this.onDirectionTap,
  });

  @override
  Widget build(BuildContext context) {
    final route = group.route;
    final multi = group.directions.length > 1;

    return Row(
      crossAxisAlignment:
          multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(top: multi ? 1 : 0),
          child: LineBadge(
            code: route.routeShortName ?? route.routeId,
            transportType: route.transportType,
            background: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < group.directions.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: _directionLine(group.directions[i], multi),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _directionLine(StationDeparture dep, bool multi) {
    final row = Row(
      children: [
        Expanded(
          child: Text(
            multi ? '• ${dep.headsign}' : dep.headsign,
            style: TextStyle(
              fontSize: multi ? 13 : 13.5,
              fontWeight: multi ? FontWeight.w600 : FontWeight.w700,
              letterSpacing: -0.2,
              color: FlowColors.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        WaitTime(
          waitMinutes: dep.waitMinutes,
          nextWaitMinutes: dep.nextWaitMinutes,
        ),
      ],
    );

    if (onDirectionTap == null) return row;
    return FlowTappable(
      onTap: () => onDirectionTap!(dep),
      pressedScale: 0.99,
      child: row,
    );
  }
}

/// Temps d'attente ultra-lisible : pastille verte pulsée « Arrive » si le
/// départ est imminent, sinon temps coloré par état (vert/orange/gris) avec
/// 2e passage discret. Le compteur s'anime à chaque changement de minute.
class WaitTime extends StatefulWidget {
  final int waitMinutes;
  final int nextWaitMinutes;

  const WaitTime({
    super.key,
    required this.waitMinutes,
    required this.nextWaitMinutes,
  });

  @override
  State<WaitTime> createState() => _WaitTimeState();
}

class _WaitTimeState extends State<WaitTime>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _imminent => widget.waitMinutes <= 1;

  @override
  Widget build(BuildContext context) {
    if (_imminent) return _arriveBadge();

    final color = flowWaitColor(widget.waitMinutes);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            '${widget.waitMinutes} min',
            key: ValueKey<int>(widget.waitMinutes),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.0,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '· ${widget.nextWaitMinutes}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.0,
            color: FlowColors.gWeak,
          ),
        ),
      ],
    );
  }

  Widget _arriveBadge() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: FlowColors.greenSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_pulse),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1.15).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: FlowColors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Arrive',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.0,
              color: FlowColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pilule de pertinence : étoile + libellé, fond doux coloré.
class RelevanceBadge extends StatelessWidget {
  final StationBadge badge;

  const RelevanceBadge({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.star, size: 12, color: badge.color),
          const SizedBox(width: 3),
          Text(
            badge.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: badge.color,
            ),
          ),
        ],
      ),
    );
  }
}
