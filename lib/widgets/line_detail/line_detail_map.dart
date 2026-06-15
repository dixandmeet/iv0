import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/gtfs.dart';
import '../../screens/line_detail_map_fullscreen.dart';
import 'line_detail_map_body.dart';

/// Carte interactive embarquée dans la page détail ligne.
class LineDetailMap extends StatelessWidget {
  final GtfsRoute route;
  final String headsign;
  final GtfsStop stop;
  final LatLng userPosition;
  final LatLng? vehiclePosition;
  final Color lineColor;
  final int waitMinutes;
  final IconData vehicleIcon;

  const LineDetailMap({
    super.key,
    required this.route,
    required this.headsign,
    required this.stop,
    required this.userPosition,
    required this.vehiclePosition,
    required this.lineColor,
    required this.waitMinutes,
    this.vehicleIcon = LucideIcons.bus,
  });

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LineDetailMapFullScreenPage(
          route: route,
          headsign: headsign,
          stop: stop,
          userPosition: userPosition,
          vehiclePosition: vehiclePosition,
          lineColor: lineColor,
          waitMinutes: waitMinutes,
          vehicleIcon: vehicleIcon,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LineDetailMapBody(
          route: route,
          headsign: headsign,
          stop: stop,
          userPosition: userPosition,
          vehiclePosition: vehiclePosition,
          lineColor: lineColor,
          waitMinutes: waitMinutes,
          vehicleIcon: vehicleIcon,
          onFullscreen: () => _openFullscreen(context),
        ),
      ),
    );
  }
}
