import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../models/driver/control_mission_terrain.dart';
import '../../../models/driver/control_plan_context.dart';
import '../../../services/driver/control_mission_terrain_service.dart';
import '../../../services/gtfs_service.dart';
import '../../../services/location_service.dart';
import '../../../theme/driver_home_palette.dart';

class MissionTerrainTab extends StatefulWidget {
  final ControlMissionSummary mission;

  const MissionTerrainTab({super.key, required this.mission});

  @override
  State<MissionTerrainTab> createState() => _MissionTerrainTabState();
}

class _MissionTerrainTabState extends State<MissionTerrainTab> {
  final _terrain = ControlMissionTerrainService();
  MissionTerrainPlan? _plan;
  bool _loading = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _plan = _terrain.buildPlan(
      mission: widget.mission,
      gtfs: null,
      teamPosition: null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant MissionTerrainTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mission.id != widget.mission.id) {
      _plan = _terrain.buildPlan(
        mission: widget.mission,
        gtfs: null,
        teamPosition: null,
      );
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    if (_started && _loading) return;
    _started = true;
    setState(() => _loading = true);

    final gtfs = _read<GtfsService>();
    final location = _read<LocationService>();
    try {
      await location?.refreshIfPermitted();
    } catch (_) {}
    try {
      if (gtfs != null) {
        if (gtfs.cachedStops.isEmpty) await gtfs.fetchStops();
        if (gtfs.cachedRoutes.isEmpty) await gtfs.fetchRoutes();
      }
    } catch (_) {}

    if (!mounted) return;
    final pos = location?.currentPosition;
    final teamPosition = pos == null
        ? null
        : LatLng(pos.latitude, pos.longitude);
    setState(() {
      _plan = _terrain.buildPlan(
        mission: widget.mission,
        gtfs: gtfs,
        teamPosition: teamPosition,
      );
      _loading = false;
    });
  }

  T? _read<T>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan =
        _plan ??
        _terrain.buildPlan(
          mission: widget.mission,
          gtfs: null,
          teamPosition: null,
        );
    final recommended = plan.recommendedStop;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _MissionTerrainMap(
            plan: plan,
            selectedStop: recommended,
            onStopTap: _showStopDetails,
          ),
          const SizedBox(height: 12),
          _StatusBadges(plan: plan, loading: _loading),
          const SizedBox(height: 12),
          _RecommendedStopCard(
            stop: recommended,
            onGo: recommended == null
                ? null
                : () => _showStopDetails(recommended),
            onDetails: recommended == null
                ? null
                : () => _showStopDetails(recommended),
          ),
          const SizedBox(height: 12),
          _SectorLinesCard(lines: plan.sectorLines),
          const SizedBox(height: 12),
          _AssistantPadCard(
            recommendation: plan.padRecommendation,
            onRecalculate: _refresh,
          ),
        ],
      ),
    );
  }

  void _showStopDetails(MissionTerrainStopPlan stop) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StopDetailsSheet(stop: stop),
    );
  }
}

class _MissionTerrainMap extends StatelessWidget {
  final MissionTerrainPlan plan;
  final MissionTerrainStopPlan? selectedStop;
  final ValueChanged<MissionTerrainStopPlan> onStopTap;

