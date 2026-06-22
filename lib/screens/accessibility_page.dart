import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/aule_theme.dart';
import 'stop_detail_page.dart';

/// Écran Accessibilité : arrêts PMR du réseau, triés par proximité.
class AccessibilityPage extends StatefulWidget {
  const AccessibilityPage({super.key});

  @override
  State<AccessibilityPage> createState() => _AccessibilityPageState();
}

class _AccessibilityPageState extends State<AccessibilityPage> {
  final TextEditingController _search = TextEditingController();
  _PmrFilter _filter = _PmrFilter.accessible;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openStop(NearbyStation station, {required bool hasDistance}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            StopDetailPage(station: station, showDistance: hasDistance),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;

    final gtfs = context.watch<GtfsService>();
    final location = context.watch<LocationService>();
    final pos = location.currentPosition;
    final LatLng? from =
        pos != null ? LatLng(pos.latitude, pos.longitude) : null;

    final query = _search.text.trim().toLowerCase();
    final allStops = gtfs.cachedStops.where((s) {
      if (_filter == _PmrFilter.accessible && !s.isWheelchairAccessible) {
        return false;
      }
      if (_filter == _PmrFilter.inaccessible && !s.isWheelchairInaccessible) {
        return false;
      }
      if (query.isNotEmpty &&
          !s.stopName.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    if (from != null) {
      const d = Distance();
      allStops.sort((a, b) => d
          .as(LengthUnit.Meter, from, a.position)
          .compareTo(d.as(LengthUnit.Meter, from, b.position)));
    } else {
      allStops.sort((a, b) => a.stopName.compareTo(b.stopName));
    }

    final total = allStops.length;

    return AuleTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              _Header(colors: c, total: total),
              _SearchField(controller: _search, colors: c),
              _FilterRow(
                selected: _filter,
                colors: c,
                onChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: allStops.isEmpty
                    ? _EmptyState(colors: c)
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: allStops.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final stop = allStops[i];
                          final station =
                              gtfs.nearbyStationFor(stop, from: from);
                          if (station == null) {
                            return const SizedBox.shrink();
                          }
                          return _StopRow(
                            station: station,
                            hasDistance: from != null,
                            colors: c,
                            onTap: () =>
                                _openStop(station, hasDistance: from != null),
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

enum _PmrFilter { accessible, inaccessible, all }

class _Header extends StatelessWidget {
  final AuleColors colors;
  final int total;
  const _Header({required this.colors, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.line),
              ),
              child: Icon(LucideIcons.arrowLeft, size: 20, color: colors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accessibilité',
                  style: hankenGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: colors.text,
                  ),
                ),
                Text(
                  '$total arrêt${total > 1 ? 's' : ''}',
                  style: hankenGrotesk(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.muted,
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final AuleColors colors;
  const _SearchField({required this.controller, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.search, size: 18, color: colors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                cursorColor: colors.brand,
                style: hankenGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Rechercher un arrêt...',
                  hintStyle: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.faint,
                  ),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.clear,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(LucideIcons.x, size: 16, color: colors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _PmrFilter selected;
  final AuleColors colors;
  final ValueChanged<_PmrFilter> onChanged;

  const _FilterRow({
    required this.selected,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _chip('Accessible PMR', _PmrFilter.accessible),
          const SizedBox(width: 8),
          _chip('Non accessible', _PmrFilter.inaccessible),
          const SizedBox(width: 8),
          _chip('Tous', _PmrFilter.all),
        ],
      ),
    );
  }

  Widget _chip(String label, _PmrFilter filter) {
    final isSelected = selected == filter;
    final bg = isSelected ? colors.brand : colors.surface;
    final fg = isSelected ? Colors.white : colors.muted;
    final border = isSelected ? colors.brand : colors.line;

    return GestureDetector(
      onTap: () => onChanged(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AuleColors colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.accessibility, size: 40, color: colors.faint),
          const SizedBox(height: 14),
          Text(
            'Aucun arrêt trouvé',
            style: hankenGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final NearbyStation station;
  final bool hasDistance;
  final AuleColors colors;
  final VoidCallback onTap;

  const _StopRow({
    required this.station,
    required this.hasDistance,
    required this.colors,
    required this.onTap,
  });

  String get _sub {
    final codes = station.routes
        .map((r) => r.routeShortName ?? r.routeId)
        .take(6)
        .join(' · ');
    final more =
        station.routes.length > 6 ? ' +${station.routes.length - 6}' : '';
    if (!hasDistance) return '$codes$more';
    final meters = station.distanceMeters;
    final distance = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
    return '$distance · $codes$more';
  }

  @override
  Widget build(BuildContext context) {
    final accessible = station.stop.isWheelchairAccessible;
    final inaccessible = station.stop.isWheelchairInaccessible;
    final pmrColor = accessible
        ? colors.ok
        : inaccessible
            ? const Color(0xFFEF4444)
            : colors.faint;
    final pmrIcon = accessible
        ? LucideIcons.circleCheck
        : inaccessible
            ? LucideIcons.circleX
            : LucideIcons.circleHelp;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: pmrColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.accessibility, size: 20, color: pmrColor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          station.stop.stopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hankenGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(pmrIcon, size: 15, color: pmrColor),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hankenGrotesk(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: colors.faint),
          ],
        ),
      ),
    );
  }
}
