import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/flow_theme.dart';
import 'flow_primitives.dart';

/// Pastille d'arrêt sur la carte — fond blanc, bordure et icône colorées
/// selon le mode de transport.
class StopMapIcon extends StatelessWidget {
  final String transportType;
  final double size;
  final Color color;

  const StopMapIcon({
    super.key,
    required this.transportType,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.52;
    final borderWidth = size >= 22 ? 2.0 : 1.5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        flowModeIcon(transportType),
        size: iconSize,
        color: color,
      ),
    );
  }
}

/// Glyphe (icône) du mode de transport.
IconData flowModeIcon(String transportType) {
  switch (transportType.toLowerCase()) {
    case 'tram':
      return LucideIcons.tramFront;
    case 'busway':
      return LucideIcons.busFront;
    case 'navibus':
      return LucideIcons.ship;
    case 'bus':
    default:
      return LucideIcons.bus;
  }
}

/// Badge de ligne — pastille encre foncée, glyphe mode + code blanc (ex. C3, T1).
class LineBadge extends StatelessWidget {
  final String code;
  final String transportType;
  final bool large;
  final Color background;

  const LineBadge({
    super.key,
    required this.code,
    required this.transportType,
    this.large = false,
    this.background = FlowColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    final double pad = large ? 11 : 8;
    final double padV = large ? 9 : 5;
    final double radius = large ? 12 : 9;
    final double iconSize = large ? 18 : 14;
    final double fontSize = large ? 18 : 13;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: padV),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(flowModeIcon(transportType), size: iconSize, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            code,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur d'affluence — 3 barres montantes remplies selon le niveau.
class CrowdBars extends StatelessWidget {
  final CrowdLevel level;
  final String? label;

  const CrowdBars({super.key, required this.level, this.label});

  Color get _color {
    switch (level) {
      case CrowdLevel.low:
        return FlowColors.green;
      case CrowdLevel.mid:
        return FlowColors.orange;
      case CrowdLevel.high:
        return FlowColors.red;
    }
  }

  int get _filled {
    switch (level) {
      case CrowdLevel.low:
        return 1;
      case CrowdLevel.mid:
        return 2;
      case CrowdLevel.high:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final heights = [6.0, 10.0, 14.0];
    final bars = List.generate(3, (i) {
      return Container(
        width: 4,
        height: heights[i],
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          color: i < _filled ? _color : FlowColors.fill2,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    });

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars,
    );

    if (label == null) return row;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        const SizedBox(width: 7),
        Text(
          label!,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _color,
          ),
        ),
      ],
    );
  }
}

/// Label de section (kicker) majuscule.
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const SectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: FlowText.kicker.copyWith(color: color),
    );
  }
}

/// Poignée de bottom sheet centrée.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 5,
        decoration: BoxDecoration(
          color: FlowColors.fill2,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Conteneur de bottom sheet FLOW : coins haut arrondis 20, poignée, ombre montante.
class FlowSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const FlowSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: FlowColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(FlowTokens.rSheet)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F1A1916),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Tuile statistique (Affluence / Fiabilité / Retard…).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color valueColor;
  final Widget? leading;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.valueColor = FlowColors.ink,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      decoration: BoxDecoration(
        color: FlowColors.fill,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: valueColor,
              height: 1.0,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Flexible(
                  child: Text(
                    sub!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: FlowColors.g2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Petit badge sémantique « soft » (fond doux + texte coloré).
class SoftBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final bool dot;
  final IconData? icon;

  const SoftBadge({
    super.key,
    required this.text,
    required this.color,
    required this.background,
    this.dot = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Capsule véhicule posée sur la carte : carte blanche arrondie, glyphe + code,
/// statut coloré dessous, triangle pointeur sous la carte.
class VehicleCapsule extends StatelessWidget {
  final String code;
  final String transportType;
  final String statusText;
  final Color statusColor;
  final bool me;

  const VehicleCapsule({
    super.key,
    required this.code,
    required this.transportType,
    required this.statusText,
    required this.statusColor,
    this.me = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 6),
          decoration: BoxDecoration(
            color: FlowColors.white,
            borderRadius: BorderRadius.circular(13),
            boxShadow: FlowTokens.capsule,
            border: me ? Border.all(color: FlowColors.blue, width: 2) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(flowModeIcon(transportType), size: 14, color: FlowColors.ink),
                  const SizedBox(width: 5),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        // Triangle pointeur
        Transform.translate(
          offset: const Offset(0, -3),
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: FlowColors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: FlowColors.ink.withValues(alpha: 0.10),
                    blurRadius: 3,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton rond flottant (recentrer, retour…).
class FlowRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final double size;

  const FlowRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor = FlowColors.ink,
    this.size = 46,
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
          shape: BoxShape.circle,
          border: Border.all(color: FlowColors.line),
          boxShadow: FlowTokens.soft,
        ),
        child: Icon(icon, size: 22, color: iconColor),
      ),
    );
  }
}

/// Bottom navigation FLOW — onglet actif = icône dans une pilule bleue douce.
class FlowBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FlowBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: LucideIcons.house, active: LucideIcons.house, label: 'Accueil'),
    (icon: LucideIcons.map, active: LucideIcons.map, label: 'Map'),
    (icon: LucideIcons.circleUser, active: LucideIcons.circleUser, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FlowColors.white,
        border: Border(top: BorderSide(color: FlowColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final active = i == currentIndex;
              final item = _items[i];
              return FlowTappable(
                onTap: () => onTap(i),
                pressedScale: 0.94,
                child: SizedBox(
                  width: 84,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        height: 32,
                        decoration: BoxDecoration(
                          color: active ? FlowColors.blueSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          active ? item.active : item.icon,
                          size: 22,
                          color: active ? FlowColors.blue : FlowColors.g2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? FlowColors.blue : FlowColors.g2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Tuile d'icône (34–44, rayon 11–13).
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;
  final double size;

  const IconTile({
    super.key,
    required this.icon,
    this.background = FlowColors.fill,
    this.iconColor = FlowColors.ink,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size * 0.5, color: iconColor),
    );
  }
}
