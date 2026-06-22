import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import 'theoretical_schedule_list.dart';

/// Bottom sheet des horaires théoriques de passage à un arrêt.
class TheoreticalScheduleBottomSheet extends StatelessWidget {
  final List<DateTime> times;
  final String stopName;
  final String headsign;
  final String? lineCode;
  final Color lineColor;
  final int headwayMinutes;
  final ScrollController scrollController;

  const TheoreticalScheduleBottomSheet({
    super.key,
    required this.times,
    required this.stopName,
    required this.headsign,
    this.lineCode,
    required this.lineColor,
    required this.headwayMinutes,
    required this.scrollController,
  });

  static Future<void> show(
    BuildContext context, {
    required List<DateTime> times,
    required String stopName,
    required String headsign,
    String? lineCode,
    required Color lineColor,
    required int headwayMinutes,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.68,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, controller) => TheoreticalScheduleBottomSheet(
          times: times,
          stopName: stopName,
          headsign: headsign,
          lineCode: lineCode,
          lineColor: lineColor,
          headwayMinutes: headwayMinutes,
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        'Horaires théoriques',
                        style: hankenGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hankenGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mutedText,
                        ),
                      ),
                      Text(
                        'Direction $headsign',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hankenGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mutedText.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TheoreticalScheduleInfoBanner(headwayMinutes: headwayMinutes),
          Divider(height: 1, color: borderCol),
          Expanded(
            child: TheoreticalScheduleList(
              times: times,
              lineColor: lineColor,
              headwayMinutes: headwayMinutes,
              scrollController: scrollController,
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
            ),
          ),
        ],
      ),
    );
  }
}
