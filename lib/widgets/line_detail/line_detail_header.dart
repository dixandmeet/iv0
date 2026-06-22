import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/gtfs.dart';
import 'realtime_signal.dart';

/// En-tête premium de la page détail ligne.
class LineDetailHeader extends StatelessWidget {
  final GtfsRoute route;
  final String headsign;
  final String fromStopName;
  final String modeLabel;
  final Color lineColor;
  final int nextWaitMinutes;
  final bool isFavorite;
  final bool isRealtime;
  final VoidCallback onBack;
  final VoidCallback onFavoriteToggle;
  final IconData vehicleIcon;

  const LineDetailHeader({
    super.key,
    required this.route,
    required this.headsign,
    required this.fromStopName,
    this.modeLabel = 'Ligne',
    required this.lineColor,
    required this.nextWaitMinutes,
    required this.isFavorite,
    this.isRealtime = true,
    required this.onBack,
    required this.onFavoriteToggle,
    required this.vehicleIcon,
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
    final label = route.routeShortName ?? route.routeId;
    const waitColor = Color(0xFF16A34A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _HeaderIconButton(
                icon: LucideIcons.arrowLeft,
                onTap: onBack,
                primaryText: primaryText,
                borderCol: borderCol,
                cardBg: cardBg,
                isDark: isDark,
              ),
              const Spacer(),
              _HeaderIconButton(
                icon: LucideIcons.star,
                onTap: onFavoriteToggle,
                primaryText: isFavorite ? const Color(0xFFF59E0B) : mutedText,
                borderCol: borderCol,
                cardBg: cardBg,
                isDark: isDark,
                filled: isFavorite,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderCol),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: lineColor.withValues(alpha: 0.38),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
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
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Icon(
                        vehicleIcon,
                        color: Colors.white.withValues(alpha: 0.92),
                        size: 15,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direction',
                        style: hankenGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: mutedText,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headsign,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: hankenGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                          letterSpacing: -0.35,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.mapPin,
                            size: 11,
                            color: mutedText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Depuis $fromStopName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: hankenGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: mutedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StatusPill(
                            label: isRealtime ? 'Temps réel' : 'Estimé',
                            dotColor: isRealtime
                                ? const Color(0xFF16A34A)
                                : mutedText,
                            bg: isRealtime
                                ? const Color(0xFFDCFCE7)
                                : (isDark
                                    ? const Color(0xFF1B232F)
                                    : const Color(0xFFF3F4F6)),
                            fg: isRealtime
                                ? const Color(0xFF16A34A)
                                : mutedText,
                          ),
                          _StatusPill(
                            label: modeLabel,
                            dotColor: lineColor,
                            bg: lineColor.withValues(alpha: 0.12),
                            fg: lineColor,
                            showDot: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 72, maxWidth: 88),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: waitColor.withValues(alpha: isDark ? 0.14 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: waitColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$nextWaitMinutes',
                              style: hankenGrotesk(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: waitColor,
                                height: 1,
                                letterSpacing: -1.2,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 2,
                                bottom: 4,
                              ),
                              child: Text(
                                'min',
                                style: hankenGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: waitColor.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 5),
                              child: RealtimeSignal(color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prochain\npassage',
                        textAlign: TextAlign.right,
                        style: hankenGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: mutedText,
                          height: 1.2,
                        ),
                      ),
                    ],
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

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color primaryText;
  final Color borderCol;
  final Color cardBg;
  final bool isDark;
  final bool filled;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.primaryText,
    required this.borderCol,
    required this.cardBg,
    required this.isDark,
    this.filled = false,
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
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: primaryText,
            fill: filled ? 1.0 : 0.0,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color dotColor;
  final Color bg;
  final Color fg;
  final bool showDot;

  const _StatusPill({
    required this.label,
    required this.dotColor,
    required this.bg,
    required this.fg,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: hankenGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
