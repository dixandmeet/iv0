import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/aule_models.dart';
import '../services/aule_data_adapter.dart';
import '../services/gtfs_service.dart';
import '../services/home_aggregator.dart';
import '../services/location_service.dart';
import '../services/report_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/aule/aule_icons.dart';
import '../widgets/aule/line_badge.dart';
import '../widgets/aule/aule_network_map_view.dart';

/// Écran Map — plan du réseau GTFS avec filtres de ligne.
class AuleMapScreen extends StatefulWidget {
  const AuleMapScreen({super.key});

  @override
  State<AuleMapScreen> createState() => _AuleMapScreenState();
}

class _AuleMapScreenState extends State<AuleMapScreen> {
  String? _selectedLine;

  void _selectLine(String? line) {
    setState(() {
      if (line == null || line == 'Tout') {
        _selectedLine = null;
      } else if (_selectedLine == line) {
        _selectedLine = null;
      } else {
        _selectedLine = line;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    final gtfs = context.watch<GtfsService>();
    final reports = context.watch<ReportService>();
    final location = context.watch<LocationService>();

    final pos = location.currentPosition;
    final userPos =
        pos != null ? LatLng(pos.latitude, pos.longitude) : null;
    final center = HomeAggregator.resolveCenter(userPos);

    final routes = AuleDataAdapter.mapRoutes(gtfs);
    final filterChips = AuleDataAdapter.mapFilterChips(gtfs);
    final networkLines =
        AuleDataAdapter.networkLines(gtfs, reports.activeReports);
    final mapStops = AuleDataAdapter.mapStopsNear(center, gtfs);

    return ColoredBox(
      color: c.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AuleNetworkMapView(
            selectedLine: _selectedLine,
            center: center,
            routes: routes,
            stops: mapStops,
            userPosition: userPos,
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.line),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AuleTokens.cardShadow(c.shadow),
                    ),
                    child: Row(
                      children: [
                        AuleIcons.search(size: 19, color: c.muted),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Rechercher une ligne, un arrêt',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.faint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    itemCount: filterChips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final chip = filterChips[i];
                      final active = chip == 'Tout'
                          ? _selectedLine == null
                          : _selectedLine == chip;
                      final lineColor = chip == 'Tout'
                          ? c.brand
                          : AuleLineColors.forLine(chip);
                      return GestureDetector(
                        onTap: () => _selectLine(chip),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? lineColor : c.surface,
                            border: Border.all(
                              color: active ? lineColor : c.line,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color:
                                          lineColor.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            chip,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: active ? Colors.white : c.text,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 120,
            child: Column(
              children: [
                _FabButton(
                  icon: AuleIcons.locate(size: 22, color: c.text),
                  onTap: () {},
                  semanticLabel: 'Recentrer la carte',
                ),
                const SizedBox(height: 10),
                _FabButton(
                  icon: AuleIcons.layers(size: 22, color: c.text),
                  onTap: () {},
                  semanticLabel: 'Calques de carte',
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LinesSheet(
              lines: networkLines,
              selectedLine: _selectedLine,
              onLineTap: _selectLine,
              bottomInset: bottomPad,
            ),
          ),
        ],
      ),
    );
  }
}

class _FabButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  final String semanticLabel;

  const _FabButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: c.surface,
            shape: BoxShape.circle,
            border: Border.all(color: c.line),
            boxShadow: AuleTokens.cardShadow(c.shadow),
          ),
          alignment: Alignment.center,
          child: icon,
        ),
      ),
    );
  }
}

class _LinesSheet extends StatelessWidget {
  final List<AuleNetworkLine> lines;
  final String? selectedLine;
  final ValueChanged<String?> onLineTap;
  final double bottomInset;

  const _LinesSheet({
    required this.lines,
    required this.selectedLine,
    required this.onLineTap,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 280),
          padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + bottomInset),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.95),
            border: Border(top: BorderSide(color: c.line)),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Toutes les lignes',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: c.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${lines.length}',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: lines.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Chargement des lignes…',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.muted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: lines.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: c.lineSoft),
                        itemBuilder: (context, i) {
                          final line = lines[i];
                          return GestureDetector(
                            onTap: () => onLineTap(line.code),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  LineBadge.medium(
                                    label: line.code,
                                    mode: line.mode,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.terminus,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            color: c.text,
                                          ),
                                        ),
                                        Text(
                                          '${line.modeLabel} · ${line.frequency}',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: c.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color:
                                          line.disrupted ? c.warn : c.ok,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  AuleIcons.chevron(size: 18, color: c.faint),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
