import 'package:flutter/material.dart';

/// Point « live » avec halo pulsant facon radar : un disque plein fixe entouré
/// d'une onde qui s'agrandit et s'estompe en boucle. [animate] à faux ne rend
/// que le point fixe (état au repos). Réservé aux passages imminents.
class LiveDot extends StatefulWidget {
  final bool animate;

  /// Diamètre du point plein central.
  final double size;
  final Color color;

  const LiveDot({
    super.key,
    this.animate = true,
    this.size = 7,
    this.color = const Color(0xFFEF4444),
  });

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(LiveDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size * 2;
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.animate)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final t = _ctrl.value;
                  final scale = 1.0 + 1.4 * t;
                  return Container(
                    width: widget.size * scale,
                    height: widget.size * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(alpha: 0.4 * (1 - t)),
                    ),
                  );
                },
              ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
