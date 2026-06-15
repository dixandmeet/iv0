import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/gtfs.dart';
import '../theme/aule_theme.dart';
import '../widgets/line_detail/line_detail_map_body.dart';

/// Carte détail ligne en plein écran.
class LineDetailMapFullScreenPage extends StatelessWidget {
  final GtfsRoute route;
  final String headsign;
  final GtfsStop stop;
  final LatLng userPosition;
  final LatLng? vehiclePosition;
  final Color lineColor;
  final int waitMinutes;
  final IconData vehicleIcon;

  const LineDetailMapFullScreenPage({
    super.key,
    required this.route,
    required this.headsign,
    required this.stop,
    required this.userPosition,
    required this.vehiclePosition,
    required this.lineColor,
    required this.waitMinutes,
    required this.vehicleIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = route.routeShortName ?? route.routeId;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D13) : const Color(0xFFF6F7FB),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Stack(
          children: [
            Positioned.fill(
              child: LineDetailMapBody(
                route: route,
                headsign: headsign,
                stop: stop,
                userPosition: userPosition,
                vehiclePosition: vehiclePosition,
                lineColor: lineColor,
                waitMinutes: waitMinutes,
                vehicleIcon: vehicleIcon,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _TopButton(
                      icon: LucideIcons.x,
                      onTap: () => Navigator.pop(context),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? const Color(0xFF141A23)
                                  : Colors.white)
                              .withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x17FFFFFF)
                                : const Color(0xFFE7EAF0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: lineColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Direction $headsign',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AuleColors.dark.text
                                          : AuleColors.light.text,
                                    ),
                                  ),
                                  Text(
                                    '$waitMinutes min · ${stop.stopName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AuleColors.dark.muted
                                          : AuleColors.light.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _TopButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF141A23) : Colors.white)
                .withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0x17FFFFFF)
                  : const Color(0xFFE7EAF0),
            ),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
