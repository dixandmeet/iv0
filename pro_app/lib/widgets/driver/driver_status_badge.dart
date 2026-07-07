import 'package:flutter/material.dart';

import '../../theme/driver_home_palette.dart';

/// Petit badge « ● En service » (pastille colorée + libellé).
///
/// Vert pâle quand le conducteur est en service, gris discret sinon.
class DriverStatusBadge extends StatelessWidget {
  final String label;
  final bool active;

  const DriverStatusBadge({
    super.key,
    required this.label,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? DriverHomePalette.primary : DriverHomePalette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? DriverHomePalette.lightGreen
            : DriverHomePalette.border.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
