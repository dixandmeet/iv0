import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/flow_theme.dart';

/// Primitives interactives du design system FLOW.
///
/// Remplacent les composants Material (boutons, switch, snackbar, bottom
/// sheet, dialog, ripple) par un langage maison : feedback au press par
/// scale + opacité, surfaces blanches arrondies, ombres douces.

// ---------------------------------------------------------------------------
// FlowTappable — surface tactile signature (scale 0.97 + opacité au press)
// ---------------------------------------------------------------------------

class FlowTappable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final double pressedOpacity;
  final HitTestBehavior behavior;

  const FlowTappable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
    this.pressedOpacity = 0.85,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<FlowTappable> createState() => _FlowTappableState();
}

class _FlowTappableState extends State<FlowTappable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? widget.pressedOpacity : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FlowButton — bouton signature (primary / secondary / ghost)
// ---------------------------------------------------------------------------

enum FlowButtonVariant { primary, secondary, ghost }

class FlowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final FlowButtonVariant variant;
  final IconData? icon;
  final Color? color;
  final double height;

  const FlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FlowButtonVariant.primary,
    this.icon,
    this.color,
    this.height = FlowTokens.btnHeight,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    Border? border;
    switch (variant) {
      case FlowButtonVariant.primary:
        bg = color ?? FlowColors.blue;
        fg = Colors.white;
      case FlowButtonVariant.secondary:
        bg = FlowColors.white;
        fg = color ?? FlowColors.ink;
        border = Border.all(color: FlowColors.line);
      case FlowButtonVariant.ghost:
        bg = Colors.transparent;
        fg = color ?? FlowColors.g2;
    }

    return FlowTappable(
      onTap: onPressed,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(FlowTokens.rBtn),
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton carré à icône (retour, fermer, swap…) — bord fin, fond blanc.
class FlowIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color iconColor;

  const FlowIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.iconSize = 20,
    this.iconColor = FlowColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: FlowColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlowColors.line),
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FlowSwitch — interrupteur maison (piste animée + pouce blanc)
// ---------------------------------------------------------------------------

class FlowSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const FlowSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: () => onChanged(!value),
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? FlowColors.blue : FlowColors.fill2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: FlowColors.ink.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FlowToast — remplace les SnackBars (capsule encre flottante via Overlay)
// ---------------------------------------------------------------------------

OverlayEntry? _currentToast;

void showFlowToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Duration duration = const Duration(milliseconds: 2800),
}) {
  _currentToast?.remove();
  _currentToast = null;

  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _FlowToast(
      message: message,
      icon: icon,
      duration: duration,
      onDismissed: () {
        if (_currentToast == entry) _currentToast = null;
        entry.remove();
      },
    ),
  );
  _currentToast = entry;
  overlay.insert(entry);
}

class _FlowToast extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onDismissed;

  const _FlowToast({
    required this.message,
    this.icon,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_FlowToast> createState() => _FlowToastState();
}

class _FlowToastState extends State<_FlowToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return Positioned(
      left: FlowTokens.margin,
      right: FlowTokens.margin,
      bottom: MediaQuery.of(context).padding.bottom + 84,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.35),
              end: Offset.zero,
            ).animate(curved),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: FlowColors.ink,
                borderRadius: BorderRadius.circular(14),
                boxShadow: FlowTokens.capsule,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon ?? LucideIcons.info,
                      size: 17, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// showFlowSheet — bottom sheet maison (route custom, slide-up + barrière)
// ---------------------------------------------------------------------------

Future<T?> showFlowSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return Navigator.of(context, rootNavigator: true)
      .push<T>(_FlowSheetRoute<T>(builder: builder));
}

class _FlowSheetRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;

  _FlowSheetRoute({required this.builder});

  @override
  Color get barrierColor => FlowColors.ink.withValues(alpha: 0.45);

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'Fermer';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 230);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    // Material transparent : requis par les TextField des sheets,
    // sans aucun rendu Material visible.
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: double.infinity,
          child: Builder(builder: builder),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(curved),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// showFlowDialog — dialog maison (fade + scale, carte blanche arrondie)
// ---------------------------------------------------------------------------

Future<T?> showFlowDialog<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: FlowColors.ink.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Builder(builder: builder),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Carte de dialog FLOW : titre, contenu, action de fermeture.
class FlowDialogCard extends StatelessWidget {
  final Widget title;
  final Widget content;
  final String closeLabel;

  const FlowDialogCard({
    super.key,
    required this.title,
    required this.content,
    this.closeLabel = 'Fermer',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      decoration: BoxDecoration(
        color: FlowColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: FlowTokens.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 14),
          content,
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FlowTappable(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  closeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FlowColors.blue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FlowPageRoute — transition push signature (slide latéral + fade)
// ---------------------------------------------------------------------------

class FlowPageRoute<T> extends PageRouteBuilder<T> {
  FlowPageRoute({required Widget page})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            final curved =
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.18, 0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        );
}

// ---------------------------------------------------------------------------
// FlowTextField — champ de saisie FLOW (sans décor Material)
// ---------------------------------------------------------------------------

class FlowTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextStyle? style;
  final TextCapitalization textCapitalization;

  const FlowTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.focusNode,
    this.autofocus = false,
    this.style,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      cursorColor: FlowColors.blue,
      textCapitalization: textCapitalization,
      style: style ?? FlowText.rowTitle,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hintText,
        hintStyle: const TextStyle(
          color: FlowColors.g2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
