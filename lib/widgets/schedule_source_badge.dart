import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../services/realtime_config.dart';

/// Badge indiquant la provenance des horaires affichés :
///   • « Temps réel » (vert) quand le flux live Okina (GTFS-RT/SIRI) est
///     configuré ([RealtimeConfig.isLiveEnabled]) ;
///   • « Théorique » (gris) sinon — les minutes proviennent alors des horaires
///     GTFS précompilés, pas d'un flux live.
class ScheduleSourceBadge extends StatelessWidget {
  const ScheduleSourceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final live = RealtimeConfig.isLiveEnabled;
    final bg = live ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6);
    final fg = live ? const Color(0xFF16A34A) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        live ? 'Temps réel' : 'Théorique',
        style: hankenGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
