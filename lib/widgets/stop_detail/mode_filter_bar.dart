import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Filtre par mode de transport (Tout, Tram, Bus, Chronobus, Navette).
enum TransportModeFilter {
  all,
  tram,
  bus,
  busway,
  navibus,
}

extension TransportModeFilterX on TransportModeFilter {
  String get label => switch (this) {
        TransportModeFilter.all => 'Tout',
        TransportModeFilter.tram => 'Tram',
        TransportModeFilter.bus => 'Bus',
        TransportModeFilter.busway => 'Chronobus',
        TransportModeFilter.navibus => 'Navette',
      };

  String? get transportType => switch (this) {
        TransportModeFilter.all => null,
        TransportModeFilter.tram => 'tram',
        TransportModeFilter.bus => 'bus',
        TransportModeFilter.busway => 'busway',
        TransportModeFilter.navibus => 'navibus',
      };

  IconData get icon => switch (this) {
        TransportModeFilter.all => LucideIcons.layers,
        TransportModeFilter.tram => LucideIcons.tramFront,
        TransportModeFilter.bus => LucideIcons.bus,
        TransportModeFilter.busway => LucideIcons.busFront,
        TransportModeFilter.navibus => LucideIcons.ship,
      };

  Color get iconColor => switch (this) {
        TransportModeFilter.all => const Color(0xFF1B66F5),
        TransportModeFilter.tram => const Color(0xFF16A34A),
        TransportModeFilter.bus => const Color(0xFF1B66F5),
        TransportModeFilter.busway => const Color(0xFF8B258F),
        TransportModeFilter.navibus => const Color(0xFFF29400),
      };
}

class ModeFilterBar extends StatelessWidget {
  final TransportModeFilter selected;
  final ValueChanged<TransportModeFilter> onSelected;

  const ModeFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final borderCol = isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    final primaryText = isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedText = isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: TransportModeFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = TransportModeFilter.values[index];
                final isActive = filter == selected;

                return GestureDetector(
                  onTap: () => onSelected(filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1B66F5) : cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isActive ? const Color(0xFF1B66F5) : borderCol,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF1B66F5).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (filter != TransportModeFilter.all) ...[
                          Icon(
                            filter.icon,
                            size: 14,
                            color: isActive ? Colors.white : filter.iconColor,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          filter.label,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.slidersHorizontal, size: 16, color: mutedText),
            ),
          ),
        ],
      ),
    );
  }
}
