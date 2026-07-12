import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/map_weather_service.dart';

class MapWeatherLayer extends StatefulWidget {
  final MapWeatherSnapshot weather;

  const MapWeatherLayer({super.key, required this.weather});

  @override
  State<MapWeatherLayer> createState() => _MapWeatherLayerState();
}

class _MapWeatherLayerState extends State<MapWeatherLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.weather;
    final wet =
        weather.condition == MapWeatherCondition.rain ||
        weather.condition == MapWeatherCondition.storm;
    final cloudy = weather.condition != MapWeatherCondition.clear;
    final tint = switch ((weather.period, weather.condition)) {
      (MapDayPeriod.dawn, _) => const Color(0x22F08C62),
      (MapDayPeriod.dusk, _) => const Color(0x2ADF7658),
      (MapDayPeriod.night, _) => const Color(0x5204111B),
      (_, MapWeatherCondition.rain || MapWeatherCondition.storm) => const Color(
        0x38556876,
      ),
      (_, MapWeatherCondition.fog) => const Color(0x38AAB6BA),
      _ => Colors.transparent,
    };

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: tint),
          if (weather.condition == MapWeatherCondition.clear &&
              weather.period != MapDayPeriod.night)
            const _SunGlow(),
          if (cloudy) const _CloudCover(),
          if (weather.condition == MapWeatherCondition.fog) const _FogCover(),
          if (wet || weather.condition == MapWeatherCondition.snow)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => CustomPaint(
                painter: _PrecipitationPainter(
                  progress: _animation.value,
                  snow: weather.condition == MapWeatherCondition.snow,
                  heavy: weather.condition == MapWeatherCondition.storm,
                ),
              ),
            ),
          if (weather.condition == MapWeatherCondition.storm)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final flash =
                    _animation.value > 0.88 && _animation.value < 0.91;
                return ColoredBox(
                  color: Colors.white.withValues(alpha: flash ? 0.2 : 0),
                );
              },
            ),
        ],
      ),
    );
  }
}

class MapWeatherBadge extends StatelessWidget {
  final MapWeatherSnapshot weather;

  const MapWeatherBadge({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final icon = switch (weather.condition) {
      MapWeatherCondition.clear =>
        weather.period == MapDayPeriod.night
            ? Icons.nightlight_round
            : Icons.wb_sunny_rounded,
      MapWeatherCondition.cloudy => Icons.cloud_rounded,
      MapWeatherCondition.fog => Icons.dehaze_rounded,
      MapWeatherCondition.rain => Icons.water_drop_rounded,
      MapWeatherCondition.snow => Icons.ac_unit_rounded,
      MapWeatherCondition.storm => Icons.thunderstorm_rounded,
    };
    return Semantics(
      label: 'Météo ${weather.label}. Données Open-Meteo.com',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xCC07110F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF8DEEDD)),
            const SizedBox(width: 7),
            Text(
              weather.temperature == null
                  ? weather.label
                  : '${weather.temperature!.round()}° · ${weather.label}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SunGlow extends StatelessWidget {
  const _SunGlow();

  @override
  Widget build(BuildContext context) => Positioned(
    top: -55,
    right: -42,
    width: 230,
    height: 230,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFFFE8AA).withValues(alpha: 0.42),
            const Color(0xFFFFAD72).withValues(alpha: 0.14),
            Colors.transparent,
          ],
        ),
      ),
    ),
  );
}

class _CloudCover extends StatelessWidget {
  const _CloudCover();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: FractionallySizedBox(
      widthFactor: 1,
      heightFactor: 0.42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFBBC5C9).withValues(alpha: 0.38),
              const Color(0xFF71808A).withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );
}

class _FogCover extends StatelessWidget {
  const _FogCover();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFE1E6E7).withValues(alpha: 0.24),
          Colors.transparent,
          const Color(0xFFC9D1D3).withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ),
    ),
  );
}

class _PrecipitationPainter extends CustomPainter {
  final double progress;
  final bool snow;
  final bool heavy;

  const _PrecipitationPainter({
    required this.progress,
    required this.snow,
    required this.heavy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = heavy ? 90 : 58;
    final paint = Paint()
      ..strokeWidth = snow ? 1.5 : 1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: snow ? 0.62 : 0.34);
    for (var i = 0; i < count; i++) {
      final seedX = (i * 47.0 + math.sin(i * 2.1) * 17) % size.width;
      final speed = snow ? 0.55 + (i % 5) * 0.08 : 1.3 + (i % 4) * 0.2;
      final y =
          (i * 73.0 + progress * size.height * speed) % (size.height + 30) - 15;
      if (snow) {
        final drift = math.sin(progress * math.pi * 2 + i) * 7;
        canvas.drawCircle(
          Offset(seedX + drift, y),
          1.2 + (i % 3) * 0.45,
          paint,
        );
      } else {
        canvas.drawLine(Offset(seedX, y), Offset(seedX - 5, y + 17), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PrecipitationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.snow != snow ||
      oldDelegate.heavy != heavy;
}
