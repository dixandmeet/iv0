import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Carte premium « Votre véhicule » — illustration tram et équipements.
class VehicleDetailCard extends StatefulWidget {
  final String vehicleNumber;
  final String vehicleModel;
  final Color lineColor;
  final String? lineCode;
  final List<VehicleFeature> features;

  const VehicleDetailCard({
    super.key,
    required this.vehicleNumber,
    required this.vehicleModel,
    required this.lineColor,
    this.lineCode,
    this.features = const [],
  });

  static List<VehicleFeature> defaultTramFeatures() => const [
        VehicleFeature(
          icon: LucideIcons.snowflake,
          label: 'Climatisé',
        ),
        VehicleFeature(
          icon: LucideIcons.accessibility,
          label: 'Accessibilité PMR',
        ),
        VehicleFeature(
          icon: LucideIcons.wifi,
          label: 'WiFi',
        ),
        VehicleFeature(
          icon: LucideIcons.cctv,
          label: 'Vidéosurveillance',
        ),
      ];

  @override
  State<VehicleDetailCard> createState() => _VehicleDetailCardState();
}

class _VehicleDetailCardState extends State<VehicleDetailCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  String get _displayName {
    final n = widget.vehicleNumber.trim();
    if (n.toLowerCase().startsWith('tram') || n.toLowerCase().startsWith('bus')) {
      return '$n • ${widget.vehicleModel}';
    }
    final prefix = widget.lineCode != null ? 'Tram' : 'Véhicule';
    return '$prefix $n • ${widget.vehicleModel}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.lineColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE7EAF0)),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Row(
                children: [
                  Text(
                    'Votre véhicule',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                  const Spacer(),
                  _LiveChip(color: c),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _HeroIllustration(
                color: c,
                lineCode: widget.lineCode,
                floatAnimation: _float,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                _displayName,
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B1220),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Matériel roulant Naolib · ${widget.vehicleModel}',
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9AA4B2),
                ),
              ),
            ),
            if (widget.features.isNotEmpty) ...[
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: widget.features
                      .map((f) => _FeaturePill(feature: f, lineColor: c))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class VehicleFeature {
  final IconData icon;
  final String label;

  const VehicleFeature({required this.icon, required this.label});
}

class _LiveChip extends StatelessWidget {
  final Color color;

  const _LiveChip({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'En service',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  final Color color;
  final String? lineCode;
  final Animation<double> floatAnimation;

  const _HeroIllustration({
    required this.color,
    required this.lineCode,
    required this.floatAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.05),
            const Color(0xFFF8FAFC),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reflet sol
          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Rails décoratifs
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: CustomPaint(
              size: const Size(double.infinity, 8),
              painter: _RailsPainter(color: color),
            ),
          ),
          // Tram animé
          AnimatedBuilder(
            animation: floatAnimation,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(0, floatAnimation.value),
                child: Center(
                  child: CustomPaint(
                    painter: _CitadisTramPainter(
                      color: color,
                      lineCode: lineCode,
                    ),
                    size: const Size(260, 90),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final VehicleFeature feature;
  final Color lineColor;

  const _FeaturePill({
    required this.feature,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: lineColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(feature.icon, size: 15, color: lineColor),
          ),
          const SizedBox(width: 8),
          Text(
            feature.label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5B6677),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailsPainter extends CustomPainter {
  final Color color;

  _RailsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final railPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), railPaint);
    canvas.drawLine(
      Offset(20, y + 5),
      Offset(size.width - 20, y + 5),
      railPaint..color = const Color(0xFFE2E8F0),
    );

    for (var x = 30.0; x < size.width - 20; x += 22) {
      canvas.drawLine(
        Offset(x, y - 3),
        Offset(x, y + 8),
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RailsPainter old) => old.color != color;
}

/// Illustration détaillée Citadis — style cutout premium.
class _CitadisTramPainter extends CustomPainter {
  final Color color;
  final String? lineCode;

  _CitadisTramPainter({required this.color, this.lineCode});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 2;

    // Ombre portée douce
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 34), width: 210, height: 14),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Corps blanc principal
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 228, height: 58),
      const Radius.circular(16),
    );
    canvas.drawRRect(body, Paint()..color = Colors.white);
    canvas.drawRRect(
      body,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Bande couleur ligne (bas)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 20), width: 224, height: 18),
        const Radius.circular(10),
      ),
      Paint()..color = color,
    );

    // Bande blanche intermédiaire
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 8), width: 224, height: 6),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white,
    );

    // Vitres avec reflet
    for (var i = -3; i <= 3; i++) {
      final wx = cx + i * 30.0;
      final glassRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(wx, cy - 8), width: 24, height: 26),
        const Radius.circular(7),
      );
      canvas.drawRRect(
        glassRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFDBEAFE).withValues(alpha: 0.95),
              const Color(0xFF93C5FD).withValues(alpha: 0.55),
            ],
          ).createShader(glassRect.outerRect),
      );
      canvas.drawRRect(
        glassRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Toit arrondi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 26), width: 200, height: 10),
        const Radius.circular(5),
      ),
      Paint()..color = color.withValues(alpha: 0.9),
    );

    // Pantographe
    final pantoX = cx - 28;
    canvas.drawLine(
      Offset(pantoX, cy - 31),
      Offset(pantoX, cy - 42),
      Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(pantoX - 8, cy - 42),
      Offset(pantoX + 8, cy - 42),
      Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Badge ligne avant
    if (lineCode != null) {
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 88, cy + 4), width: 28, height: 22),
        const Radius.circular(7),
      );
      canvas.drawRRect(badgeRect, Paint()..color = color);
      final tp = TextPainter(
        text: TextSpan(
          text: lineCode,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(cx - 88 - tp.width / 2, cy + 4 - tp.height / 2),
      );
    }

    // Phares avant
    canvas.drawCircle(
      Offset(cx - 108, cy + 10),
      4,
      Paint()..color = const Color(0xFFFDE68A),
    );
    canvas.drawCircle(
      Offset(cx + 108, cy + 10),
      4,
      Paint()..color = const Color(0xFFFCA5A5),
    );

    // Bogies / roues
    for (final wx in [cx - 68.0, cx - 22.0, cx + 22.0, cx + 68.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(wx, cy + 36), width: 36, height: 10),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF334155),
      );
      for (final ox in [-10.0, 10.0]) {
        canvas.drawCircle(
          Offset(wx + ox, cy + 36),
          7,
          Paint()..color = const Color(0xFF1E293B),
        );
        canvas.drawCircle(
          Offset(wx + ox, cy + 36),
          3,
          Paint()..color = const Color(0xFF94A3B8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CitadisTramPainter old) =>
      old.color != color || old.lineCode != lineCode;
}
