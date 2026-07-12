import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Écran de démarrage Aule Pro.
///
/// La progression se termine avant le fondu de sortie afin que le splash ne
/// paraisse jamais bloqué ou assombri en cours de chargement.
class SplashOverlay extends StatefulWidget {
  final VoidCallback? onFinished;

  const SplashOverlay({super.key, this.onFinished});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  static const _exitDelay = Duration(milliseconds: 1850);

  late final AnimationController _pulse;
  late final AnimationController _intro;
  late final AnimationController _progress;
  late final AnimationController _exit;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentOffset;
  late final Animation<double> _progressValue;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    )..forward();
    _exit =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onFinished?.call();
        });

    _logoOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.42, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0, 0.72, curve: Curves.easeOutBack),
      ),
    );
    _contentOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.32, 1, curve: Curves.easeOut),
    );
    _contentOffset =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _intro,
            curve: const Interval(0.32, 1, curve: Curves.easeOutCubic),
          ),
        );
    _progressValue = CurvedAnimation(
      parent: _progress,
      curve: Curves.easeInOutCubic,
    );

    _exitTimer = Timer(_exitDelay, () {
      if (mounted) _exit.forward();
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _pulse.dispose();
    _intro.dispose();
    _progress.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: ReverseAnimation(
        CurvedAnimation(parent: _exit, curve: Curves.easeInCubic),
      ),
      child: ColoredBox(
        color: AppColors.bg,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.16),
              radius: 0.82,
              colors: [Color(0xFF123029), Color(0xFF0B1714), AppColors.bg],
              stops: [0, 0.44, 1],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _contentOpacity,
                        child: SlideTransition(
                          position: _contentOffset,
                          child: _buildBranding(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 174,
      height: 174,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PulseRing(animation: _pulse),
          _PulseRing(animation: _pulse, phase: 0.5),
          ScaleTransition(
            scale: _logoScale,
            child: FadeTransition(
              opacity: _logoOpacity,
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 38,
                      spreadRadius: 2,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo_aule.png',
                  filterQuality: FilterQuality.high,
                  semanticLabel: 'Logo Aule Pro',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Aule '),
              TextSpan(
                text: 'Pro',
                style: TextStyle(color: AppColors.accent),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "L'app des agents de terrain",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.35,
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 36),
        Semantics(
          label: 'Chargement de Aule Pro',
          child: SizedBox(
            width: 156,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.12),
                child: ScaleTransition(
                  scale: _progressValue,
                  alignment: Alignment.centerLeft,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF279E88), AppColors.accent],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseRing extends AnimatedWidget {
  final double phase;

  const _PulseRing({required Animation<double> animation, this.phase = 0})
    : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final t = (animation.value + phase) % 1;
    final opacity = (1 - t) * 0.34;

    return Transform.scale(
      scale: 0.72 + (t * 0.74),
      child: Container(
        width: 122,
        height: 122,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            width: 1.2,
            color: AppColors.accent.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}
