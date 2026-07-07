import 'package:flutter/material.dart';

import 'auth_palette.dart';

/// Bouton principal des écrans d'authentification : dégradé sauge, ombre
/// portée et micro-interaction d'appui (léger tassement) pour un rendu
/// premium et un retour tactile net.
class PremiumAuthButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final IconData? icon;

  const PremiumAuthButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onTap,
    this.icon,
  });

  @override
  State<PremiumAuthButton> createState() => _PremiumAuthButtonState();
}

class _PremiumAuthButtonState extends State<PremiumAuthButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [AuthPalette.forest, AuthPalette.forestDeep]
                  : [Colors.grey.shade300, Colors.grey.shade400],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AuthPalette.forest
                          .withValues(alpha: _pressed ? 0.22 : 0.34),
                      blurRadius: _pressed ? 10 : 18,
                      offset: Offset(0, _pressed ? 4 : 9),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 18),
                        const SizedBox(width: 9),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
