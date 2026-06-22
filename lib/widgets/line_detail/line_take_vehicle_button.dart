import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bouton flottant pleine largeur « Prendre ce tram / bus ».
class LineTakeVehicleButton extends StatefulWidget {
  final Color lineColor;
  final String label;
  final IconData icon;
  final bool isRegistered;
  final VoidCallback onPressed;

  const LineTakeVehicleButton({
    super.key,
    required this.lineColor,
    required this.label,
    required this.icon,
    required this.isRegistered,
    required this.onPressed,
  });

  static String labelFor(String transportType, {bool registered = false}) {
    if (registered) return 'Montée enregistrée';
    switch (transportType.toLowerCase()) {
      case 'tram':
        return 'Prendre ce tram';
      case 'navibus':
        return 'Prendre ce navibus';
      case 'busway':
        return 'Prendre ce chronobus';
      default:
        return 'Prendre ce bus';
    }
  }

  static IconData iconFor(String transportType, {bool registered = false}) {
    if (registered) return LucideIcons.circleCheck;
    switch (transportType.toLowerCase()) {
      case 'tram':
        return LucideIcons.tramFront;
      default:
        return LucideIcons.bus;
    }
  }

  @override
  State<LineTakeVehicleButton> createState() => _LineTakeVehicleButtonState();
}

class _LineTakeVehicleButtonState extends State<LineTakeVehicleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;
  late final Animation<double> _halo;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.18, end: 0.42).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _halo = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(LineTakeVehicleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRegistered != widget.isRegistered) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isRegistered) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = widget.isRegistered ? 1.0 : _scale.value;
        final glow = widget.isRegistered ? 0.22 : _glow.value;
        final haloExpand = widget.isRegistered ? 0.0 : _halo.value;

        return Transform.scale(
          scale: scale,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (!widget.isRegistered)
                Positioned(
                  left: -6 - haloExpand * 6,
                  right: -6 - haloExpand * 6,
                  top: -4 - haloExpand * 4,
                  bottom: -4 - haloExpand * 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: widget.lineColor.withValues(
                            alpha: 0.12 + haloExpand * 0.18,
                          ),
                          blurRadius: 18 + haloExpand * 14,
                          spreadRadius: 1 + haloExpand * 3,
                        ),
                      ],
                    ),
                  ),
                ),
              Material(
                color: Colors.transparent,
                elevation: widget.isRegistered ? 4 : 10,
                shadowColor: widget.lineColor.withValues(alpha: glow),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(18),
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  highlightColor: Colors.white.withValues(alpha: 0.08),
                  child: Ink(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: widget.isRegistered
                          ? widget.lineColor.withValues(
                              alpha: isDark ? 0.22 : 0.12,
                            )
                          : widget.lineColor,
                      borderRadius: BorderRadius.circular(18),
                      border: widget.isRegistered
                          ? Border.all(color: widget.lineColor, width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: widget.lineColor.withValues(alpha: glow),
                          blurRadius:
                              widget.isRegistered ? 10 : 18 + haloExpand * 6,
                          offset: Offset(
                            0,
                            widget.isRegistered ? 3 : 5 + haloExpand * 2,
                          ),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            widget.icon,
                            key: ValueKey(widget.icon),
                            size: 20,
                            color: widget.isRegistered
                                ? widget.lineColor
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 280),
                          style: hankenGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: widget.isRegistered
                                ? widget.lineColor
                                : Colors.white,
                            letterSpacing: -0.2,
                          ),
                          child: Text(widget.label),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
