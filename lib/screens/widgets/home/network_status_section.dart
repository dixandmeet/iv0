import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../services/home_aggregator.dart';
import '../../../theme/flow_theme.dart';
import '../../../widgets/flow_primitives.dart';
import '../../../widgets/home/home_section_header.dart';
import '../../pulse_screen.dart';

class NetworkStatusSection extends StatelessWidget {
  final NetworkStatusSummary status;

  const NetworkStatusSection({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final hasDisruptions = status.disruptionCount > 0;
    final color = hasDisruptions ? FlowColors.orange : FlowColors.green;
    final soft = hasDisruptions ? FlowColors.orangeSoft : FlowColors.greenSoft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(emoji: '📡', title: 'État du réseau'),
        FlowTappable(
          onTap: () {
            Navigator.push(
              context,
              FlowPageRoute(page: const PulseScreen()),
            );
          },
          pressedScale: 0.985,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(FlowTokens.rCardXl),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  hasDisruptions ? LucideIcons.triangleAlert : LucideIcons.circleCheck,
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status.headline,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 18, color: FlowColors.g2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
