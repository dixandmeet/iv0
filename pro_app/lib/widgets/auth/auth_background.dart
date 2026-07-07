import 'package:flutter/material.dart';

import 'auth_palette.dart';

/// Fond premium des écrans d'authentification : dégradé clair, halos doux et
/// silhouette de ville en pied d'écran. Statique (pas de photo, pas
/// d'animation) pour rester léger sur tous les appareils.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF8FCFB),
                Color(0xFFF0FAF7),
                Color(0xFFD7F6EF),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),

        // Halo doux en haut à droite.
        Positioned(
          top: -80,
          right: -60,
          child: _Glow(color: AuthPalette.sage, size: 260, opacity: 0.35),
        ),
        // Halo doux en bas à gauche.
        Positioned(
          bottom: -60,
          left: -70,
          child: _Glow(color: AuthPalette.forest, size: 220, opacity: 0.20),
        ),

        // Silhouette de ville, très atténuée, en pied d'écran.
        Align(
          alignment: Alignment.bottomCenter,
          child: CustomPaint(
            size: const Size(double.infinity, 90),
            painter: _SkylinePainter(),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity),
            blurRadius: size * 0.55,
            spreadRadius: size * 0.12,
          ),
        ],
      ),
    );
  }
}

/// Silhouette de ville + bus, très atténuée, posée en bas d'écran.
class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AuthPalette.sage.withValues(alpha: 0.16);
    final base = size.height;

    const heights = [38.0, 62.0, 30.0, 80.0, 48.0, 70.0, 34.0, 56.0, 42.0];
    final slot = size.width / heights.length;
    for (int i = 0; i < heights.length; i++) {
      final x = i * slot;
      final h = heights[i];
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x + 4, base - h, slot - 8, h),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        paint,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, base - 3, size.width, 3),
      Paint()..color = AuthPalette.sage.withValues(alpha: 0.22),
    );

    final busPaint = Paint()..color = AuthPalette.sage.withValues(alpha: 0.30);
    final bx = size.width * 0.62;
    final by = base - 22;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, 64, 19), const Radius.circular(5)),
      busPaint,
    );
    final wheel = Paint()..color = AuthPalette.sage.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(bx + 14, by + 19), 3.4, wheel);
    canvas.drawCircle(Offset(bx + 50, by + 19), 3.4, wheel);
  }

  @override
  bool shouldRepaint(_SkylinePainter oldDelegate) => false;
}
