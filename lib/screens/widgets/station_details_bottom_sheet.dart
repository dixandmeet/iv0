import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/gtfs_service.dart';
import '../../services/map_service.dart';
import '../../theme/flow_theme.dart';
import '../../widgets/flow_primitives.dart';
import '../../widgets/flow_widgets.dart';
import '../../widgets/nearby_station_card.dart';

/// Fiche d'un arrêt : lignes desservies et temps d'attente estimés.
class StationDetailsBottomSheet extends StatefulWidget {
  final NearbyStation station;
  final GtfsService gtfs;
  final MapService mapHelper;
  final bool showDistance;
  final VoidCallback? onCenterMap;
  final DirectionTapCallback? onDirectionTap;

  const StationDetailsBottomSheet({
    super.key,
    required this.station,
    required this.gtfs,
    required this.mapHelper,
    this.showDistance = true,
    this.onCenterMap,
    this.onDirectionTap,
  });

  @override
  State<StationDetailsBottomSheet> createState() =>
      _StationDetailsBottomSheetState();
}

class _StationDetailsBottomSheetState extends State<StationDetailsBottomSheet> {
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

  @override
  Widget build(BuildContext context) {
    final groups = widget.gtfs.stationLineGroups(widget.station);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.58;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: FlowSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionLabel('Arrêt'),
                Row(
                  children: [
                    if (widget.onCenterMap != null) ...[
                      FlowIconButton(
                        icon: LucideIcons.locateFixed,
                        size: 38,
                        iconSize: 18,
                        onTap: widget.onCenterMap!,
                      ),
                      const SizedBox(width: 4),
                    ],
                    FlowIconButton(
                      icon: LucideIcons.x,
                      size: 38,
                      iconSize: 18,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel('Prochains passages'),
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 12, color: FlowColors.gWeak),
                    SizedBox(width: 4),
                    Text('temps estimés', style: FlowText.kicker),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: groups.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Aucune ligne ne dessert cette station.',
                          style: FlowText.rowSub,
                        ),
                      )
                    : NearbyStationCard(
                        station: widget.station,
                        groups: groups,
                        mapHelper: widget.mapHelper,
                        showDistance: widget.showDistance,
                        onTap: widget.onCenterMap ?? () => Navigator.pop(context),
                        onDirectionTap: widget.onDirectionTap == null
                            ? null
                            : (route, station, dep) {
                                Navigator.pop(context);
                                widget.onDirectionTap!(route, station, dep);
                              },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
