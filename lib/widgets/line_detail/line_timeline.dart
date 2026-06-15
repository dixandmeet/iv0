import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/gtfs.dart';
import 'line_plan_bottom_sheet.dart';

/// Timeline horizontale scrollable du plan de la ligne.
class LineTimeline extends StatefulWidget {
  final List<GtfsStop> stops;
  final int selectedIndex;
  final int vehicleBetweenIndex;
  final Color lineColor;
  final String headsign;
  final String? originTerminus;
  final String? destinationTerminus;
  final String? lineCode;
  final IconData vehicleIcon;

  static const nodeWidth = 92.0;
  static const dotRowHeight = 28.0;
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

  @override
  State<LineTimeline> createState() => _LineTimelineState();
}

class _LineTimelineState extends State<LineTimeline> {
  final _scrollController = ScrollController();
  bool _didAutoScroll = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (_didAutoScroll || widget.stops.isEmpty) return;
    if (!_scrollController.hasClients) return;

    final selected = widget.selectedIndex.clamp(0, widget.stops.length - 1);
    final target = selected * LineTimeline.nodeWidth +
        LineTimeline.nodeWidth / 2 -
        (_scrollController.position.viewportDimension / 2);
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(target.clamp(0.0, max));
    _didAutoScroll = true;
  }

  @override
  void didUpdateWidget(LineTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _didAutoScroll = false;
    }
  }

  void _openFullPlan(BuildContext context) {
    LinePlanBottomSheet.show(
      context,
      stops: widget.stops,
      selectedIndex: widget.selectedIndex,
      vehicleBetweenIndex: widget.vehicleBetweenIndex,
      lineColor: widget.lineColor,
      headsign: widget.headsign,
      lineCode: widget.lineCode,
      originTerminus: widget.originTerminus,
      destinationTerminus: widget.destinationTerminus,
      vehicleIcon: widget.vehicleIcon,
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

    if (widget.stops.isEmpty) {
      return const SizedBox.shrink();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());

    final trackWidth = widget.stops.length * LineTimeline.nodeWidth;
    final selected = widget.selectedIndex.clamp(0, widget.stops.length - 1);
    final lastIndex = widget.stops.length - 1;

    final origin = widget.originTerminus ?? widget.stops.first.stopName;
    final destination =
        widget.destinationTerminus ?? widget.stops.last.stopName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                  style: GoogleFonts.hankenGrotesk(
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
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: mutedText,
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronUp,
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
                    lineColor: mutedText,
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
                    color: widget.lineColor,
                  ),
                ),
                Expanded(
                  child: _TerminusChip(
                    label: destination,
                    lineColor: widget.lineColor,
                    bg: widget.lineColor.withValues(alpha: 0.12),
                    fg: widget.lineColor,
                    icon: LucideIcons.flag,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 98,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: trackWidth,
                      height: 98,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CustomPaint(
                            size: Size(trackWidth, LineTimeline.dotRowHeight),
                            painter: _TimelineLinePainter(
                              stopCount: widget.stops.length,
                              selectedIndex: selected,
                              lineColor: widget.lineColor,
                              nodeWidth: LineTimeline.nodeWidth,
                              y: LineTimeline.dotRowHeight / 2,
                            ),
                          ),
                          if (widget.vehicleBetweenIndex >= 0 &&
                              widget.vehicleBetweenIndex < lastIndex)
                            Positioned(
                              left: LineTimeline.nodeWidth *
                                      (widget.vehicleBetweenIndex + 0.5) +
                                  LineTimeline.nodeWidth / 2 -
                                  11,
                              top: 0,
                              child: _VehicleMarker(
                                color: widget.lineColor,
                                icon: widget.vehicleIcon,
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < widget.stops.length; i++)
                                _StopColumn(
                                  name: widget.stops[i].stopName,
                                  isPast: i < selected,
                                  isSelected: i == selected,
                                  isOriginTerminus: i == 0,
                                  isDestinationTerminus: i == lastIndex,
                                  lineColor: widget.lineColor,
                                  primaryText: primaryText,
                                  mutedText: mutedText,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 28,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              cardBg.withValues(alpha: 0),
                              cardBg,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminusChip extends StatelessWidget {
  final String label;
  final Color lineColor;
  final Color bg;
  final Color fg;
  final IconData icon;
  final bool alignEnd;

  const _TerminusChip({
    required this.label,
    required this.lineColor,
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
          style: GoogleFonts.hankenGrotesk(
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
            border: Border.all(color: lineColor.withValues(alpha: 0.25)),
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
                  style: GoogleFonts.hankenGrotesk(
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

/// Segments horizontaux continus entre les centres des pastilles.
class _TimelineLinePainter extends CustomPainter {
  final int stopCount;
  final int selectedIndex;
  final Color lineColor;
  final double nodeWidth;
  final double y;

  const _TimelineLinePainter({
    required this.stopCount,
    required this.selectedIndex,
    required this.lineColor,
    required this.nodeWidth,
    required this.y,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stopCount < 2) return;

    for (var i = 0; i < stopCount - 1; i++) {
      final x1 = nodeWidth * i + nodeWidth / 2;
      final x2 = nodeWidth * (i + 1) + nodeWidth / 2;
      final isPastSegment = i < selectedIndex;

      final paint = Paint()
        ..color = isPastSegment ? LineTimeline.pastGrey : lineColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
    }
  }

  @override
  bool shouldRepaint(_TimelineLinePainter oldDelegate) =>
      oldDelegate.stopCount != stopCount ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.lineColor != lineColor;
}

class _VehicleMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _VehicleMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, size: 11, color: Colors.white),
    );
  }
}

class _StopColumn extends StatelessWidget {
  final String name;
  final bool isPast;
  final bool isSelected;
  final bool isOriginTerminus;
  final bool isDestinationTerminus;
  final Color lineColor;
  final Color primaryText;
  final Color mutedText;

  const _StopColumn({
    required this.name,
    required this.isPast,
    required this.isSelected,
    required this.isOriginTerminus,
    required this.isDestinationTerminus,
    required this.lineColor,
    required this.primaryText,
    required this.mutedText,
  });

  bool get _isTerminus => isOriginTerminus || isDestinationTerminus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: LineTimeline.nodeWidth,
      child: Column(
        children: [
          SizedBox(
            height: LineTimeline.dotRowHeight,
            child: Center(
              child: _StopDot(
                isPast: isPast,
                isSelected: isSelected,
                isTerminus: _isTerminus,
                isDestinationTerminus: isDestinationTerminus,
                lineColor: lineColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (_isTerminus)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isDestinationTerminus
                    ? lineColor.withValues(alpha: 0.12)
                    : mutedText.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Terminus',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: isDestinationTerminus ? lineColor : mutedText,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 10,
                fontWeight: isSelected || isDestinationTerminus
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: isPast
                    ? mutedText
                    : (isDestinationTerminus ? lineColor : primaryText),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopDot extends StatelessWidget {
  final bool isPast;
  final bool isSelected;
  final bool isTerminus;
  final bool isDestinationTerminus;
  final Color lineColor;

  const _StopDot({
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
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: lineColor, width: 3),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: lineColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    if (isTerminus) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: isDestinationTerminus ? lineColor : LineTimeline.pastGrey,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isDestinationTerminus ? lineColor : LineTimeline.pastGrey,
            width: 2,
          ),
        ),
      );
    }

    if (isPast) {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: LineTimeline.pastGrey,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: lineColor,
        shape: BoxShape.circle,
      ),
    );
  }
}
