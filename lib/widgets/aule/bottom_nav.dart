import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../theme/aule_theme.dart';
import 'aule_icons.dart';

/// Barre de navigation fixe en bas — Accueil · Map · Profil.
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _labels = ['Accueil', 'Map', 'Profil'];

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.navBg,
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(3, (i) {
                  final active = i == currentIndex;
                  return Semantics(
                    button: true,
                    label: _labels[i],
                    selected: active,
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 72,
                          minHeight: AuleTokens.minTouch,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _navIcon(i, c, active),
                            const SizedBox(height: 4),
                            Text(
                              _labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: hankenGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                                height: 1.1,
                                color: active ? c.brand : c.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navIcon(int index, AuleColors c, bool active) {
    final color = active ? c.brand : c.faint;
    switch (index) {
      case 0:
        return AuleIcons.accueil(size: 24, color: color, active: active);
      case 1:
        return AuleIcons.map(size: 24, color: color, active: active);
      default:
        return AuleIcons.profile(size: 24, color: color, active: active);
    }
  }
}
