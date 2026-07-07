import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/driver_home_palette.dart';

/// Bouton aide compact — coin inférieur gauche.
class TerrainHelpFab extends StatelessWidget {
  final VoidCallback onTap;

  const TerrainHelpFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x1A101A14),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.lifeBuoy, size: 17, color: DriverHomePalette.primary),
              SizedBox(width: 8),
              Text(
                'Besoin d\'aide',
                style: TextStyle(
                  color: DriverHomePalette.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton recentrage GPS — coin inférieur droit.
class TerrainLocateButton extends StatefulWidget {
  final Future<void> Function() onTap;

  const TerrainLocateButton({super.key, required this.onTap});

  @override
  State<TerrainLocateButton> createState() => _TerrainLocateButtonState();
}

class _TerrainLocateButtonState extends State<TerrainLocateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handle() async {
    _ctrl.forward(from: 0);
    await widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0x1A101A14),
      child: InkWell(
        onTap: _handle,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: RotationTransition(
            turns: CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
            child: const Icon(
              LucideIcons.locateFixed,
              size: 22,
              color: DriverHomePalette.primary,
            ),
          ),
        ),
      ),
    );
  }
}
