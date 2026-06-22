import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/gtfs_service.dart';
import '../../theme/aule_theme.dart';
import '../live_dot.dart';
import '../nearby_stops/line_badge.dart';

/// Carte d'un prochain départ (une ligne, une direction) à l'arrêt.
///
/// Hiérarchie : badge de ligne › destination › temps d'attente. La carte
/// entière est cliquable et ouvre la fiche véhicule (page ligne). Une bande
/// d'accent latérale reprend la couleur de la ligne pour un repérage immédiat.
/// Quand le véhicule est en approche (< 1 min), la carte pulse avec un halo
/// coloré pour alerter visuellement l'utilisateur.
class DepartureCard extends StatefulWidget {
  final StationDeparture departure;
  final AuleColors colors;
  final VoidCallback onTap;

  const DepartureCard({
    super.key,
    required this.departure,
    required this.colors,
    required this.onTap,
  });

  @override
  State<DepartureCard> createState() => _DepartureCardState();
}

class _DepartureCardState extends State<DepartureCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;
  Animation<double>? _glowAnim;

  bool get _isApproaching => widget.departure.waitMinutes < 1;

  @override
  void initState() {
    super.initState();
    if (_isApproaching) _startPulse();
  }

  @override
  void didUpdateWidget(DepartureCard old) {
    super.didUpdateWidget(old);
    final wasApproaching = old.departure.waitMinutes < 1;
    if (_isApproaching && !wasApproaching) {
      _startPulse();
    } else if (!_isApproaching && wasApproaching) {
      _stopPulse();
    }
  }

  void _startPulse() {
    _pulse ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulse!, curve: Curves.easeInOut),
    );
    _pulse!.repeat(reverse: true);
  }

  void _stopPulse() {
    _pulse?.stop();
    _pulse?.dispose();
    _pulse = null;
    _glowAnim = null;
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final departure = widget.departure;
    final colors = widget.colors;
    final route = departure.route;
    final label = route.routeShortName ?? route.routeId;
    final color = LineBadge.colorFor(label);

    Widget card = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isApproaching ? _WaitPill._imminent.withValues(alpha: 0.5) : colors.line,
          width: _isApproaching ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                    child: Row(
                      children: [
                        _LineBadge(
                          label: label,
                          color: color,
                          icon: _vehicleIcon(route.transportType),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            departure.headsign,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: hankenGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: colors.text,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _WaitPill(minutes: departure.waitMinutes, animate: _isApproaching),
                        const SizedBox(width: 6),
                        Icon(LucideIcons.chevronRight,
                            size: 18, color: colors.faint),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!_isApproaching || _glowAnim == null) return card;

    return AnimatedBuilder(
      animation: _glowAnim!,
      builder: (_, __) {
        final t = _glowAnim!.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _WaitPill._imminent.withValues(alpha: 0.12 + 0.14 * t),
                blurRadius: 10 + 8 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          child: card,
        );
      },
    );
  }
}

class _LineBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _LineBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
        // Ombre colorée : légère profondeur qui renforce la couleur de ligne.
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: hankenGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 13),
        ],
      ),
    );
  }
}

/// Temps d'attente principal dans une pastille teintée, color-codée selon
/// l'imminence : vert (≥ 5 min), orange (1–4 min), « À l'approche » avec point
/// « live » pulsant (< 1 min).
class _WaitPill extends StatelessWidget {
  final int minutes;
  final bool animate;
  const _WaitPill({required this.minutes, this.animate = false});

  static const _green = Color(0xFF22C55E);
  static const _orange = Color(0xFFF59E0B);
  static const _imminent = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    if (minutes < 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _imminent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiveDot(animate: animate),
            const SizedBox(width: 6),
            Text(
              "À l'approche",
              style: hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _imminent,
              ),
            ),
          ],
        ),
      );
    }

    final color = minutes >= 5 ? _green : _orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$minutes',
              style: hankenGrotesk(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            TextSpan(
              text: ' min',
              style: hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

