import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bottom sheet « Tram en approche » — alerte in-app.
class ApproachAlertSheet extends StatelessWidget {
  final String lineCode;
  final String direction;
  final String stopName;
  final Color lineColor;
  final VoidCallback onViewMap;
  final VoidCallback onDismiss;

  const ApproachAlertSheet({
    super.key,
    required this.lineCode,
    required this.direction,
    required this.stopName,
    required this.lineColor,
    required this.onViewMap,
    required this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required String lineCode,
    required String direction,
    required String stopName,
    required Color lineColor,
    required VoidCallback onViewMap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ApproachAlertSheet(
        lineCode: lineCode,
        direction: direction,
        stopName: stopName,
        lineColor: lineColor,
        onViewMap: () {
          Navigator.pop(ctx);
          onViewMap();
        },
        onDismiss: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.bell,
                size: 26,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '🚋 Tram en approche !',
              textAlign: TextAlign.center,
              style: hankenGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B1220),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Le tram $lineCode en direction de $direction arrive à $stopName dans 1 minute.',
              textAlign: TextAlign.center,
              style: hankenGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5B6677),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: onViewMap,
                style: FilledButton.styleFrom(
                  backgroundColor: lineColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Voir le tram sur la carte',
                  style: hankenGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onDismiss,
              child: Text(
                'Ok, merci',
                style: hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9AA4B2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
