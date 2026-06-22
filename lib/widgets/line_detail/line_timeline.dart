import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/gtfs.dart';
import 'line_plan_bottom_sheet.dart';

/// Plan de la ligne en liste verticale. À l'ouverture, n'affiche que la
/// portion utile : de la position du véhicule jusqu'à l'arrêt de l'utilisateur.
/// Le tracé complet reste accessible via « Voir tout ».
class LineTimeline extends StatelessWidget {
  final List<GtfsStop> stops;
  final int selectedIndex;
  final int vehicleBetweenIndex;
  final Color lineColor;
  final String headsign;
  final String? originTerminus;
  final String? destinationTerminus;
  final String? lineCode;
  final IconData vehicleIcon;

  static const railWidth = 28.0;
  static const pastGrey = Color(0xFFD1D5DB);

  const LineTimeline({
    super.key,
    required this.stops,
    required this.selectedIndex,
    required this.vehicleBetweenIndex,
    required this.lineColor,
    required this.headsign,
    this.originTerminus,
    this.destinationTerminus,
    this.lineCode,
    this.vehicleIcon = LucideIcons.bus,
  });

  void _openFullPlan(BuildContext context) {
    LinePlanBottomSheet.show(
      context,
      stops: stops,
      selectedIndex: selectedIndex,
      vehicleBetweenIndex: vehicleBetweenIndex,
      lineColor: lineColor,
      headsign: headsign,
      lineCode: lineCode,
      originTerminus: originTerminus,
      destinationTerminus: destinationTerminus,
      vehicleIcon: vehicleIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedText =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    if (stops.isEmpty) {
      return const SizedBox.shrink();
    }

    final lastIndex = stops.length - 1;
    final selected = selectedIndex.clamp(0, lastIndex);
    final showVehicle =
        vehicleBetweenIndex >= 0 && vehicleBetweenIndex < lastIndex;

    // Fenêtre affichée : de la position du véhicule jusqu'à l'arrêt utilisateur.
    var lo = selected;
    var hi = selected;
    if (showVehicle) {
      lo = lo < vehicleBetweenIndex ? lo : vehicleBetweenIndex;
      final vehicleNext = vehicleBetweenIndex + 1;
      hi = hi > vehicleNext ? hi : vehicleNext;
    }
    lo = lo.clamp(0, lastIndex);
    hi = hi.clamp(0, lastIndex);

    final origin = originTerminus ?? stops.first.stopName;
    final destination = destinationTerminus ?? stops.last.stopName;

    final hiddenBefore = lo;
    final hiddenAfter = lastIndex - hi;

    final rows = <Widget>[];
    if (hiddenBefore > 0) {
      rows.add(_MoreStopsHint(count: hiddenBefore, mutedText: mutedText));
    }
    for (var i = lo; i <= hi; i++) {
      final passed = i <= vehicleBetweenIndex;
      final isFirstInWindow = i == lo;
      final isLastInWindow = i == hi;
      // Segment au-dessus / en-dessous d'un arrêt : gris s'il est en amont du
      // véhicule (déjà parcouru), couleur de ligne s'il reste à parcourir.
      final topColor = isFirstInWindow
          ? Colors.transparent
          : (i <= vehicleBetweenIndex ? pastGrey : lineColor);
      final bottomColor = isLastInWindow
          ? Colors.transparent
          : (i <= vehicleBetweenIndex ? pastGrey : lineColor);

      rows.add(
        _StopRow(
          name: stops[i].stopName,
          isPastDot: passed && i != selected,
          isSelected: i == selected,
          isOriginTerminus: i == 0,
          isDestinationTerminus: i == lastIndex,
          topColor: topColor,
          bottomColor: bottomColor,
          lineColor: lineColor,
          primaryText: primaryText,
          mutedText: mutedText,
        ),
      );

      if (showVehicle && i == vehicleBetweenIndex) {
        rows.add(
          _VehicleRow(lineColor: lineColor, vehicleIcon: vehicleIcon),
        );
      }
    }
    if (hiddenAfter > 0) {
      rows.add(_MoreStopsHint(count: hiddenAfter, mutedText: mutedText));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Plan de la ligne',
                  style: hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openFullPlan(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Voir tout',
                            style: hankenGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: mutedText,
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 14,
                            color: mutedText,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _TerminusChip(
                    label: origin,
                    bg: isDark
                        ? const Color(0xFF1B232F)
                        : const Color(0xFFF3F4F6),
                    fg: mutedText,
                    icon: LucideIcons.flag,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    LucideIcons.arrowRight,
                    size: 14,
                    color: lineColor,
                  ),
                ),
                Expanded(
                  child: _TerminusChip(
                    label: destination,
                    bg: lineColor.withValues(alpha: 0.12),
                    fg: lineColor,
                    icon: LucideIcons.flag,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _TerminusChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;
  final bool alignEnd;

  const _TerminusChip({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          'Terminus',
          style: hankenGrotesk(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: fg.withValues(alpha: 0.85),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fg.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!alignEnd) ...[
                Icon(icon, size: 11, color: fg),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                  style: hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
              if (alignEnd) ...[
                const SizedBox(width: 5),
                Icon(icon, size: 11, color: fg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Indique le nombre d'arrêts masqués (avant la fenêtre ou après).
class _MoreStopsHint extends StatelessWidget {
  final int count;
  final Color mutedText;

  const _MoreStopsHint({required this.count, required this.mutedText});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        children: [
          SizedBox(
            width: LineTimeline.railWidth,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (_) => Container(
                    width: 3,
                    height: 3,
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    decoration: BoxDecoration(
                      color: mutedText.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            count > 1 ? '$count arrêts' : '$count arrêt',
            style: hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marqueur véhicule posé sur le tracé, entre deux arrêts.
class _VehicleRow extends StatelessWidget {
  final Color lineColor;
  final IconData vehicleIcon;

  const _VehicleRow({required this.lineColor, required this.vehicleIcon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: LineTimeline.railWidth,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    // Segment déjà parcouru au-dessus du véhicule.
                    Expanded(
                      child: Container(
                        width: 3,
                        color: LineTimeline.pastGrey,
                      ),
                    ),
                    // Segment restant à parcourir sous le véhicule.
                    Expanded(child: Container(width: 3, color: lineColor)),
                  ],
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: lineColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: lineColor.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(vehicleIcon, size: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Véhicule ici',
                style: hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: lineColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final String name;
  final bool isPastDot;
  final bool isSelected;
  final bool isOriginTerminus;
  final bool isDestinationTerminus;
  final Color topColor;
  final Color bottomColor;
  final Color lineColor;
  final Color primaryText;
  final Color mutedText;

  const _StopRow({
    required this.name,
    required this.isPastDot,
    required this.isSelected,
    required this.isOriginTerminus,
    required this.isDestinationTerminus,
    required this.topColor,
    required this.bottomColor,
    required this.lineColor,
    required this.primaryText,
    required this.mutedText,
  });

  bool get _isTerminus => isOriginTerminus || isDestinationTerminus;

  @override
  Widget build(BuildContext context) {
    final dotSize = isSelected ? 18.0 : (_isTerminus ? 14.0 : 11.0);

    return SizedBox(
      height: isSelected ? 50 : 42,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: LineTimeline.railWidth,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    Expanded(child: Container(width: 3, color: topColor)),
                    Expanded(child: Container(width: 3, color: bottomColor)),
                  ],
                ),
                _StopDot(
                  size: dotSize,
                  isPast: isPastDot,
                  isSelected: isSelected,
                  isTerminus: _isTerminus,
                  isDestinationTerminus: isDestinationTerminus,
                  lineColor: lineColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hankenGrotesk(
                          fontSize: 13.5,
                          fontWeight: isSelected || isDestinationTerminus
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isPastDot
                              ? mutedText
                              : (isSelected
                                  ? lineColor
                                  : (isDestinationTerminus
                                      ? lineColor
                                      : primaryText)),
                        ),
                      ),
                    ),
                    if (_isTerminus) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDestinationTerminus
                              ? lineColor.withValues(alpha: 0.12)
                              : mutedText.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Terminus',
                          style: hankenGrotesk(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color:
                                isDestinationTerminus ? lineColor : mutedText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isSelected)
                  Text(
                    'Votre arrêt',
                    style: hankenGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: lineColor,
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

class _StopDot extends StatelessWidget {
  final double size;
  final bool isPast;
  final bool isSelected;
  final bool isTerminus;
  final bool isDestinationTerminus;
  final Color lineColor;

  const _StopDot({
    required this.size,
    required this.isPast,
    required this.isSelected,
    required this.isTerminus,
    required this.isDestinationTerminus,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: lineColor, width: 3),
        ),
        child: Center(
          child: Container(
            width: size / 2.6,
            height: size / 2.6,
            decoration: BoxDecoration(
              color: lineColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    if (isTerminus) {
      final col = isPast
          ? LineTimeline.pastGrey
          : (isDestinationTerminus ? lineColor : LineTimeline.pastGrey);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: col,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: col, width: 2),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isPast ? LineTimeline.pastGrey : lineColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
