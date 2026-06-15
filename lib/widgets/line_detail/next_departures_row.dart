import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/line_detail_models.dart';
import 'realtime_signal.dart';

/// Section premium des prochains passages à l'arrêt.
class NextDeparturesRow extends StatelessWidget {
  final List<DepartureSlot> departures;
  final Color lineColor;
  final String? stopName;
  final int? headwayMinutes;
  final VoidCallback? onSeeMore;

  const NextDeparturesRow({
    super.key,
    required this.departures,
    required this.lineColor,
    this.stopName,
    this.headwayMinutes,
    this.onSeeMore,
  });

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

    if (departures.isEmpty) return const SizedBox.shrink();

    final next = departures.first;
    final following = departures.length > 1 ? departures.sublist(1) : const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Prochains passages',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _LiveBadge(isDark: isDark),
                        ],
                      ),
                      if (stopName != null || headwayMinutes != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (stopName != null)
                              Flexible(
                                child: Text(
                                  stopName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: mutedText,
                                  ),
                                ),
                              ),
                            if (stopName != null && headwayMinutes != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '·',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 11,
                                    color: mutedText,
                                  ),
                                ),
                              ),
                            if (headwayMinutes != null)
                              Text(
                                'toutes les $headwayMinutes min',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: mutedText,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (onSeeMore != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSeeMore,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B232F)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderCol),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.clock,
                              size: 13,
                              color: mutedText,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Théoriques',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _HeroDepartureCard(
              slot: next,
              lineColor: lineColor,
              cardBg: cardBg,
              borderCol: borderCol,
              primaryText: primaryText,
              mutedText: mutedText,
              isDark: isDark,
            ),
            if (following.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Suivants',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: mutedText,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: following.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return _FollowingChip(
                      slot: following[i],
                      lineColor: lineColor,
                      borderCol: borderCol,
                      primaryText: primaryText,
                      mutedText: mutedText,
                      isDark: isDark,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final bool isDark;

  const _LiveBadge({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Live',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDepartureCard extends StatelessWidget {
  final DepartureSlot slot;
  final Color lineColor;
  final Color cardBg;
  final Color borderCol;
  final Color primaryText;
  final Color mutedText;
  final bool isDark;

  const _HeroDepartureCard({
    required this.slot,
    required this.lineColor,
    required this.cardBg,
    required this.borderCol,
    required this.primaryText,
    required this.mutedText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final status = _statusStyle(slot.status, isDark, mutedText, primaryText);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lineColor.withValues(alpha: 0.4), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lineColor.withValues(alpha: isDark ? 0.22 : 0.1),
            cardBg,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: lineColor.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: lineColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Prochain passage',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: lineColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: status.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.label,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: status.fg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${slot.waitMinutes}',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: status.waitColor,
                        height: 1,
                        letterSpacing: -1.5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 3, bottom: 5),
                      child: Text(
                        'min',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: status.waitColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    RealtimeSignal(
                      color: status.waitColor,
                      muted: slot.status == DepartureStatus.theoretical,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: borderCol,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(LucideIcons.clock, size: 14, color: mutedText),
              const SizedBox(height: 6),
              Text(
                timeFmt.format(slot.departureTime),
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Passage',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowingChip extends StatelessWidget {
  final DepartureSlot slot;
  final Color lineColor;
  final Color borderCol;
  final Color primaryText;
  final Color mutedText;
  final bool isDark;

  const _FollowingChip({
    required this.slot,
    required this.lineColor,
    required this.borderCol,
    required this.primaryText,
    required this.mutedText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final status = _statusStyle(slot.status, isDark, mutedText, primaryText);
    final isTheoretical = slot.status == DepartureStatus.theoretical;

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B232F) : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTheoretical ? borderCol : lineColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${slot.waitMinutes}',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: status.waitColor,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 1),
                child: Text(
                  'min',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: status.waitColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            timeFmt.format(slot.departureTime),
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: mutedText,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

({String label, Color bg, Color fg, Color waitColor}) _statusStyle(
  DepartureStatus status,
  bool isDark,
  Color mutedText,
  Color primaryText,
) {
  return switch (status) {
    DepartureStatus.realtime => (
        label: 'Temps réel',
        bg: const Color(0xFFDCFCE7),
        fg: const Color(0xFF16A34A),
        waitColor: const Color(0xFF16A34A),
      ),
    DepartureStatus.theoretical => (
        label: 'Théorique',
        bg: isDark ? const Color(0xFF1B232F) : const Color(0xFFF3F4F6),
        fg: mutedText,
        waitColor: primaryText,
      ),
    DepartureStatus.delayed => (
        label: 'Retardé',
        bg: const Color(0xFFFEE2E2),
        fg: const Color(0xFFDC2626),
        waitColor: const Color(0xFFDC2626),
      ),
  };
}