  const _MissionTerrainMap({
    required this.plan,
    required this.selectedStop,
    required this.onStopTap,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      Marker(
        point: plan.mapCenter,
        width: 42,
        height: 42,
        alignment: Alignment.center,
        child: const _TeamMarker(),
      ),
      for (final stop in plan.stops.take(18))
        Marker(
          point: stop.position,
          width: stop.id == selectedStop?.id ? 54 : 44,
          height: stop.id == selectedStop?.id ? 54 : 44,
          alignment: Alignment.center,
          child: _StopMarker(
            stop: stop,
            selected: stop.id == selectedStop?.id,
            onTap: () => onStopTap(stop),
          ),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 310,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              key: ValueKey(
                '${plan.mapCenter.latitude}:${plan.mapCenter.longitude}:${plan.stops.length}',
              ),
              options: MapOptions(
                initialCenter: plan.mapCenter,
                initialZoom: 13.6,
                minZoom: 11,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.aule.pro',
                  retinaMode: RetinaMode.isHighDensity(context),
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              left: 12,
              top: 12,
              right: 12,
              child: _MapOverlayTitle(plan: plan),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapOverlayTitle extends StatelessWidget {
  final MissionTerrainPlan plan;

  const _MapOverlayTitle({required this.plan});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DriverHomePalette.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              LucideIcons.map,
              color: DriverHomePalette.primary,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                plan.usedFallbackCenter
                    ? 'Carte terrain · fallback Nantes'
                    : 'Carte terrain · secteur service',
                style: const TextStyle(
                  color: DriverHomePalette.textDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${plan.stops.length} arrêts',
              style: const TextStyle(
                color: DriverHomePalette.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamMarker extends StatelessWidget {
  const _TeamMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DriverHomePalette.blue.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: DriverHomePalette.blue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x332F80ED),
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(LucideIcons.users, color: Colors.white, size: 13),
      ),
    );
  }
}

class _StopMarker extends StatelessWidget {
  final MissionTerrainStopPlan stop;
  final bool selected;
  final VoidCallback onTap;

  const _StopMarker({
    required this.stop,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final recommended =
        stop.scoreLevel == MissionTerrainScoreLevel.veryHigh ||
        stop.scoreLevel == MissionTerrainScoreLevel.high;
    final color = recommended
        ? DriverHomePalette.primary
        : stop.inSector
        ? DriverHomePalette.controlAccent
        : DriverHomePalette.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.18 : 0.11),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.7 : 0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DriverHomePalette.card,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: selected ? 3 : 2),
          ),
          child: Center(
            child: Icon(
              recommended ? LucideIcons.star : LucideIcons.mapPin,
              color: color,
              size: selected ? 20 : 17,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadges extends StatelessWidget {
  final MissionTerrainPlan plan;
  final bool loading;

  const _StatusBadges({required this.plan, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (loading) const _Badge(label: 'Chargement position équipe'),
        for (final badge in plan.badges)
          _Badge(label: badge.label, warning: badge.warning),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool warning;

  const _Badge({required this.label, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? DriverHomePalette.warning
        : DriverHomePalette.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RecommendedStopCard extends StatelessWidget {
  final MissionTerrainStopPlan? stop;
  final VoidCallback? onGo;
  final VoidCallback? onDetails;

  const _RecommendedStopCard({
    required this.stop,
    required this.onGo,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final s = stop;
    return _Panel(
      child: s == null
          ? const _EmptyState(
              icon: LucideIcons.mapPinned,
              title: 'Point conseillé maintenant',
              message:
                  'Aucun arrêt trouvé. Le secteur reste affiché en mode dégradé.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  icon: LucideIcons.crosshair,
                  title: 'Point conseillé maintenant',
                ),
                const SizedBox(height: 12),
                Text(
                  s.name,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill('${s.lineCount} lignes'),
                    _InfoPill(_nextPassageLabel(s)),
                    _InfoPill(_distanceLabel(s)),
                    _InfoPill('Score ${s.scoreLevel.label}'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  s.operationalInterest,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PrimaryActionButton(
                        label: 'S’y rendre',
                        icon: LucideIcons.navigation,
                        onTap: onGo,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SecondaryActionButton(
                        label: 'Voir détails',
                        icon: LucideIcons.list,
                        onTap: onDetails,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SectorLinesCard extends StatelessWidget {
  final List<MissionTerrainLinePlan> lines;

  const _SectorLinesCard({required this.lines});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: LucideIcons.route,
            title: 'Lignes du secteur',
          ),
          const SizedBox(height: 12),
          if (lines.isEmpty)
            const _EmptyState(
              icon: LucideIcons.clockAlert,
              title: 'Aucun passage disponible',
              message:
                  'Les horaires restent en attente. Le mode dégradé garde une aide secteur.',
            )
          else
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LineTile(line: line),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  final MissionTerrainLinePlan line;

  const _LineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final color = switch (line.status) {
      MissionTerrainLineStatus.immediate => DriverHomePalette.primary,
      MissionTerrainLineStatus.soon => DriverHomePalette.warning,
      MissionTerrainLineStatus.longWait => DriverHomePalette.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DriverHomePalette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              line.lineLabel,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.advisedStopName,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${line.direction} · ${line.operationalInterest}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${line.nextWaitMinutes} min',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
              Text(
                line.status.label,
                style: const TextStyle(
                  color: DriverHomePalette.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantPadCard extends StatelessWidget {
  final MissionTerrainPadRecommendation recommendation;
  final VoidCallback onRecalculate;

  const _AssistantPadCard({
    required this.recommendation,
    required this.onRecalculate,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: LucideIcons.sparkles,
            title: 'Assistant PAD',
          ),
          const SizedBox(height: 6),
          const Text(
            'Recommandation terrain',
            style: TextStyle(
              color: DriverHomePalette.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (recommendation.steps.isEmpty)
            const _EmptyState(
              icon: LucideIcons.circleAlert,
              title: 'Retour dépôt impossible',
              message:
                  'Aucun itinéraire fiable à proposer. Restez sur le point le plus proche.',
            )
          else
            ...recommendation.steps.asMap().entries.map(
              (entry) => _PadStepTile(index: entry.key + 1, step: entry.value),
            ),
          const SizedBox(height: 10),
          _ReturnEstimate(recommendation: recommendation),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PrimaryActionButton(
                  label: 'Lancer l’itinéraire',
                  icon: LucideIcons.play,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              _IconAction(
                tooltip: 'Recalculer',
                icon: LucideIcons.refreshCw,
                onTap: onRecalculate,
              ),
              const SizedBox(width: 8),
              _IconAction(
                tooltip: 'Voir alternatives',
                icon: LucideIcons.gitBranch,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadStepTile extends StatelessWidget {
  final int index;
  final MissionTerrainPadStep step;

  const _PadStepTile({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: DriverHomePalette.lightGreen,
            child: Text(
              '$index',
              style: const TextStyle(
                color: DriverHomePalette.primary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.stop.name,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${step.recommendedMinutes} min · ${step.targetLines.join(', ')}',
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pourquoi ce choix ? ${step.stop.operationalInterest}.',
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12,
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

class _ReturnEstimate extends StatelessWidget {
  final MissionTerrainPadRecommendation recommendation;

  const _ReturnEstimate({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final color = recommendation.returnPossible
        ? DriverHomePalette.primary
        : DriverHomePalette.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        'Retour dépôt estimé : ${_time(recommendation.estimatedDepotArrivalAt)}'
        '${recommendation.leaveLastPointAt == null ? '' : ' · départ dernier point ${_time(recommendation.leaveLastPointAt)}'}',
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StopDetailsSheet extends StatelessWidget {
  final MissionTerrainStopPlan stop;

  const _StopDetailsSheet({required this.stop});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.56,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, controller) => DecoratedBox(
        decoration: const BoxDecoration(
          color: DriverHomePalette.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: DriverHomePalette.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              stop.name,
              style: const TextStyle(
                color: DriverHomePalette.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(_distanceLabel(stop)),
                _InfoPill('${stop.lineCount} lignes disponibles'),
                _InfoPill('Score ${stop.scoreLevel.label}'),
                if (stop.inSector) const _InfoPill('Arrêt du secteur'),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionHeader(
              icon: LucideIcons.clock,
              title: 'Prochains passages',
            ),
            const SizedBox(height: 10),
            if (stop.passages.isEmpty)
              const Text(
                'Aucun passage disponible',
                style: TextStyle(color: DriverHomePalette.textSecondary),
              )
            else
              ...stop.passages.map(
                (p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: DriverHomePalette.lightGreen,
                    child: Text(
                      p.lineLabel,
                      style: const TextStyle(
                        color: DriverHomePalette.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(p.direction),
                  subtitle: Text(p.theoretical ? 'Horaires théoriques' : ''),
                  trailing: Text(
                    '${p.waitMinutes} min',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const _SectionHeader(
              icon: LucideIcons.info,
              title: 'Intérêt opérationnel',
            ),
            const SizedBox(height: 8),
            Text(
              stop.operationalInterest,
              style: const TextStyle(
                color: DriverHomePalette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            _PrimaryActionButton(
              label: 'S’y rendre',
              icon: LucideIcons.navigation,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: DriverHomePalette.primary, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: DriverHomePalette.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;

  const _InfoPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: DriverHomePalette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: DriverHomePalette.textDark,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: DriverHomePalette.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: DriverHomePalette.primary,
        minimumSize: const Size(0, 46),
        side: const BorderSide(color: DriverHomePalette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon),
        color: DriverHomePalette.primary,
        style: IconButton.styleFrom(
          backgroundColor: DriverHomePalette.lightGreen,
          fixedSize: const Size(46, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: DriverHomePalette.textSecondary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: DriverHomePalette.textDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: DriverHomePalette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _nextPassageLabel(MissionTerrainStopPlan stop) {
  final wait = stop.soonestWaitMinutes;
  if (wait == null) return 'Aucun passage';
  return 'Prochain $wait min';
}

String _distanceLabel(MissionTerrainStopPlan stop) {
  final meters = stop.distanceMeters;
  if (meters == null) return 'Distance estimée';
  if (meters < 1000) return '${meters.round()} m à pied';
  return '${(meters / 1000).toStringAsFixed(1)} km à pied';
}

String _time(DateTime? d) {
  if (d == null) return '—';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
