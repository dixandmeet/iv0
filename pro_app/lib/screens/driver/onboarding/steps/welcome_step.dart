import 'package:flutter/material.dart';

import '../../../../theme/driver_home_palette.dart';

/// Écran 1 — Bienvenue.
///
/// Hero plein cadre avec dégradé de marque et tracé abstrait animé (aucune
/// icône, aucun emoji, aucun badge encadré). L'entrée est chorégraphiée en
/// cascade (hero → tracé → texte → profils) puis le point d'arrivée du
/// tracé pulse doucement, comme un repère de position vivant.
class WelcomeStep extends StatefulWidget {
  const WelcomeStep({super.key});

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat(reverse: true);

  late final Animation<double> _heroAnim = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _wordmarkAnim = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.12, 0.5, curve: Curves.easeOut),
  );
  late final Animation<double> _pathAnim = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.22, 0.78, curve: Curves.easeInOut),
  );
  late final Animation<double> _dotAnim = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.62, 0.88, curve: Curves.easeOutBack),
  );
  late final Animation<double> _textAnim = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.46, 0.82, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _entrance.forward().whenComplete(() {
      if (mounted) _pulse.repeat();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _drift.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(
          (0.66 + index * 0.055).clamp(0.0, 1.0),
          (0.88 + index * 0.055).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _WelcomeHero(
            heroAnim: _heroAnim,
            wordmarkAnim: _wordmarkAnim,
            pathAnim: _pathAnim,
            dotAnim: _dotAnim,
            pulse: _pulse,
            drift: _drift,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: AnimatedBuilder(
              animation: _textAnim,
              builder: (context, child) => Opacity(
                opacity: _textAnim.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - _textAnim.value)),
                  child: child,
                ),
              ),
              child: const Column(
                children: [
                  Text(
                    'Bienvenue sur Aule Pro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      color: DriverHomePalette.textDark,
                      height: 1.15,
                      letterSpacing: -0.6,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'L’espace professionnel qui accompagne conducteurs, '
                    'contrôleurs, VTC et commerçants au quotidien.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.5,
                      color: DriverHomePalette.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _AudienceStrip(staggerBuilder: _staggered),
          ),
        ],
      ),
    );
  }
}

// ── Hero de marque ──────────────────────────────────────────────────────────

class _WelcomeHero extends StatelessWidget {
  final Animation<double> heroAnim;
  final Animation<double> wordmarkAnim;
  final Animation<double> pathAnim;
  final Animation<double> dotAnim;
  final Animation<double> pulse;
  final Animation<double> drift;

  const _WelcomeHero({
    required this.heroAnim,
    required this.wordmarkAnim,
    required this.pathAnim,
    required this.dotAnim,
    required this.pulse,
    required this.drift,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: heroAnim,
      builder: (context, child) => Opacity(
        opacity: heroAnim.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.97 + 0.03 * heroAnim.value,
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        child: Container(
          width: double.infinity,
          height: 296,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DriverHomePalette.gradientStart,
                DriverHomePalette.darkGreen,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -50,
                child: _Glow(
                  color: DriverHomePalette.primary,
                  size: 240,
                  opacity: 0.38,
                  drift: drift,
                ),
              ),
              Positioned(
                bottom: -80,
                left: -60,
                child: _Glow(
                  color: Colors.white,
                  size: 220,
                  opacity: 0.07,
                  drift: drift,
                  reversed: true,
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 96, 32, 28),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([pathAnim, dotAnim, pulse]),
                    builder: (context, _) => CustomPaint(
                      painter: _RoutePainter(
                        pathProgress: pathAnim.value,
                        dotScale: dotAnim.value.clamp(0.0, 1.4),
                        pulseValue: pulse.value,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                top: 32,
                child: AnimatedBuilder(
                  animation: wordmarkAnim,
                  builder: (context, child) => Opacity(
                    opacity: wordmarkAnim.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - wordmarkAnim.value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESPACE PROFESSIONNEL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.62),
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Aule Pro',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.9,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  final Animation<double> drift;
  final bool reversed;

  const _Glow({
    required this.color,
    required this.size,
    required this.opacity,
    required this.drift,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: drift,
      builder: (context, child) {
        final t = reversed ? 1 - drift.value : drift.value;
        final scale = 0.94 + 0.12 * t;
        final alpha = opacity * (0.82 + 0.18 * t);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tracé abstrait pointillé évoquant un itinéraire, dessiné (pas une image)
/// pour rester net à toute résolution et rester dans la charte de marque.
/// Se dévoile progressivement puis pulse doucement à son point d'arrivée.
class _RoutePainter extends CustomPainter {
  final double pathProgress;
  final double dotScale;
  final double pulseValue;

  const _RoutePainter({
    required this.pathProgress,
    required this.dotScale,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pathProgress <= 0) return;

    final path = Path()
      ..moveTo(0, size.height * 0.94)
      ..cubicTo(
        size.width * 0.22,
        size.height * 1.0,
        size.width * 0.28,
        size.height * 0.52,
        size.width * 0.54,
        size.height * 0.46,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.41,
        size.width * 0.64,
        size.height * 0.08,
        size.width * 0.96,
        size.height * 0.02,
      );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.6),
        ],
      ).createShader(Offset.zero & size);

    const dashWidth = 6.0;
    const dashSpace = 7.0;
    Offset? endPoint;
    for (final metric in path.computeMetrics()) {
      final revealed = metric.length * pathProgress;
      var distance = 0.0;
      while (distance < revealed) {
        final end = (distance + dashWidth).clamp(0.0, revealed);
        canvas.drawPath(metric.extractPath(distance, end), linePaint);
        distance += dashWidth + dashSpace;
      }
      endPoint = metric.getTangentForOffset(revealed)?.position;
    }

    canvas.drawCircle(
      Offset(0, size.height * 0.94),
      3.5,
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );

    if (dotScale <= 0 || endPoint == null) return;
    final targetCenter = Offset(size.width * 0.96, size.height * 0.02);
    final center = pathProgress >= 1 ? targetCenter : endPoint;

    if (pulseValue > 0) {
      canvas.drawCircle(
        center,
        (14 + pulseValue * 20) * dotScale,
        Paint()
          ..color = DriverHomePalette.primary
              .withValues(alpha: (1 - pulseValue) * 0.35),
      );
    }
    canvas.drawCircle(
      center,
      15 * dotScale,
      Paint()..color = DriverHomePalette.primary.withValues(alpha: 0.55),
    );
    canvas.drawCircle(center, 6 * dotScale, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.pathProgress != pathProgress ||
      oldDelegate.dotScale != dotScale ||
      oldDelegate.pulseValue != pulseValue;
}

class _StaggerItem extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _StaggerItem({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ── Bandeau des profils ─────────────────────────────────────────────────────

class _AudienceStrip extends StatelessWidget {
  final Animation<double> Function(int index) staggerBuilder;

  const _AudienceStrip({required this.staggerBuilder});

  @override
  Widget build(BuildContext context) {
    const labels = ['Conducteur', 'Contrôleur', 'VTC', 'Commerçant'];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 10,
      children: [
        for (var i = 0; i < labels.length; i++)
          _StaggerItem(
            animation: staggerBuilder(i),
            child: Text(
              labels[i].toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: DriverHomePalette.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
          ),
      ],
    );
  }
}
