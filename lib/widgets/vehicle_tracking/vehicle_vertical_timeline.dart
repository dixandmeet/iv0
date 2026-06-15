import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Timeline verticale de progression — arrêts passés, position utilisateur, véhicule.
class VehicleVerticalTimeline extends StatelessWidget {
  final List<TimelineStop> stops;
  final int userStopIndex;
  final int vehicleBetweenIndex;
  final Color lineColor;
  final IconData vehicleIcon;
  final bool showVehicleOnTimeline;
  /// Index de l'arrêt de descente à surligner (spec guidage s4).
  final int? alightStopIndex;

  const VehicleVerticalTimeline({
    super.key,
    required this.stops,
    required this.userStopIndex,
    required this.vehicleBetweenIndex,
    required this.lineColor,
    this.vehicleIcon = LucideIcons.tramFront,
    this.showVehicleOnTimeline = false,
    this.alightStopIndex,
  });

  static const _pastGrey = Color(0xFFD1D5DB);
  static const _mutedText = Color(0xFF9AA4B2);
  static const _primaryText = Color(0xFF0B1220);

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE7EAF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Progression du trajet',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _primaryText,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(stops.length, (i) {
              final stop = stops[i];
              final isPast = i < userStopIndex;
              final isUser = i == userStopIndex;
              final isFuture = i > userStopIndex;
              final showVehicleAbove =
                  showVehicleOnTimeline && i == vehicleBetweenIndex + 1;

              return Column(
                children: [
                  if (showVehicleAbove) ...[
                    _VehicleTimelineMarker(
                      color: lineColor,
                      icon: vehicleIcon,
                    ),
                    _ConnectorLine(
                      color: lineColor,
                      isPast: false,
                      height: 20,
                    ),
                  ],
                  _StopRow(
                    name: stop.name,
                    time: stop.arrivalTime,
                    isPast: isPast,
                    isUser: isUser,
                    isFuture: isFuture,
                    isAlight: alightStopIndex == i,
                    lineColor: lineColor,
                    isLast: i == stops.length - 1,
                  ),
                  if (i < stops.length - 1)
                    _ConnectorLine(
                      color: isPast ? _pastGrey : lineColor,
                      isPast: isPast,
                      height: 24,
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class TimelineStop {
  final String name;
  final String? arrivalTime;
  final bool isAlight;

  const TimelineStop({
    required this.name,
    this.arrivalTime,
    this.isAlight = false,
  });
}

class _StopRow extends StatelessWidget {
  final String name;
  final String? time;
  final bool isPast;
  final bool isUser;
  final bool isFuture;
  final bool isAlight;
  final Color lineColor;
  final bool isLast;

  const _StopRow({
    required this.name,
    this.time,
    required this.isPast,
    required this.isUser,
    required this.isFuture,
    this.isAlight = false,
    required this.lineColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = isAlight
        ? '◆ $name — descendre'
        : (isUser ? '$name (vous êtes ici)' : name);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StopDot(
          isPast: isPast,
          isUser: isUser,
          isAlight: isAlight,
          lineColor: lineColor,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            displayName,
            style: GoogleFonts.hankenGrotesk(
              fontSize: isUser || isAlight ? 15 : 14,
              fontWeight: isUser || isAlight ? FontWeight.w800 : FontWeight.w600,
              color: isAlight
                  ? const Color(0xFFD6453E)
                  : (isPast
                      ? VehicleVerticalTimeline._mutedText
                      : VehicleVerticalTimeline._primaryText),
            ),
          ),
        ),
        if (time != null)
          Text(
            time!,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isPast
                  ? VehicleVerticalTimeline._mutedText
                  : (isUser ? lineColor : VehicleVerticalTimeline._mutedText),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

class _StopDot extends StatelessWidget {
  final bool isPast;
  final bool isUser;
  final bool isAlight;
  final Color lineColor;

  const _StopDot({
    required this.isPast,
    required this.isUser,
    this.isAlight = false,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isAlight) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFFD6453E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD6453E).withValues(alpha: 0.35),
              blurRadius: 6,
            ),
          ],
        ),
      );
    }

    if (isUser) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lineColor.withValues(alpha: 0.12),
          border: Border.all(color: lineColor, width: 2.5),
        ),
        child: Icon(
          LucideIcons.circleCheck,
          size: 14,
          color: lineColor,
        ),
      );
    }

    if (isPast) {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: VehicleVerticalTimeline._pastGrey,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: lineColor, width: 2),
      ),
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  final Color color;
  final bool isPast;
  final double height;

  const _ConnectorLine({
    required this.color,
    required this.isPast,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 2,
          height: height,
          decoration: BoxDecoration(
            color: isPast ? VehicleVerticalTimeline._pastGrey : color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

class _VehicleTimelineMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _VehicleTimelineMarker({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(icon, size: 11, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Text(
            '🚋',
            style: GoogleFonts.hankenGrotesk(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
