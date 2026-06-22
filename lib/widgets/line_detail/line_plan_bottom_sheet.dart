import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/gtfs.dart';
import '../../services/realtime_config.dart';

/// Bottom sheet avec le plan complet de la ligne (liste verticale).
class LinePlanBottomSheet extends StatelessWidget {
  final List<GtfsStop> stops;
  final int selectedIndex;
  final int vehicleBetweenIndex;
  final Color lineColor;
  final String headsign;
  final String? lineCode;
  final String? originTerminus;
  final String? destinationTerminus;
  final IconData vehicleIcon;
  final ScrollController scrollController;

  const LinePlanBottomSheet({
    super.key,
    required this.stops,
    required this.selectedIndex,
    required this.vehicleBetweenIndex,
    required this.lineColor,
    required this.headsign,
    this.lineCode,
    this.originTerminus,
    this.destinationTerminus,
    this.vehicleIcon = LucideIcons.bus,
    required this.scrollController,
  });

  static Future<void> show(
    BuildContext context, {
    required List<GtfsStop> stops,
    required int selectedIndex,
    required int vehicleBetweenIndex,
    required Color lineColor,
    required String headsign,
    String? lineCode,
    String? originTerminus,
    String? destinationTerminus,
    IconData vehicleIcon = LucideIcons.bus,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, controller) => LinePlanBottomSheet(
          stops: stops,
          selectedIndex: selectedIndex,
          vehicleBetweenIndex: vehicleBetweenIndex,
          lineColor: lineColor,
          headsign: headsign,
          lineCode: lineCode,
          originTerminus: originTerminus,
          destinationTerminus: destinationTerminus,
          vehicleIcon: vehicleIcon,
          scrollController: controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final primaryText =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedText =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    final selected = selectedIndex.clamp(0, stops.length - 1);
    final lastIndex = stops.length - 1;
    final showVehicle = vehicleBetweenIndex >= 0 &&
        vehicleBetweenIndex < lastIndex;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderCol)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: mutedText.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                if (lineCode != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      lineCode!,
                      style: hankenGrotesk(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan de la ligne',
                        style: hankenGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Direction $headsign',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hankenGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${stops.length} arrêts',
                  style: hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mutedText,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderCol),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
              itemCount: stops.length + (showVehicle ? 1 : 0),
              itemBuilder: (context, i) {
                if (showVehicle && i == 0) {
                  return _VehicleRow(
                    lineColor: lineColor,
                    vehicleIcon: vehicleIcon,
                    mutedText: mutedText,
                  );
                }
                final index = showVehicle ? i - 1 : i;
                return _StopRow(
                  name: stops[index].stopName,
                  isPast: index < selected,
                  isSelected: index == selected,
                  isOriginTerminus: index == 0,
                  isDestinationTerminus: index == lastIndex,
                  isLast: index == lastIndex,
                  showVehicleBefore: index == vehicleBetweenIndex + 1,
                  lineColor: lineColor,
                  primaryText: primaryText,
                  mutedText: mutedText,
                  borderCol: borderCol,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final Color lineColor;
  final IconData vehicleIcon;
  final Color mutedText;

  const _VehicleRow({
    required this.lineColor,
    required this.vehicleIcon,
    required this.mutedText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: lineColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: lineColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(vehicleIcon, size: 13, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Véhicule en circulation',
            style: hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: lineColor,
            ),
          ),
          const Spacer(),
          Text(
            RealtimeConfig.isLiveEnabled ? 'Temps réel' : 'Théorique',
            style: hankenGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final String name;
  final bool isPast;
  final bool isSelected;
  final bool isOriginTerminus;
  final bool isDestinationTerminus;
  final bool isLast;
  final bool showVehicleBefore;
  final Color lineColor;
  final Color primaryText;
  final Color mutedText;
  final Color borderCol;

  const _StopRow({
    required this.name,
    required this.isPast,
    required this.isSelected,
    required this.isOriginTerminus,
    required this.isDestinationTerminus,
    required this.isLast,
    required this.showVehicleBefore,
    required this.lineColor,
    required this.primaryText,
    required this.mutedText,
    required this.borderCol,
  });

  @override
  Widget build(BuildContext context) {
    final dotSize = isSelected ? 16.0 : 10.0;
    final segmentColor =
        isPast ? const Color(0xFFD1D5DB) : lineColor.withValues(alpha: 0.35);

    return SizedBox(
      height: isSelected ? 52 : 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 3,
                        color: showVehicleBefore ? Colors.transparent : segmentColor,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 3,
                        color: isLast ? Colors.transparent : segmentColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : (isPast
                            ? const Color(0xFFD1D5DB)
                            : lineColor),
                    shape: isOriginTerminus || isDestinationTerminus
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                    borderRadius: (isOriginTerminus || isDestinationTerminus)
                        ? BorderRadius.circular(3)
                        : null,
                    border: Border.all(
                      color: lineColor,
                      width: isSelected ? 3 : 2,
                    ),
                  ),
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
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isPast
                              ? mutedText
                              : (isSelected ? lineColor : primaryText),
                        ),
                      ),
                    ),
                    if (isOriginTerminus || isDestinationTerminus) ...[
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
                            color: isDestinationTerminus ? lineColor : mutedText,
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
                      color: const Color(0xFF1B66F5),
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
