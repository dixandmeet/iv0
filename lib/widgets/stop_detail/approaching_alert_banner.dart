import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/gtfs_service.dart';
import '../../theme/aule_theme.dart';
import '../../theme/app_fonts.dart';
import '../nearby_stops/line_badge.dart';

/// Bandeau d'alarme affiché quand un ou plusieurs véhicules sont en approche
/// (< 1 min). Pulsation ambre/rouge + icône animée pour capter l'attention.
class ApproachingAlertBanner extends StatefulWidget {
  final List<StationDeparture> departures;
  final AuleColors colors;
  final VoidCallback? onTap;

  const ApproachingAlertBanner({
    super.key,
    required this.departures,
    required this.colors,
    this.onTap,
  });

  @override
  State<ApproachingAlertBanner> createState() => _ApproachingAlertBannerState();
}

class _ApproachingAlertBannerState extends State<ApproachingAlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  static const _alertColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _message() {
    final deps = widget.departures;
    if (deps.length == 1) {
      final d = deps.first;
      final code = d.route.routeShortName ?? d.route.routeId;
      final type = d.route.transportType == 'tram' ? 'Tram' : 'Bus';
      return '$type $code → ${d.headsign} arrive !';
    }
    return '${deps.length} véhicules en approche !';
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.departures;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final t = _pulse.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: _alertColor.withValues(alpha: 0.08 + 0.06 * t),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _alertColor.withValues(alpha: 0.35 + 0.2 * t),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _alertColor.withValues(alpha: 0.08 + 0.1 * t),
                  blurRadius: 12 + 6 * t,
                  spreadRadius: 1 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _alertColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(LucideIcons.bellRing, size: 20, color: _alertColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _message(),
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _alertColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    for (var i = 0; i < deps.length && i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      _MiniLineBadge(
                        code: deps[i].route.routeShortName ?? deps[i].route.routeId,
                      ),
                    ],
                    if (deps.length > 4) ...[
                      const SizedBox(width: 6),
                      Text(
                        '+${deps.length - 4}',
                        style: hankenGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.colors.muted,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'Préparez-vous',
                      style: hankenGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: widget.colors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.onTap != null) ...[
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: widget.colors.faint),
          ],
        ],
      ),
    );
  }
}

class _MiniLineBadge extends StatelessWidget {
  final String code;
  const _MiniLineBadge({required this.code});

  @override
  Widget build(BuildContext context) {
    final color = LineBadge.colorFor(code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
